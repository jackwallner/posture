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
    private(set) var isAvailable: Bool
    private(set) var isConnected: Bool = false
    private(set) var isRunning: Bool = false
    private(set) var lastPitch: Double?
    private(set) var lastYaw: Double?
    private(set) var lastRoll: Double?

    var onSample: ((_ pitch: Double, _ yaw: Double, _ roll: Double) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()

    init() {
        self.isAvailable = manager.isDeviceMotionAvailable
        manager.delegate = HeadphoneDelegateBox.shared
        HeadphoneDelegateBox.shared.onChange = { [weak self] connected in
            Task { @MainActor [weak self] in self?.isConnected = connected }
        }
    }

    func start() {
        guard isAvailable, manager.isDeviceMotionAvailable else { return }
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

/// Delegate has to live somewhere outside the actor to satisfy the protocol's nonisolated requirement.
private final class HeadphoneDelegateBox: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    static let shared = HeadphoneDelegateBox()
    var onChange: ((Bool) -> Void)?

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        onChange?(true)
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        onChange?(false)
    }
}
#endif
