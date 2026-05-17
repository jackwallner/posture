#if os(iOS)
import CoreMotion
import Foundation
import Observation

/// Wraps `CMHeadphoneMotionManager`. Only AirPods Pro / 3rd-gen / Max provide head motion.
/// iOS only delivers updates while the app is foreground (or while audio is playing with the
/// right session category — we don't rely on that).
@MainActor
@Observable
final class HeadphoneMotionService {
    /// `isDeviceMotionAvailable` reflects whether *currently-connected* headphones report
    /// motion. It can flip false→true when supported AirPods come into range, so we read
    /// it live instead of caching at init.
    var isAvailable: Bool { manager.isDeviceMotionAvailable }
    private(set) var isConnected: Bool = false
    private(set) var isRunning: Bool = false
    private(set) var lastPitch: Double?
    private(set) var lastYaw: Double?
    private(set) var lastRoll: Double?

    var onSample: ((_ pitch: Double, _ yaw: Double, _ roll: Double) -> Void)?
    var onConnect: ((Bool) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private let delegateBox: HeadphoneDelegateBox
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()

    init() {
        // Per-instance delegate. Previously a `static let shared` box was overwritten
        // by every HMS init, racing with delegate callbacks delivered on a non-main
        // thread — when AirPods connected mid-onboarding the stale closure storage
        // could be read against a deallocated instance and crash under Swift 6
        // strict concurrency. Wire the closure first, then attach the delegate, so
        // the first connect callback can't land in the gap.
        let box = HeadphoneDelegateBox()
        self.delegateBox = box
        // self is now fully initialized — safe to capture in the escaping closure.
        box.onChange = { [weak self] connected in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = connected
                self.onConnect?(connected)
            }
        }
        manager.delegate = box
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive else { return }
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            let pitch = motion.attitude.pitch
            let yaw = motion.attitude.yaw
            let roll = motion.attitude.roll
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = true
                self.lastPitch = pitch
                self.lastYaw = yaw
                self.lastRoll = roll
                self.onSample?(pitch, yaw, roll)
            }
        }
        isRunning = true
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }
}

/// Delegate has to live outside the @MainActor service so it can conform to the
/// nonisolated `CMHeadphoneMotionManagerDelegate` protocol. Each HMS owns its
/// own box — no shared mutable state.
private final class HeadphoneDelegateBox: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    var onChange: ((Bool) -> Void)?

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        onChange?(true)
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        onChange?(false)
    }
}
#endif
