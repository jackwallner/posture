#if os(watchOS)
import CoreMotion
import Foundation
import HealthKit
import Observation
import SwiftData
import WatchKit

/// Premium "always-on" monitoring. Starts an HKWorkoutSession of type .other so CoreMotion
/// keeps streaming in the background and we can fire haptics + log slouch events all day.
@MainActor
@Observable
final class BackgroundPostureWorkout: NSObject {
    /// Process-scoped so the phone-synced auto-starter and the on-watch
    /// settings toggle drive the *same* workout instead of racing two
    /// HKWorkoutSessions.
    static let shared = BackgroundPostureWorkout()

    private(set) var isActive: Bool = false
    private(set) var lastSlouchAt: Date?
    private(set) var totalSlouchEvents: Int = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private var calibrationBaseline: (x: Double, y: Double, z: Double)?
    private var slouchDelta: Double = .pi / 6  // 30° default
    private var smoothedDeviation: Double?
    private var sustainedBadStart: Date?

    private let badThresholdSeconds: TimeInterval = 8
    private let nudgeCooldownSeconds: TimeInterval = 60

    var onSlouchEvent: ((Double) -> Void)?

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [])
            return true
        } catch {
            return false
        }
    }

    func start(calibration: Calibration) async {
        guard !isActive else { return }
        if let x = calibration.watchGravityX, let y = calibration.watchGravityY, let z = calibration.watchGravityZ {
            calibrationBaseline = (x, y, z)
        }
        slouchDelta = calibration.slouchPitchDelta

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            let startDate = Date()
            session?.startActivity(with: startDate)
            try await builder?.beginCollection(at: startDate)

            startMotionUpdates()
            isActive = true
        } catch {
            stop()
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        sustainedBadStart = nil
        smoothedDeviation = nil
        session?.end()
        Task {
            try? await builder?.endCollection(at: Date())
            try? await builder?.finishWorkout()
        }
        session = nil
        builder = nil
        isActive = false
    }

    private func startMotionUpdates() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.5
        motion.startDeviceMotionUpdates(to: queue) { @Sendable [weak self] motion, _ in
            guard let motion else { return }
            let g = motion.gravity
            Task { @MainActor in
                self?.handle(gravity: (g.x, g.y, g.z))
            }
        }
    }

    private func handle(gravity g: (x: Double, y: Double, z: Double)) {
        if calibrationBaseline == nil { calibrationBaseline = g }
        guard let baseline = calibrationBaseline else { return }
        let dev = WatchMotionService.angleBetween(baseline, g)
        let smoothed = PostureScoring.smoothed(previous: smoothedDeviation, sample: dev)
        smoothedDeviation = smoothed
        let quality = PostureScoring.quality(deviation: smoothed, slouchDelta: slouchDelta, sensitivity: GoalSettings.shared.sensitivity)

        if quality == .bad {
            if sustainedBadStart == nil {
                sustainedBadStart = Date()
            } else if let start = sustainedBadStart, Date().timeIntervalSince(start) >= badThresholdSeconds {
                fireSlouchEvent(severity: smoothed)
                sustainedBadStart = nil
            }
        } else {
            sustainedBadStart = nil
        }
    }

    private func fireSlouchEvent(severity: Double) {
        let now = Date()
        if let last = lastSlouchAt, now.timeIntervalSince(last) < nudgeCooldownSeconds { return }
        lastSlouchAt = now
        totalSlouchEvents += 1
        WKInterfaceDevice.current().play(.notification)
        Task { @MainActor in
            let context = ModelContext(DataService.sharedModelContainer)
            context.insert(PosturePassiveSample(timestamp: now, severity: severity, source: .watch))
            try? context.save()
        }
        onSlouchEvent?(severity)
    }
}
#endif
