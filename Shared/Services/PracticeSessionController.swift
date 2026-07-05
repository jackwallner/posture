// Practice sessions are iOS-only — they read AirPods head motion.
#if os(iOS)

import AudioToolbox
import Foundation
import SwiftData
import UIKit
import UserNotifications

/// Drives one bounded posture session (daily practice now; walks in a later
/// phase): owns the motion stream for its duration, scores every sample,
/// accrues elapsed time from observed samples only, and writes the results.
///
/// Deliberately NOT an extension of `AirpodsBackgroundMonitor` — the all-day
/// monitor is a process-scoped singleton with all-day semantics (retention
/// pruning, long haptic debounce). A session wants tighter feedback constants
/// and a lifecycle tied to a view. The two share `PostureScoring` and
/// `MinuteBucket` so their numbers always agree.
@MainActor
@Observable
final class PracticeSessionController {
    enum PauseReason: Equatable {
        case airpodsOut
        case user
    }

    enum Phase: Equatable {
        case idle
        /// Armed, waiting for the first scored AirPods sample.
        case waiting
        case running
        case paused(PauseReason)
        case finished
    }

    struct Config: Sendable {
        let kind: PostureSessionKind
        let targetSeconds: Int
        let targetPercent: Int
        let level: Int
    }

    struct Result: Sendable {
        let kind: PostureSessionKind
        let alignedPercent: Int
        let completed: Bool
        let passed: Bool
        let goodSeconds: Int
        let borderlineSeconds: Int
        let badSeconds: Int
        /// Aligned fraction per segment (10s for practice, 60s for walks),
        /// for the summary strip.
        let timeline: [Double]
        let level: Int
        let newLevel: Int
        let leveledUp: Bool
        let streakDays: Int
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .idle
    private(set) var elapsedSeconds: Double = 0
    private(set) var currentQuality: PostureQuality = .good
    private(set) var result: Result?
    private(set) var config: Config?
    private(set) var lastError: String?

    var remainingSeconds: Int {
        guard let config else { return 0 }
        return max(0, config.targetSeconds - Int(elapsedSeconds))
    }

    /// Weighted aligned fraction so far (good = 1, borderline = 0.5).
    var alignedFractionSoFar: Double {
        let total = goodSeconds + borderlineSeconds + badSeconds
        guard total > 0 else { return 0 }
        return (goodSeconds + borderlineSeconds * 0.5) / total
    }

    // MARK: - Internals

    private let motion = HeadphoneMotionService()
    private let context: ModelContext
    private let calibrationService: CalibrationService

    private var smoothedPitch: Double?
    private let smoothingAlpha = 0.15

    private var goodSeconds: Double = 0
    private var borderlineSeconds: Double = 0
    private var badSeconds: Double = 0
    private var minuteBucket = MinuteBucket()

    // Segment timeline for the summary strip (10s practice, 60s walk —
    // a 30-min walk at 10s segments would be an unreadable 180 bars).
    private var timeline: [Double] = []
    private var segmentSeconds: Double = 0
    private var segmentAligned: Double = 0
    private var segmentLength: Double = 10

    // In-session slouch nudge: tighter than the all-day monitor — the whole
    // point of practice is immediate feedback. Walks nudge slower and rarer.
    private var firstBadAt: Date?
    private var inBadBout = false
    private var lastHapticAt: Date = .distantPast
    private var slouchNudgeSeconds: TimeInterval = 15
    private var hapticDebounceSeconds: TimeInterval = 20

    // Walk mode: rolling window of raw samples; the verdict recomputes at
    // most once a second off the window median (gait bob cancels out).
    private var walkSamples: [(t: TimeInterval, pitch: Double)] = []
    private var lastWalkVerdictAt: TimeInterval = 0

    /// Sessions under this long aren't worth a row — an instant cancel is
    /// noise, not an attempt.
    private static let minRecordSeconds: Double = 30

    private static let keepAliveToken = "session"

    var isAirpodsConnected: Bool { motion.isConnected }

    /// Tracked via lifecycle notifications — `UIApplication.shared` is
    /// unavailable in the extension targets that also compile Shared/.
    private var isAppInBackground = false
    private var lifecycleObservers: [NSObjectProtocol] = []

    init(context: ModelContext) {
        self.context = context
        self.calibrationService = CalibrationService(context: context)
        motion.onSample = { [weak self] pitch, _, _ in
            self?.ingest(pitch: pitch, at: .now)
        }
        motion.onConnect = { [weak self] connected in
            self?.handleConnect(connected)
        }
        let center = NotificationCenter.default
        let toBackground = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { @Sendable [weak self] _ in
            Task { @MainActor in self?.isAppInBackground = true }
        }
        let toForeground = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
        ) { @Sendable [weak self] _ in
            Task { @MainActor in self?.isAppInBackground = false }
        }
        lifecycleObservers = [toBackground, toForeground]
    }

    // MARK: - Config

    /// Count of passed practice sessions — the input to the level ramp.
    static func passedPracticeCount(context: ModelContext) -> Int {
        let practiceRaw = PostureSessionKind.practice.rawValue
        let descriptor = FetchDescriptor<PostureSession>(
            predicate: #Predicate { $0.kindRaw == practiceRaw && $0.passed }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Today's practice config from the level ramp (free users cap at
    /// `PracticeProgression.freeLevelCap`).
    static func nextConfig(context: ModelContext, isPro: Bool) -> Config {
        let passed = passedPracticeCount(context: context)
        let level = PracticeProgression.effectiveLevel(
            level: PracticeProgression.level(passedSessions: passed),
            isPro: isPro
        )
        return Config(
            kind: .practice,
            targetSeconds: PracticeProgression.sessionSeconds(forLevel: level),
            targetPercent: PracticeProgression.targetPercent(forLevel: level),
            level: level
        )
    }

    // MARK: - Lifecycle

    func start(config: Config) {
        guard phase == .idle || phase == .finished else { return }
        guard calibrationService.current()?.airpodsPitch != nil else {
            lastError = "Calibrate with AirPods before a session."
            return
        }
        self.config = config
        result = nil
        lastError = nil
        elapsedSeconds = 0
        goodSeconds = 0
        borderlineSeconds = 0
        badSeconds = 0
        timeline = []
        segmentSeconds = 0
        segmentAligned = 0
        smoothedPitch = nil
        firstBadAt = nil
        inBadBout = false
        minuteBucket = MinuteBucket()
        walkSamples = []
        lastWalkVerdictAt = 0
        currentQuality = .good
        if config.kind == .walk {
            segmentLength = 60
            slouchNudgeSeconds = PostureScoring.Walk.nudgeSustainSeconds
            hapticDebounceSeconds = PostureScoring.Walk.nudgeDebounceSeconds
        } else {
            segmentLength = 10
            slouchNudgeSeconds = 15
            hapticDebounceSeconds = 20
        }
        phase = .waiting

        // Take exclusive ownership of the head-motion stream — iOS starves a
        // second CMHeadphoneMotionManager while the monitor's is live.
        AirpodsBackgroundMonitor.shared.suspendForForegroundRead()
        // Keep motion flowing through a screen lock for the bounded duration.
        AudioKeepAlive.shared.acquire(Self.keepAliveToken)
        motion.start()
        AnalyticsService.sessionStarted(source: .airpods, targetSeconds: config.targetSeconds)
    }

    func pauseByUser() {
        guard phase == .running || phase == .waiting else { return }
        persistFlush(minuteBucket.flush())
        motion.stop()
        phase = .paused(.user)
        AnalyticsService.sessionPaused()
    }

    func resume() {
        guard case .paused(.user) = phase else { return }
        phase = .waiting
        motion.start()
        AnalyticsService.sessionResumed()
    }

    /// End before the target. Writes an honest partial row (no streak or
    /// level credit) when the attempt was long enough to mean something.
    func endEarly() {
        guard phase != .idle, phase != .finished else { return }
        AnalyticsService.sessionCancelled()
        finish(completed: false)
    }

    /// Abandon without recording anything (view dismissed instantly).
    func cancel() {
        guard phase != .idle else { return }
        if elapsedSeconds >= Self.minRecordSeconds {
            endEarly()
            return
        }
        teardown()
        phase = .idle
        config = nil
    }

    // MARK: - Sample path

    private func handleConnect(_ connected: Bool) {
        guard phase == .running || phase == .waiting else { return }
        if !connected {
            persistFlush(minuteBucket.flush())
            firstBadAt = nil
            inBadBout = false
            smoothedPitch = nil
            phase = .paused(.airpodsOut)
        }
        // Reconnect: HeadphoneMotionService's wantsToRun re-arms motion on its
        // own; the next scored sample flips us back to .running in ingest.
    }

    /// Score one sample and advance the session clock by the observed dt.
    /// Internal (not private) so tests can drive synthetic streams.
    func ingest(pitch: Double, at now: Date) {
        switch phase {
        case .waiting, .paused(.airpodsOut):
            phase = .running
        case .running:
            break
        case .idle, .finished, .paused(.user):
            return
        }

        guard let config, let calibration = calibrationService.current(),
              let baseline = calibration.airpodsPitch else { return }

        let quality: PostureQuality
        if config.kind == .walk {
            quality = walkQuality(pitch: pitch, at: now, calibration: calibration, combined: baseline)
        } else {
            smoothedPitch = PostureScoring.smoothed(
                previous: smoothedPitch, sample: pitch, alpha: smoothingAlpha
            )
            let scoredPitch = smoothedPitch ?? pitch
            let referenceBaseline = PostureScoring.nearestBaseline(
                pitch: scoredPitch,
                standing: calibration.airpodsStandingPitch,
                sitting: calibration.airpodsSittingPitch,
                combined: baseline
            )
            quality = PostureScoring.quality(
                deviation: scoredPitch - referenceBaseline,
                slouchDelta: calibration.slouchPitchDelta,
                sensitivity: GoalSettings.shared.sensitivity
            )
        }
        if quality != currentQuality { currentQuality = quality }

        // Elapsed accrues from observed sample gaps (clamped), never a Timer —
        // pods-out or a suspension can't credit phantom time, and pausing
        // falls out for free.
        let (credited, flush) = minuteBucket.accumulate(quality: quality, at: now)
        persistFlush(flush)
        elapsedSeconds += credited
        // A walk's first stretch (pocketing the phone, finding stride) runs
        // the clock but stays out of the score and timeline.
        let inWarmup = config.kind == .walk && elapsedSeconds <= PostureScoring.Walk.warmupSeconds
        if !inWarmup {
            switch quality {
            case .good: goodSeconds += credited
            case .borderline: borderlineSeconds += credited
            case .bad: badSeconds += credited
            }
            accrueTimeline(credited: credited, quality: quality)
        }
        updateSlouchNudge(quality: quality, now: now)

        if Int(elapsedSeconds) >= config.targetSeconds {
            finish(completed: true)
        }
    }

    /// Walk verdict: median head pitch over the rolling window, judged
    /// against the standing baseline with relaxed thresholds. Recomputes at
    /// most once a second; between verdicts the last one holds.
    private func walkQuality(
        pitch: Double, at now: Date, calibration: Calibration, combined: Double
    ) -> PostureQuality {
        let t = now.timeIntervalSinceReferenceDate
        walkSamples.append((t, pitch))
        let cutoff = t - PostureScoring.Walk.windowSeconds
        if let firstKeep = walkSamples.firstIndex(where: { $0.t >= cutoff }), firstKeep > 0 {
            walkSamples.removeFirst(firstKeep)
        }
        guard t - lastWalkVerdictAt >= 1 else { return currentQuality }
        // Walking is standing — judge against the standing baseline when we
        // have one instead of the sitting-blurred combined number.
        let walkBaseline = calibration.airpodsStandingPitch ?? combined
        guard let deviation = PostureScoring.walkWindowDeviation(
            samples: walkSamples, baseline: walkBaseline, now: t
        ) else { return currentQuality }
        lastWalkVerdictAt = t
        return PostureScoring.quality(
            deviation: deviation,
            slouchDelta: calibration.slouchPitchDelta,
            sensitivity: PostureScoring.Walk.sensitivity
        )
    }

    private func accrueTimeline(credited: Double, quality: PostureQuality) {
        segmentSeconds += credited
        switch quality {
        case .good: segmentAligned += credited
        case .borderline: segmentAligned += credited * 0.5
        case .bad: break
        }
        if segmentSeconds >= segmentLength {
            timeline.append(segmentAligned / segmentSeconds)
            segmentSeconds = 0
            segmentAligned = 0
        }
    }

    private func updateSlouchNudge(quality: PostureQuality, now: Date) {
        switch quality {
        case .good:
            firstBadAt = nil
            inBadBout = false
        case .borderline:
            break
        case .bad:
            if let started = firstBadAt {
                if !inBadBout, now.timeIntervalSince(started) >= slouchNudgeSeconds {
                    inBadBout = true
                    guard now.timeIntervalSince(lastHapticAt) >= hapticDebounceSeconds else { return }
                    lastHapticAt = now
                    AudioServicesPlaySystemSound(1520)
                }
            } else {
                firstBadAt = now
            }
        }
    }

    // MARK: - Finish

    private func finish(completed: Bool) {
        guard let config else { return }
        teardown()

        if segmentSeconds >= 2 {
            timeline.append(segmentAligned / segmentSeconds)
        }

        let good = Int(goodSeconds.rounded())
        let borderline = Int(borderlineSeconds.rounded())
        let bad = Int(badSeconds.rounded())
        let alignedPercent = PostureScoring.sessionScore(
            goodSeconds: good, borderlineSeconds: borderline, badSeconds: bad
        )
        // `passed` means level credit, which only practice can earn.
        let passed = config.kind == .practice && completed
            && alignedPercent >= config.targetPercent

        let passedBefore = Self.passedPracticeCount(context: context)
        let levelBefore = PracticeProgression.level(passedSessions: passedBefore)

        let row = PostureSession(
            durationSeconds: Int(elapsedSeconds.rounded()),
            score: alignedPercent,
            goodSeconds: good,
            borderlineSeconds: borderline,
            badSeconds: bad,
            source: .airpods,
            kind: config.kind,
            targetSeconds: config.targetSeconds,
            targetPercent: config.targetPercent,
            alignedPercent: alignedPercent,
            completed: completed,
            passed: passed
        )
        row.startedAt = Date.now.addingTimeInterval(-elapsedSeconds)
        context.insert(row)
        try? context.save()

        var streakDays = 0
        if completed {
            let state = StreakService(context: context).recordSessionCompleted(at: .now)
            streakDays = state.currentStreak
        }

        // Walks never advance the practice level.
        let countsForLevel = config.kind == .practice && passed
        let newLevel = PracticeProgression.level(
            passedSessions: passedBefore + (countsForLevel ? 1 : 0)
        )

        result = Result(
            kind: config.kind,
            alignedPercent: alignedPercent,
            completed: completed,
            passed: passed,
            goodSeconds: good,
            borderlineSeconds: borderline,
            badSeconds: bad,
            timeline: timeline,
            level: config.level,
            newLevel: newLevel,
            leveledUp: newLevel > levelBefore,
            streakDays: streakDays
        )
        phase = .finished
        AnalyticsService.sessionCompleted(
            score: alignedPercent, duration: Int(elapsedSeconds), source: .airpods
        )

        if completed, isAppInBackground {
            postCompletionNotification(kind: config.kind, alignedPercent: alignedPercent, passed: passed)
        }
    }

    /// Stop motion, hand the stream back, drop the keep-alive, flush minutes.
    private func teardown() {
        motion.stop()
        persistFlush(minuteBucket.flush())
        AudioKeepAlive.shared.release(Self.keepAliveToken)
        AirpodsBackgroundMonitor.shared.resumeAfterForegroundRead()
    }

    private func persistFlush(_ flush: MinuteBucket.Flush?) {
        guard let flush else { return }
        let row = PostureMinuteSample(
            minuteStart: flush.minuteStart,
            goodSeconds: flush.goodSeconds,
            borderlineSeconds: flush.borderlineSeconds,
            badSeconds: flush.badSeconds,
            source: .airpods
        )
        context.insert(row)
        try? context.save()
    }

    /// The session hit its target while the phone was locked or backgrounded —
    /// tell the user it's done so they aren't sitting tall for nothing.
    private func postCompletionNotification(kind: PostureSessionKind, alignedPercent: Int, passed: Bool) {
        let content = UNMutableNotificationContent()
        if kind == .walk {
            content.title = "walk done."
        } else {
            content.title = passed ? "practice done. target met." : "practice done."
        }
        content.body = "\(alignedPercent)% aligned today. Your streak is safe."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "posture.practice.finished",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

#endif
