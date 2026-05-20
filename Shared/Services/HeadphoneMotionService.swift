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

    /// Set by `start()` even if motion can't begin yet (no AirPods connected).
    /// When the delegate later reports connect we activate updates then. Without
    /// this, the user puts in AirPods after we called `start()` and motion
    /// never flows — UI looks "linked" but no samples ever arrive.
    private var wantsToRun = false

    init() {
        // Per-instance delegate with a `weak` back-pointer to the owner.
        // Previously the box stored a closure assigned post-init; that closure
        // read happened cross-thread (CoreMotion delivers delegate calls on a
        // private queue) against a `var` property, which Swift 6 strict
        // concurrency would not vouch for despite `@unchecked Sendable`. A
        // `weak` reference uses atomic load and is safe to read from any
        // thread.
        let box = HeadphoneDelegateBox()
        self.delegateBox = box
        box.owner = self
        manager.delegate = box
    }

    /// Called by the delegate (off-main) via a MainActor hop.
    fileprivate func handleConnectChange(_ connected: Bool) {
        isConnected = connected
        // If start() was called before AirPods were connected, the motion
        // updates never began. Now that they're here, kick them off.
        if connected, wantsToRun, !manager.isDeviceMotionActive {
            beginMotionUpdates()
        }
        onConnect?(connected)
    }

    func start() {
        wantsToRun = true
        // If AirPods are already in when we attach (e.g. cold launch with the
        // user already wearing them), the delegate's didConnect doesn't fire.
        // Reflect the truth synchronously so the UI doesn't sit on "waiting."
        if manager.isDeviceMotionAvailable, !isConnected {
            isConnected = true
        }
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive else { return }
        beginMotionUpdates()
    }

    private func beginMotionUpdates() {
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
        wantsToRun = false
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }
}

/// Delegate has to live outside the @MainActor service so it can conform to the
/// nonisolated `CMHeadphoneMotionManagerDelegate` protocol. Each HMS owns its
/// own box and the box weakly points back — no shared mutable closure storage,
/// no cross-thread races.
private final class HeadphoneDelegateBox: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    weak var owner: HeadphoneMotionService?

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak owner] in
            owner?.handleConnectChange(true)
        }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Task { @MainActor [weak owner] in
            owner?.handleConnectChange(false)
        }
    }
}
#endif
