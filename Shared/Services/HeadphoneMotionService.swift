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
    /// `isDeviceMotionAvailable` is *device* capability — "does this iPhone support
    /// headphone motion at all". It is true on any real iOS 14+ device even with no
    /// headphones anywhere in sight (and false on the simulator). It says nothing
    /// about whether AirPods are currently connected; connection truth comes from
    /// the delegate callbacks and from samples actually arriving.
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// True when the user has denied (or is restricted from) motion access, so a
    /// calibration/scan failure is a permission problem, not missing hardware.
    /// Lets the UI show a distinct "Motion access is off → Settings" state instead
    /// of the misleading "compatible AirPods required" gate.
    static var isMotionAccessDenied: Bool {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted: return true
        default: return false
        }
    }

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
        // Do NOT infer connection from `isDeviceMotionAvailable` — that's device
        // capability and is always true on a real iPhone, AirPods or not. Forcing
        // `isConnected = true` here made the calibration/scan views start a capture
        // against headphones that weren't there, and because the flag never changed
        // again their `.onChange(of: isConnected)` transitions went permanently
        // dead. If AirPods are already worn, the first motion sample (and usually
        // a didConnect callback) lands within ~a second of beginMotionUpdates()
        // and flips `isConnected` through the normal path.
        guard manager.isDeviceMotionAvailable else { return }
        guard !manager.isDeviceMotionActive else { return }
        beginMotionUpdates()
    }

    private func beginMotionUpdates() {
        // The handler MUST be `@Sendable` so it doesn't inherit this method's
        // @MainActor isolation. CoreMotion's bridged signature isn't @Sendable,
        // so without this annotation the closure carries MainActor isolation,
        // and the runtime asserts on the main queue when CoreMotion invokes it
        // from our OperationQueue thread (EXC_BREAKPOINT in
        // _swift_task_checkIsolatedSwift). Repro: TF feedback #10 (build 18).
        manager.startDeviceMotionUpdates(to: queue) { @Sendable [weak self] motion, _ in
            guard let motion else { return }
            let pitch = motion.attitude.pitch
            let yaw = motion.attitude.yaw
            let roll = motion.attitude.roll
            Task { @MainActor in
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
