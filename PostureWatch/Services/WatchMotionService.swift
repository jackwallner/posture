import CoreMotion
import Foundation
import Observation
#if os(watchOS)
import WatchKit
#endif

/// Reads wrist motion via `CMMotionManager` device motion. Computes the angle between the
/// current gravity vector and the calibrated baseline; large deltas mean the wrist (and by
/// proxy the upper body) has rotated forward - the slumped-shoulder telltale.
@MainActor
@Observable
final class WatchMotionService {
    private(set) var isRunning: Bool = false
    private(set) var lastDeviationRadians: Double = 0

    var onDeviation: ((Double) -> Void)?

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private var baseline: (x: Double, y: Double, z: Double)?

    init() {
        manager.deviceMotionUpdateInterval = 0.2
    }

    /// Calibrate using the current wrist orientation as "good posture."
    func captureBaseline() {
        guard let motion = manager.deviceMotion else { return }
        baseline = (motion.gravity.x, motion.gravity.y, motion.gravity.z)
    }

    func setBaseline(x: Double, y: Double, z: Double) {
        baseline = (x, y, z)
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.startDeviceMotionUpdates(to: queue) { @Sendable [weak self] motion, _ in
            guard let motion else { return }
            let g = motion.gravity
            Task { @MainActor in
                guard let self else { return }
                if self.baseline == nil {
                    self.baseline = (g.x, g.y, g.z)
                }
                let deviation = Self.angleBetween(self.baseline!, (g.x, g.y, g.z))
                self.lastDeviationRadians = deviation
                self.onDeviation?(deviation)
            }
        }
        isRunning = true
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    /// Angle (radians) between two unit-ish vectors using the dot product.
    nonisolated static func angleBetween(_ a: (x: Double, y: Double, z: Double), _ b: (x: Double, y: Double, z: Double)) -> Double {
        let dot = a.x * b.x + a.y * b.y + a.z * b.z
        let magA = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        let magB = sqrt(b.x * b.x + b.y * b.y + b.z * b.z)
        guard magA > 0, magB > 0 else { return 0 }
        let cos = max(-1, min(1, dot / (magA * magB)))
        return acos(cos)
    }

    #if os(watchOS)
    func playSlouchHaptic() {
        WKInterfaceDevice.current().play(.notification)
    }
    #endif
}
