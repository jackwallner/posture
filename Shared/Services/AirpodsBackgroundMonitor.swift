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

    // MARK: - Slouch detection (time-based)

    /// When the user first entered `.bad`. Reset on `.good` or on AirPods
    /// disconnect. We trigger a haptic + record a sample after this much
    /// continuous bad posture.
    private var firstBadAt: Date?
    private let badDurationThreshold: TimeInterval = 3.0

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
    }

    private func handleConnect(_ connected: Bool) {
        isConnected = connected
        if !connected {
            currentQuality = .good
            firstBadAt = nil
        }
    }

    // MARK: - Start / Stop

    /// Public for UI: are we currently running with the background audio
    /// session attached (the Pro extension) or foreground-only?
    private(set) var isBackground = false

    /// Start monitoring. `background: true` attaches a silent audio session
    /// so motion samples keep flowing while the app is suspended — this is
    /// the Pro tier behavior and shows the iOS orange dot. `background:
    /// false` starts motion only; iOS will suspend it when the app leaves
    /// the foreground. Returns false if AirPods aren't available.
    @discardableResult
    func start(background: Bool = true) -> Bool {
        guard !isMonitoring else { return true }
        guard headphoneService.isAvailable else {
            lastError = "AirPods with head tracking not available"
            return false
        }

        if background {
            do {
                try startAudioSession()
                try startSilentAudio()
            } catch {
                lastError = "Audio setup failed: \(error.localizedDescription)"
                stop()
                return false
            }
        }

        headphoneService.start()
        isMonitoring = true
        isBackground = background
        lastError = nil
        return true
    }

    func stop() {
        headphoneService.stop()
        stopSilentAudio()
        stopAudioSession()
        isMonitoring = false
        isBackground = false
        isConnected = false
        currentQuality = .good
    }

    // MARK: - Sample handler

    private func onSample(pitch: Double, yaw: Double, roll: Double) {
        isConnected = true

        let calibration = calibrationService.current()
        // AirPods motion lives in a different reference frame than the front
        // camera. Prefer the AirPods baseline; fall back to camera only if
        // calibration predates the AirPods path.
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
        case .borderline:
            // Drifting — don't restart the clock, but don't trigger either.
            break
        case .bad:
            if let started = firstBadAt {
                if now.timeIntervalSince(started) >= badDurationThreshold {
                    recordSlouchEvent(severity: 1.0)
                    triggerHaptic()
                    // Hold off until the next sustained slouch — we already
                    // told them once.
                    firstBadAt = nil
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
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func stopAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Silent Audio

    private func startSilentAudio() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

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

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed: return "Could not create silent audio buffer"
        }
    }
}

#endif
