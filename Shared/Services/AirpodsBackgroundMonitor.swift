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

    // MARK: - Haptic debounce

    private var lastHapticAt: Date = .distantPast
    private let hapticDebounceSeconds: TimeInterval = 60
    private var consecutiveBadCount = 0

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.headphoneService = HeadphoneMotionService()
        self.calibrationService = CalibrationService(context: modelContext)
        self.modelContext = modelContext
        self.isAvailable = headphoneService.isAvailable

        headphoneService.onSample = { [weak self] pitch, yaw, roll in
            self?.onSample(pitch: pitch, yaw: yaw, roll: roll)
        }
    }

    // MARK: - Start / Stop

    /// Start background monitoring. Returns false if AirPods aren't available.
    @discardableResult
    func start() -> Bool {
        guard !isMonitoring else { return true }
        guard headphoneService.isAvailable else {
            lastError = "AirPods with head tracking not available"
            return false
        }

        do {
            try startAudioSession()
            try startSilentAudio()
        } catch {
            lastError = "Audio setup failed: \(error.localizedDescription)"
            stop()
            return false
        }

        headphoneService.start()
        isMonitoring = true
        lastError = nil
        return true
    }

    func stop() {
        headphoneService.stop()
        stopSilentAudio()
        stopAudioSession()
        isMonitoring = false
        isConnected = false
        currentQuality = .good
    }

    // MARK: - Sample handler

    private func onSample(pitch: Double, yaw: Double, roll: Double) {
        isConnected = true

        let calibration = calibrationService.current()
        let baseline = calibration?.basePitch ?? 0
        let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)
        let sensitivity = GoalSettings.shared.sensitivity

        let deviation = pitch - baseline
        let quality = PostureScoring.quality(
            deviation: deviation,
            slouchDelta: slouchDelta,
            sensitivity: sensitivity
        )
        currentQuality = quality

        switch quality {
        case .good:
            consecutiveBadCount = 0
        case .borderline:
            consecutiveBadCount += 1
        case .bad:
            consecutiveBadCount += 1
            if consecutiveBadCount >= 3 {
                recordSlouchEvent(severity: 1.0)
                triggerHaptic()
                consecutiveBadCount = 0
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
