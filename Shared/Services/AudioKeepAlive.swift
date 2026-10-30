// iOS-only: silent-audio keep-alive for background CoreMotion delivery.
#if os(iOS)

import AVFoundation

/// Plays a silent looping tone so iOS keeps delivering `CMHeadphoneMotionManager`
/// updates while the app is backgrounded (requires `UIBackgroundModes: audio`;
/// shows the orange dot). Refcounted so the all-day monitor and a bounded
/// practice/walk session can hold it independently: the engine starts on the
/// first `acquire` and stops when the last holder releases.
///
/// Extracted from `AirpodsBackgroundMonitor` so a session can keep itself
/// alive through a screen lock for a bounded few minutes without arming the
/// indefinite monitor.
@MainActor
@Observable
final class AudioKeepAlive {
    static let shared = AudioKeepAlive()

    enum Event: Sendable {
        case interrupted
        case resumed
        case error(String)
    }

    private(set) var lastError: String?

    /// Single observer hook for activity logging. Only the all-day monitor
    /// assigns this (its MonitoringLogView surfaces audio health); sessions
    /// don't need it.
    var onEvent: ((Event) -> Void)?

    private var holders: Set<String> = []
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioObservers: [NSObjectProtocol] = []
    /// A call or Siri holds the session; `.ended` resumes the engine.
    private var isInterrupted = false

    private init() {
        observeAudioNotifications()
    }

    // Intentionally no deinit: `audioObservers` is @MainActor-isolated and
    // deinit is nonisolated. This is a process-scoped singleton and never
    // deallocs in practice.

    /// Start (or keep) the silent keep-alive on behalf of `token`. Errors are
    /// recorded in `lastError` rather than thrown - a failed keep-alive
    /// degrades to foreground-only motion, it doesn't break the feature.
    func acquire(_ token: String) {
        let wasEmpty = holders.isEmpty
        holders.insert(token)
        guard wasEmpty else {
            // Already held, but a failed rebuild or a route change can leave
            // the engine stopped: restart it rather than trust the hold.
            if !isInterrupted, audioEngine?.isRunning != true { resumeSilentAudio() }
            return
        }
        do {
            try startAudioSession()
            if audioEngine?.isRunning != true {
                try startSilentAudio()
            }
            lastError = nil
        } catch {
            lastError = "Audio setup failed: \(error.localizedDescription)"
            onEvent?(.error(lastError ?? "audio error"))
            // Don't keep the hold: a held token makes every later acquire a
            // no-op, so the keep-alive would never be retried.
            holders.remove(token)
            stopSilentAudio()
            stopAudioSession()
        }
    }

    /// Release `token`'s hold. Tears the engine + session down when nobody
    /// is left. Safe to call for a token that never acquired.
    func release(_ token: String) {
        holders.remove(token)
        guard holders.isEmpty else { return }
        stopSilentAudio()
        stopAudioSession()
    }

    var isHeld: Bool { !holders.isEmpty }

    // MARK: - Audio session

    private func startAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers only - the silent keep-alive tone must be both
        // inaudible AND non-interfering. .duckOthers would audibly lower the
        // user's music/podcasts the entire time it's held, which is a real UX
        // complaint and sharpens the 2.5.4 "no audible content" case.
        if session.category != .playback {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
        }
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
    /// the session AND restart the engine - `AVAudioEngine` doesn't resume
    /// itself. Same for `AVAudioEngineConfigurationChange`, which fires when
    /// the route changes (AirPods leaving, CarPlay handoff). Without these
    /// observers the keep-alive silently dies the first time a call comes in.
    ///
    /// Use block-based observers that hop to MainActor - system audio
    /// notifications post on private queues, so a selector-based observer on
    /// a `@MainActor` class would trip Swift 6 isolation.
    private func observeAudioNotifications() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { @Sendable [weak self] note in
            // Pull the raw type out here - `userInfo` is `[AnyHashable: Any]?`
            // which isn't Sendable, so we can't ferry it across the actor hop.
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in self?.handleInterruption(rawType: raw) }
        }
        // On the main queue so the notice's engine is compared by reference
        // while the notice still holds it (a freed engine's address can be
        // reused by its replacement).
        let configChange = center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // Delivered on .main, so the engine never leaves the main thread.
            nonisolated(unsafe) let engine = note.object as AnyObject?
            MainActor.assumeIsolated {
                self?.handleEngineConfigChange(from: engine)
            }
        }
        // AirPods leaving or coming back. The config-change notice usually
        // covers this, but if the engine still ended up stopped, iOS suspends
        // the app moments later and nothing resumes when the buds return.
        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { @Sendable [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in self?.handleRouteChange(rawReason: raw) }
        }
        audioObservers = [interruption, configChange, routeChange]
    }

    private func handleRouteChange(rawReason: UInt?) {
        guard isHeld, audioEngine?.isRunning != true,
              let raw = rawReason,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
              reason == .newDeviceAvailable || reason == .oldDeviceUnavailable else { return }
        resumeSilentAudio(rebuild: true)
    }

    private func handleInterruption(rawType: UInt?) {
        guard
            let raw = rawType,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        switch type {
        case .began:
            // Engine has stopped. Nothing to do until .ended fires.
            isInterrupted = true
            if isHeld { onEvent?(.interrupted) }
        case .ended:
            isInterrupted = false
            guard isHeld else { return }
            resumeSilentAudio()
        @unknown default:
            break
        }
    }

    /// A new output route can change the hardware format, which leaves the
    /// old player's connection and looping buffer stale, so rebuild it.
    /// Ignores notices from an engine already replaced, so a route change that
    /// rebuilt first doesn't get its fresh engine torn down again.
    private func handleEngineConfigChange(from engine: AnyObject?) {
        guard isHeld, let current = audioEngine, engine === current else { return }
        resumeSilentAudio(rebuild: true)
    }

    private func resumeSilentAudio(rebuild: Bool = false) {
        do {
            try AVAudioSession.sharedInstance().setActive(
                true,
                options: .notifyOthersOnDeactivation
            )
            if rebuild {
                stopSilentAudio()
                try startSilentAudio()
            } else if let engine = audioEngine, !engine.isRunning {
                try engine.start()
                audioPlayer?.play()
            } else if audioEngine == nil {
                try startSilentAudio()
            }
            lastError = nil
            isInterrupted = false
            onEvent?(.resumed)
        } catch {
            lastError = "Could not resume audio: \(error.localizedDescription)"
            onEvent?(.error(lastError ?? "audio error"))
        }
    }

    // MARK: - Silent engine

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

#endif
