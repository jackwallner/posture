// Walk metrics are iOS-only: CMPedometer + CoreLocation aren't on the watch
// target (its walks run on HealthKit), and the widgets never track a live walk.
#if os(iOS)

import CoreLocation
import CoreMotion
import Foundation

/// Live walk metrics for a walking session: steps, distance, and a
/// motion-based "are you actually walking" signal.
///
/// - `CMPedometer` always supplies steps, an estimated distance, and cadence -
///   no permission beyond Motion & Fitness (already requested) and it works
///   with the phone pocketed.
/// - `CoreLocation` is layered on *only* when the user opts into GPS, for an
///   accurate distance and to survive backgrounding; it never blocks a walk.
///
/// The `isWalking` gate is the fix for "a walk can be fooled by sitting still":
/// when no new steps arrive for a grace window we report stationary, and the
/// session controller stops crediting walk time until real steps resume. When
/// the pedometer is unavailable (older device, Simulator) the gate is disabled
/// (`isWalking` stays true) so the feature degrades instead of trapping the user.
@MainActor
@Observable
final class WalkMetricsService: NSObject, CLLocationManagerDelegate {
    private(set) var steps = 0
    private(set) var pedometerDistanceMeters: Double = 0
    private(set) var gpsDistanceMeters: Double = 0
    private(set) var cadenceStepsPerSec: Double = 0
    /// Moving vs stationary (see the gate above). Starts true.
    private(set) var isWalking = true
    /// GPS is actively providing fixes (authorized + started).
    private(set) var usingGPS = false
    /// The user asked for GPS but denied/restricted location.
    private(set) var locationDenied = false

    /// The number the UI and the session should trust: GPS distance when we
    /// have it, otherwise the pedometer's estimate.
    var distanceMeters: Double {
        usingGPS && gpsDistanceMeters > 0 ? gpsDistanceMeters : pedometerDistanceMeters
    }

    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var lastLocation: CLLocation?

    @ObservationIgnored private var lastStepCount = 0
    @ObservationIgnored private var lastStepIncreaseAt = Date.now
    @ObservationIgnored private var running = false
    @ObservationIgnored private var wantsGPS = false

    /// No new steps for this long ⇒ stationary. A stoplight or a doorway
    /// pause shouldn't drop you out of the walk; genuinely stopping should.
    @ObservationIgnored private let stationaryGraceSeconds: TimeInterval = 12
    @ObservationIgnored private let pedometerAvailable = CMPedometer.isStepCountingAvailable()

    struct LocFix: Sendable {
        let lat: Double
        let lon: Double
        let accuracy: Double
    }

    // MARK: - Lifecycle

    func start(useGPS: Bool) {
        guard !running else { return }
        running = true
        wantsGPS = useGPS
        steps = 0
        pedometerDistanceMeters = 0
        gpsDistanceMeters = 0
        cadenceStepsPerSec = 0
        lastStepCount = 0
        lastStepIncreaseAt = .now
        isWalking = true
        usingGPS = false
        locationDenied = false
        lastLocation = nil

        if pedometerAvailable {
            // The handler MUST be `@Sendable`: CMPedometer delivers on a private
            // queue, and without this the closure inherits this method's
            // @MainActor isolation, so the runtime asserts (EXC_BREAKPOINT in
            // _swift_task_checkIsolatedSwift) the instant the first step lands.
            // That is the "starting a walk crashes" bug - it only fires on a
            // real device, since the Simulator has no pedometer. Same fix as
            // HeadphoneMotionService.beginMotionUpdates.
            pedometer.startUpdates(from: .now) { @Sendable [weak self] data, _ in
                guard let data else { return }
                let steps = data.numberOfSteps.intValue
                let distance = data.distance?.doubleValue
                let cadence = data.currentCadence?.doubleValue
                Task { @MainActor [weak self] in
                    self?.ingestPedometer(steps: steps, distance: distance, cadence: cadence)
                }
            }
        }
        if useGPS { startGPS() }
    }

    func stop() {
        guard running else { return }
        running = false
        if pedometerAvailable { pedometer.stopUpdates() }
        locationManager.stopUpdatingLocation()
        cadenceStepsPerSec = 0
    }

    /// Recompute the moving/stationary state. The controller calls this each
    /// scored sample so the walk clock pauses promptly when the user stops
    /// (the pedometer callback alone can lag several seconds).
    func tick(now: Date = .now) {
        guard pedometerAvailable else {
            if !isWalking { isWalking = true }
            return
        }
        let moving = now.timeIntervalSince(lastStepIncreaseAt) < stationaryGraceSeconds
        if moving != isWalking { isWalking = moving }
    }

    // MARK: - Pedometer

    private func ingestPedometer(steps: Int, distance: Double?, cadence: Double?) {
        if steps > lastStepCount {
            lastStepCount = steps
            lastStepIncreaseAt = .now
            if !isWalking { isWalking = true }
        }
        self.steps = steps
        if let distance { pedometerDistanceMeters = distance }
        if let cadence { cadenceStepsPerSec = cadence }
    }

    // MARK: - GPS

    private func startGPS() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 5
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginLocationUpdates()
        default:
            locationDenied = true
        }
    }

    private func beginLocationUpdates() {
        usingGPS = true
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }

    private func ingestFixes(_ fixes: [LocFix]) {
        guard running else { return }
        for f in fixes {
            guard f.accuracy >= 0, f.accuracy < 20 else { continue }
            let loc = CLLocation(latitude: f.lat, longitude: f.lon)
            if let last = lastLocation {
                let d = loc.distance(from: last)
                if d >= 1 { gpsDistanceMeters += d }
            }
            lastLocation = loc
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, self.running, self.wantsGPS else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.beginLocationUpdates()
            case .denied, .restricted: self.locationDenied = true
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Snapshot to Sendable values before crossing to the main actor -
        // CLLocation isn't Sendable under strict concurrency.
        let fixes = locations.map {
            LocFix(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, accuracy: $0.horizontalAccuracy)
        }
        Task { @MainActor [weak self] in
            self?.ingestFixes(fixes)
        }
    }
}
#endif
