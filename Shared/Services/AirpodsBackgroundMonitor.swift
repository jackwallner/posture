// AirPods background monitoring is iOS-only — requires audio session + AVFoundation + CoreMotion
#if os(iOS)

import AVFoundation
import CoreMotion
import SwiftData
import SwiftUI
import UIKit

/// Background AirPods posture monitor (Pro feature).
///
/// Plays a silent audio track to keep `CMHeadphoneMotionManager` delivering
/// head-pose updates in the background, evaluates posture against the user's
/// calibration, records slouch events as `PosturePassiveSample`, and triggers
/// haptic feedback when the user slouches.
///
/// - Requires: `UIBackgroundModes: audio` in Info.plist
/// - Requires: Pro subscription (gated by the caller)
@MainActor
@Observable
final class AirpodsBackgroundMonitor {
    // MARK: - Public state

    private(set) var isMonitoring = false
    private(set) var isAvailable = false
    private(set) var isConnected = false
    private(set) var currentQuality: PostureQuality = .good
    private(set) var lastError: String?

    // MARK: - Dependencies

    private let headphoneService: HeadphoneMotionService
    private let calibrationService: CalibrationService
    private let modelContext: ModelContext

    // MARK: - Audio engine (silent track for background delivery)

    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioObservers: [NSObjectProtocol] = []

    // MARK: - Slouch detection (time-based)

    /// When the user first entered `.bad`. Reset on `.good` or on AirPods
    /// disconnect. We trigger a haptic + record a sample after this much
    /// continuous bad posture.
    private var firstBadAt: Date?
    private let badDurationThreshold: TimeInterval = 3.0

    /// Have we already fired the slouch event for the current bad bout?
    /// Keeps a long slouch from spamming `PosturePassiveSample` rows every
    /// 3 seconds. Reset on `.good` or disconnect.
    private var inBadBout = false

    /// Haptic debounce so we don't buzz the user every few seconds.
    private var lastHapticAt: Date = .distantPast
    private let hapticDebounceSeconds: TimeInterval = 60

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
        // device switch). Don't tear down — just reflect the truth in UI so
        // the user sees we're "armed and waiting" vs "live."
        headphoneService.onConnect = { [weak self] connected in
            self?.handleConnect(connected)
        }

        observeAudioNotifications()
    }

    // Intentionally no deinit: `audioObservers` is @MainActor-isolated and
    // deinit is nonisolated, so we can't touch it here. The monitor is
    // process-scoped via `.shared` and never deallocs in practice.

    /// Process-scoped instance. Constructed lazily on first access and
    /// reused for the life of the app — avoids the SwiftUI `@State` default-
    /// value footgun where the parent View's body recomputation builds a new
    /// monitor on every render. Each rebuild adds NotificationCenter
    /// observers that survive the dropped instance.
    @MainActor static let shared = AirpodsBackgroundMonitor(
        modelContext: DataService.sharedModelContainer.mainContext
    )

    private func handleConnect(_ connected: Bool) {
        isConnected = connected
        if !connected {
            currentQuality = .good
            firstBadAt = nil
            inBadBout = false
            return
        }
        // AirPods just became available. If start() previously returned
        // false because no head-tracking AirPods were connected, the user
        // is now in the "armed and waiting" state — activate motion now.
        isAvailable = headphoneService.isAvailable
        if isMonitoring && !headphoneService.isRunning {
            activateMotion()
        }
    }

    // MARK: - Start / Stop

    /// Public for UI: are we currently running with the background audio
    /// session attached (the Pro extension) or foreground-only?
    private(set) var isBackground = false

    /// Arm monitoring. `background: true` attaches a silent audio session
    /// so motion samples keep flowing while the app is suspended — this is
    /// the Pro tier behavior and shows the iOS orange dot. `background:
    /// false` starts motion only; iOS will suspend it when the app leaves
    /// the foreground. Returns true as long as the monitor is armed, even
    /// if AirPods aren't currently connected — motion activates when they
    /// appear via the connect callback.
    @discardableResult
    func start(background: Bool = true) -> Bool {
        guard !isMonitoring else { return true }
        isMonitoring = true
        isBackground = background
        lastError = nil
        activateMotion()
        return true
    }

    /// Wire up audio (if Pro/background) and start head-motion updates. Safe
    /// to call repeatedly — guarded by `headphoneService.isRunning` and the
    /// engine's own `isRunning`. Called from `start()` and from
    /// `handleConnect(true)` when AirPods appear after a cold launch.
    private func activateMotion() {
        guard isMonitoring else { return }
        isAvailable = headphoneService.isAvailable
        guard headphoneService.isAvailable else { return }

        if isBackground {
            do {
                if AVAudioSession.sharedInstance().category != .playback {
                    try startAudioSession()
                }
                if audioEngine?.isRunning != true {
                    try startSilentAudio()
                }
            } catch {
                lastError = "Audio setup failed: \(error.localizedDescription)"
                return
            }
        }
        headphoneService.start()
    }

    func stop() {
        isMonitoring = false
        isBackground = false
        headphoneService.stop()
        stopSilentAudio()
        stopAudioSession()
        isConnected = false
        currentQuality = .good
        firstBadAt = nil
        inBadBout = false
    }

    // MARK: - Foreground read coordination

    /// True while a foreground read (calibration or a check-in scan) has taken
    /// over the head-motion stream. See `suspendForForegroundRead()`.
    private var suspendedForForegroundRead = false

    /// A foreground read — the AirPods calibration capture or the 3-second
    /// check-in scan — spins up its OWN `CMHeadphoneMotionManager`. iOS does
    /// not reliably deliver head motion to two managers at once: a live
    /// background monitor starves the read's manager, so the scan/calibration
    /// sits on "waiting for AirPods" and eventually shows "can't hear your
    /// AirPods" even though they're connected and streaming to us. Suspend our
    /// motion stream for the duration of the read so it has exclusive access.
    /// Keeps any silent-audio session alive (no orange-dot churn); only the
    /// motion updates pause. Idempotent.
    func suspendForForegroundRead() {
        guard isMonitoring, !suspendedForForegroundRead else { return }
        suspendedForForegroundRead = true
        headphoneService.stop()
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
        isConnected = true

        let calibration = calibrationService.current()
        // Prefer the AirPods head-motion baseline; `basePitch` is the legacy
        // calibration value retained for users whose calibration predates the
        // AirPods path.
        let baseline = calibration?.airpodsPitch ?? calibration?.basePitch ?? 0
        let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)
        let sensitivity = GoalSettings.shared.sensitivity

        let deviation = pitch - baseline
        let quality = PostureScoring.quality(
            deviation: deviation,
            slouchDelta: slouchDelta,
            sensitivity: sensitivity
        )
        currentQuality = quality

        let now = Date.now
        switch quality {
        case .good:
            firstBadAt = nil
            inBadBout = false
        case .borderline:
            // Drifting — don't restart the clock, but don't trigger either.
            break
        case .bad:
            if let started = firstBadAt {
                if !inBadBout, now.timeIntervalSince(started) >= badDurationThreshold {
                    recordSlouchEvent(severity: 1.0)
                    triggerHaptic()
                    // One record + buzz per bout. Re-arms when posture
                    // returns to `.good`, not when the threshold lapses
                    // again — otherwise a 30-min slouch writes hundreds
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
    }

    // MARK: - Haptic

    private func triggerHaptic() {
        let now = Date.now
        guard now.timeIntervalSince(lastHapticAt) >= hapticDebounceSeconds else { return }
        lastHapticAt = now
        AudioServicesPlaySystemSound(1520)
    }

    // MARK: - Audio Session

    private func startAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers only — the silent keep-alive tone must be both
        // inaudible AND non-interfering. .duckOthers would audibly lower the
        // user's music/podcasts the entire time monitoring is armed, which is
        // a real UX complaint and sharpens the 2.5.4 "no audible content" case.
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func stopAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    // MARK: - Interruption + config-change recovery

    /// A phone call, Siri, or another app taking the audio session will
    /// pause our silent track. When the interruption ends we must reactivate
    /// the session AND restart the engine — `AVAudioEngine` doesn't resume
    /// itself. Same for `AVAudioEngineConfigurationChange`, which fires when
    /// the route changes (AirPods leaving, CarPlay handoff). Without these
    /// observers the "always-on" Pro feature silently dies the first time a
    /// call comes in.
    ///
    /// Use block-based observers that hop to MainActor — system audio
    /// notifications post on private queues, so a selector-based observer on
    /// a `@MainActor` class would trip Swift 6 isolation.
    private func observeAudioNotifications() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { @Sendable [weak self] note in
            // Pull the raw type out here — `userInfo` is `[AnyHashable: Any]?`
            // which isn't Sendable, so we can't ferry it across the actor hop.
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in self?.handleInterruption(rawType: raw) }
        }
        let configChange = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { @Sendable [weak self] _ in
            Task { @MainActor in self?.handleEngineConfigChange() }
        }
        audioObservers = [interruption, configChange]
    }

    private func handleInterruption(rawType: UInt?) {
        guard
            let raw = rawType,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        switch type {
        case .began:
            // Engine has stopped. Nothing to do until .ended fires.
            break
        case .ended:
            guard isMonitoring, isBackground else { return }
            resumeSilentAudio()
        @unknown default:
            break
        }
    }

    private func handleEngineConfigChange() {
        guard isMonitoring, isBackground else { return }
        resumeSilentAudio()
    }

    private func resumeSilentAudio() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                true,
                options: .notifyOthersOnDeactivation
            )
            if let engine = audioEngine, !engine.isRunning {
                try engine.start()
                audioPlayer?.play()
            } else if audioEngine == nil {
                try startSilentAudio()
            }
            lastError = nil
        } catch {
            lastError = "Could not resume audio: \(error.localizedDescription)"
        }
    }

    // MARK: - Silent Audio

    private func startSilentAudio() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            throw MonitorError.formatCreationFailed
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100) else {
            throw MonitorError.bufferCreationFailed
        }
        buffer.frameLength = 44100

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.volume = 0.01

        try engine.start()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()

        self.audioEngine = engine
        self.audioPlayer = player
    }

    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioEngine?.stop()
        audioPlayer = nil
        audioEngine = nil
    }
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
