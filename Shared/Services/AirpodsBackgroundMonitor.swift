// AirPods background monitoring is iOS-only - requires audio session + AVFoundation + CoreMotion
#if os(iOS)

import AVFoundation
import CoreMotion
import SwiftData
import SwiftUI
import UIKit

/// All-day AirPods posture monitor (optional Pro extra).
///
/// Holds the shared `AudioKeepAlive` to keep `CMHeadphoneMotionManager`
/// delivering head-pose updates in the background, evaluates posture against
/// the user's calibration, records slouch events as `PosturePassiveSample`,
/// and triggers haptic feedback when the user slouches.
///
/// Since the daily-practice pivot this is no longer the core loop: the streak
/// comes from completing a practice session, and monitoring only feeds the
/// day timeline/stats for users who opt in.
///
/// - Requires: `UIBackgroundModes: audio` in Info.plist
/// - Requires: Pro subscription + the Settings toggle (gated by the caller)
@MainActor
@Observable
final class AirpodsBackgroundMonitor {
    // MARK: - Public state

    private(set) var isMonitoring = false
    private(set) var isAvailable = false
    private(set) var isConnected = false
    private(set) var currentQuality: PostureQuality = .good
    private(set) var lastError: String?

    /// User hit Stop on the monitoring card. Auto-start paths (foreground
    /// live readout, Pro all-day toggle on launch) respect this until the
    /// user hits Start again - a manual stop that silently un-stopped
    /// itself on the next foreground would read as broken.
    var userPaused = false

    // MARK: - Activity visibility

    /// When the most recent head-motion sample arrived. Published at most
    /// once per second - samples land at ~25 Hz and republishing each one
    /// would re-render every observing view at that rate.
    private(set) var lastSampleAt: Date?

    /// Motion samples processed since the start of today. Same 1 Hz publish
    /// throttle as `lastSampleAt`.
    private(set) var samplesToday = 0

    /// Running log of monitor activity (newest first, capped). In-memory
    /// only - it answers "is this thing actually working?", not history.
    private(set) var events: [MonitorEvent] = []

    private var unpublishedSampleCount = 0
    private var lastSamplePublishAt: Date = .distantPast
    private var sampleCountDay: Date = DateHelpers.startOfDay()
    private static let maxEvents = 60

    private func logEvent(_ kind: MonitorEvent.Kind) {
        events.insert(MonitorEvent(timestamp: .now, kind: kind), at: 0)
        if events.count > Self.maxEvents {
            events.removeLast(events.count - Self.maxEvents)
        }
    }

    // MARK: - Dependencies

    private let headphoneService: HeadphoneMotionService
    private let calibrationService: CalibrationService
    private let modelContext: ModelContext
    private static let keepAliveToken = "monitor"

    // MARK: - Slouch detection (time-based)

    /// Exponentially smoothed head pitch. A raw ~25 Hz stream jitters enough
    /// that any instantaneous threshold flickers between buckets; we score off
    /// this instead so a momentary head turn or nod never reads as a slouch.
    private var smoothedPitch: Double?
    private let smoothingAlpha = 0.15

    /// When the user first entered `.bad`. Reset on `.good` or on AirPods
    /// disconnect. We trigger a haptic + record a sample after this much
    /// *continuous* bad posture - long enough that leaning to grab something or
    /// glancing down at a doorway never nudges. Borderline drift does not reset
    /// the clock, but also does not advance it.
    private var firstBadAt: Date?
    private let slouchNudgeSeconds: TimeInterval = 25

    /// Have we already fired the slouch event for the current bad bout?
    /// Keeps a long slouch from spamming `PosturePassiveSample` rows every
    /// few seconds. Reset on `.good` or disconnect.
    private var inBadBout = false

    /// Haptic debounce so we don't buzz the user every few seconds.
    private var lastHapticAt: Date = .distantPast
    private let hapticDebounceSeconds: TimeInterval = 60

    // MARK: - Minute aggregation

    /// The ~25 Hz stream is far too rich to persist raw, but slouch events
    /// alone throw away the story of the day. Every scored sample folds into
    /// `MinuteBucket` and persists as one `PostureMinuteSample` row per minute -
    /// that's what "% of day aligned", wear time, and the day timeline read.
    private var minuteBucket = MinuteBucket()
    /// Only all-day *background* monitoring (the Pro opt-in) persists minute
    /// rows into the day's stats. The free foreground "live readout" is just a
    /// glance - a way to see if you're sitting tall while using the app - and
    /// must not count toward % of day aligned, wear time, or the hour rhythm.
    /// Captured at `start(background:)` and held until `stop()` finishes its
    /// final flush so a real background run's last partial minute still lands.
    private var persistsMinutes = false
    /// Keep the store from growing unbounded - a monitored year is ~350k
    /// minute rows. 90 days is more history than any view reads.
    private static let minuteRetentionDays = 90

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.headphoneService = HeadphoneMotionService()
        self.calibrationService = CalibrationService(context: modelContext)
        self.modelContext = modelContext
        self.isAvailable = headphoneService.isAvailable

        headphoneService.onSample = { [weak self] pitch, yaw, roll in
            self?.onSample(pitch: pitch, yaw: yaw, roll: roll)
        }
        // AirPods can drop in/out during a background session (case, ear-out,
        // device switch). Don't tear down - just reflect the truth in UI so
        // the user sees we're "armed and waiting" vs "live."
        headphoneService.onConnect = { [weak self] connected in
            self?.handleConnect(connected)
        }

        // Surface keep-alive health in this monitor's activity log + error
        // slot - MonitoringLogView reads both. The keep-alive allows a single
        // observer and the monitor is the only long-lived holder.
        AudioKeepAlive.shared.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .interrupted:
                if self.isMonitoring, self.isBackground { self.logEvent(.audioInterrupted) }
            case .resumed:
                self.lastError = nil
                if self.isMonitoring, self.isBackground { self.logEvent(.audioResumed) }
            case .error(let message):
                self.lastError = message
                self.logEvent(.error(message))
            }
        }
    }

    // Intentionally no deinit: the monitor is process-scoped via `.shared`
    // and never deallocs in practice.

    /// Process-scoped instance. Constructed lazily on first access and
    /// reused for the life of the app - avoids the SwiftUI `@State` default-
    /// value footgun where the parent View's body recomputation builds a new
    /// monitor on every render.
    @MainActor static let shared = AirpodsBackgroundMonitor(
        modelContext: DataService.sharedModelContainer.mainContext
    )

    private func handleConnect(_ connected: Bool) {
        if connected != isConnected, isMonitoring {
            logEvent(connected ? .connected : .disconnected)
        }
        isConnected = connected
        if !connected {
            currentQuality = .good
            resetDetectionState()
            return
        }
        // AirPods just became available. If start() previously returned
        // false because no head-tracking AirPods were connected, the user
        // is now in the "armed and waiting" state - activate motion now.
        isAvailable = headphoneService.isAvailable
        if isMonitoring && !headphoneService.isRunning {
            activateMotion()
        }
    }

    // MARK: - Start / Stop

    /// Public for UI: are we currently running with the background audio
    /// session attached (the Pro extension) or foreground-only?
    private(set) var isBackground = false

    /// Arm monitoring. `background: true` holds the silent-audio keep-alive
    /// so motion samples keep flowing while the app is suspended - this is
    /// the Pro tier behavior and shows the iOS orange dot. `background:
    /// false` starts motion only; iOS will suspend it when the app leaves
    /// the foreground. Returns true as long as the monitor is armed, even
    /// if AirPods aren't currently connected - motion activates when they
    /// appear via the connect callback.
    @discardableResult
    func start(background: Bool = true) -> Bool {
        guard !isMonitoring else { return true }
        isMonitoring = true
        isBackground = background
        persistsMinutes = background
        lastError = nil
        logEvent(.armed(background: background))
        pruneOldMinuteSamples()
        activateMotion()
        return true
    }

    /// Wire up audio (if Pro/background) and start head-motion updates. Safe
    /// to call repeatedly - guarded by `headphoneService.isRunning` and the
    /// keep-alive's own refcount. Called from `start()` and from
    /// `handleConnect(true)` when AirPods appear after a cold launch.
    private func activateMotion() {
        guard isMonitoring else { return }
        isAvailable = headphoneService.isAvailable
        guard headphoneService.isAvailable else { return }

        if isBackground {
            AudioKeepAlive.shared.acquire(Self.keepAliveToken)
            if let error = AudioKeepAlive.shared.lastError {
                lastError = error
                return
            }
        }
        headphoneService.start()
    }

    func stop() {
        if isMonitoring { logEvent(.stopped) }
        isMonitoring = false
        isBackground = false
        headphoneService.stop()
        AudioKeepAlive.shared.release(Self.keepAliveToken)
        isConnected = false
        currentQuality = .good
        resetDetectionState()
        // Cleared last: resetDetectionState() above flushes this run's final
        // partial minute, which must still persist for a real background run.
        persistsMinutes = false
    }

    /// Clear all smoothing state so the next bout starts clean. Called on
    /// stop, on AirPods disconnect, and whenever we lack a real baseline.
    /// Flushes the in-progress minute first so partial minutes persist.
    private func resetDetectionState() {
        persistFlush(minuteBucket.flush())
        smoothedPitch = nil
        firstBadAt = nil
        inBadBout = false
    }

    // MARK: - Foreground read coordination

    /// True while a foreground read (calibration, a check-in scan, or a
    /// practice session) has taken over the head-motion stream. See
    /// `suspendForForegroundRead()`.
    private var suspendedForForegroundRead = false

    /// A foreground read - the AirPods calibration capture, the 3-second
    /// check-in scan, or a practice/walk session - spins up its OWN
    /// `CMHeadphoneMotionManager`. iOS does not reliably deliver head motion
    /// to two managers at once: a live background monitor starves the read's
    /// manager, so the scan/calibration sits on "waiting for AirPods" and
    /// eventually shows "can't hear your AirPods" even though they're
    /// connected and streaming to us. Suspend our motion stream for the
    /// duration of the read so it has exclusive access. Keeps any silent-audio
    /// keep-alive held (no orange-dot churn); only the motion updates pause.
    /// Idempotent.
    func suspendForForegroundRead() {
        guard isMonitoring, !suspendedForForegroundRead else { return }
        suspendedForForegroundRead = true
        headphoneService.stop()
        persistFlush(minuteBucket.flush())
    }

    /// Resume the background motion stream after a foreground read finishes.
    /// No-op unless we actually suspended. Audio (if Pro/background) was never
    /// torn down, so we only need to re-arm the motion updates.
    func resumeAfterForegroundRead() {
        guard suspendedForForegroundRead else { return }
        suspendedForForegroundRead = false
        guard isMonitoring else { return }
        headphoneService.start()
    }

    // MARK: - Sample handler

    private func onSample(pitch: Double, yaw: Double, roll: Double) {
        // Guard the publishes - samples land at ~25 Hz, and every write to an
        // @Observable property re-renders observers even when the value is
        // unchanged.
        if !isConnected {
            if isMonitoring { logEvent(.connected) }
            isConnected = true
        }
        countSample()

        let calibration = calibrationService.current()
        // Honest scoring needs a real AirPods baseline. Without one, `pitch - 0`
        // treats raw head pitch (often ~0.2 rad just sitting normally) as a
        // slouch and the monitor flags/buzzes constantly. Keep publishing
        // liveness (samples are flowing) but don't score or record until the
        // user has calibrated with AirPods in. `basePitch` is the legacy camera
        // baseline and is 0 for every AirPods-era user, so it can't stand in.
        guard let baseline = calibration?.airpodsPitch else {
            if currentQuality != .good { currentQuality = .good }
            resetDetectionState()
            return
        }
        let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)
        let sensitivity = GoalSettings.shared.sensitivity

        // Score off the smoothed pitch, not the raw sample, so ordinary head
        // motion doesn't flicker the verdict.
        smoothedPitch = PostureScoring.smoothed(
            previous: smoothedPitch, sample: pitch, alpha: smoothingAlpha
        )
        let scoredPitch = smoothedPitch ?? pitch
        // Standing and sitting have different honest head positions AND
        // different slouch ranges - score against whichever aligned baseline
        // is nearer, with that posture's own calibrated slouch delta.
        let reference = PostureScoring.postureReference(
            pitch: scoredPitch,
            standing: calibration?.airpodsStandingPitch,
            sitting: calibration?.airpodsSittingPitch,
            combined: baseline,
            standingSlouchDelta: calibration?.standingSlouchDelta,
            sittingSlouchDelta: calibration?.sittingSlouchDelta,
            fallbackSlouchDelta: slouchDelta
        )
        let instant = PostureScoring.quality(
            deviation: scoredPitch - reference.baseline,
            slouchDelta: reference.slouchDelta,
            sensitivity: sensitivity
        )

        // The "right now" readout tracks the current (smoothed) position with
        // no delay - it's a quick glance, not a verdict. The EMA above already
        // absorbs raw jitter, so this won't strobe. Sustained-time logic lives
        // only in the nudge below (buzz/record), never in what's displayed.
        if instant != currentQuality { currentQuality = instant }
        let now = Date.now
        persistFlush(minuteBucket.accumulate(quality: instant, at: now).flush)
        updateSlouchNudge(instant: instant, now: now)
    }

    // MARK: - Minute persistence

    private func persistFlush(_ flush: MinuteBucket.Flush?) {
        // Foreground glance readouts never persist - see `persistsMinutes`.
        guard persistsMinutes, let flush else { return }
        let row = PostureMinuteSample(
            minuteStart: flush.minuteStart,
            goodSeconds: flush.goodSeconds,
            borderlineSeconds: flush.borderlineSeconds,
            badSeconds: flush.badSeconds,
            source: .airpods
        )
        modelContext.insert(row)
        try? modelContext.save()
    }

    /// Drop minute rows past retention so the store stays lean.
    private func pruneOldMinuteSamples() {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -Self.minuteRetentionDays, to: DateHelpers.startOfDay()
        ) ?? .distantPast
        try? modelContext.delete(
            model: PostureMinuteSample.self,
            where: #Predicate { $0.minuteStart < cutoff }
        )
        try? modelContext.save()
    }

    /// The nudge (haptic + recorded sample) fires only after a long *continuous*
    /// slouch. Borderline drift neither advances nor resets the clock; good
    /// resets it and re-arms the next bout.
    private func updateSlouchNudge(instant: PostureQuality, now: Date) {
        switch instant {
        case .good:
            if inBadBout { logEvent(.recovered) }
            firstBadAt = nil
            inBadBout = false
        case .borderline:
            break
        case .bad:
            if let started = firstBadAt {
                if !inBadBout, now.timeIntervalSince(started) >= slouchNudgeSeconds {
                    recordSlouchEvent(severity: 1.0)
                    triggerHaptic()
                    // One record + buzz per bout. Re-arms when posture
                    // returns to `.good`, not when the threshold lapses
                    // again - otherwise a 30-min slouch writes hundreds
                    // of rows.
                    inBadBout = true
                }
            } else {
                firstBadAt = now
            }
        }
    }

    // MARK: - Recording

    private func recordSlouchEvent(severity: Double) {
        let sample = PosturePassiveSample(
            severity: severity,
            source: .airpods
        )
        modelContext.insert(sample)
        try? modelContext.save()
        logEvent(.slouchLogged)
    }

    /// Tally a motion sample, publishing the observable count + freshness
    /// stamp at most once per second.
    private func countSample() {
        unpublishedSampleCount += 1
        let now = Date.now
        guard now.timeIntervalSince(lastSamplePublishAt) >= 1 else { return }
        lastSamplePublishAt = now
        let today = DateHelpers.startOfDay()
        if today != sampleCountDay {
            sampleCountDay = today
            samplesToday = 0
        }
        samplesToday += unpublishedSampleCount
        unpublishedSampleCount = 0
        lastSampleAt = now
    }

    // MARK: - Haptic

    private func triggerHaptic() {
        let now = Date.now
        guard now.timeIntervalSince(lastHapticAt) >= hapticDebounceSeconds else { return }
        lastHapticAt = now
        AudioServicesPlaySystemSound(1520)
    }
}

// MARK: - Activity log entries

/// One line in the monitor's running activity log. In-memory, newest first.
struct MonitorEvent: Identifiable, Sendable {
    enum Kind: Sendable {
        case armed(background: Bool)
        case stopped
        case connected
        case disconnected
        case slouchLogged
        case recovered
        case audioInterrupted
        case audioResumed
        case error(String)
    }

    let id = UUID()
    let timestamp: Date
    let kind: Kind
}

// MARK: - Errors

enum MonitorError: LocalizedError {
    case bufferCreationFailed
    case formatCreationFailed

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed: return "Could not create silent audio buffer"
        case .formatCreationFailed: return "Could not create silent audio format"
        }
    }
}

#endif
