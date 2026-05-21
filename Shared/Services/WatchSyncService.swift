#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Bridges the `alwaysOnEnabled` preference between the iPhone and the
/// Apple Watch. App Group `UserDefaults` are per-device — they do *not*
/// sync across the phone/watch boundary — so without this the iOS toggle
/// would never reach the watch.
///
/// iOS pushes the latest value with `updateApplicationContext` (last value
/// wins, survives the watch being asleep). The watch persists whatever it
/// receives into its own `GoalSettings` and notifies `onAlwaysOnReceived`
/// so the UI can start or stop the background workout the next time it runs.
final class WatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncService()

    /// Called on the main actor whenever a fresh value arrives from the
    /// counterpart device. The watch app sets this to react.
    @MainActor var onAlwaysOnReceived: ((Bool) -> Void)?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// iOS → watch. Safe to call any time; no-ops until the session is
    /// activated, and the latest value is replayed on activation anyway.
    func pushAlwaysOn(_ enabled: Bool) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext(["alwaysOnEnabled": enabled])
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Replay whatever the counterpart last pushed while we were asleep.
        deliver(from: session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(from: applicationContext)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a swapped watch keeps syncing.
        session.activate()
    }
    #endif

    private func deliver(from context: [String: Any]) {
        guard let enabled = context["alwaysOnEnabled"] as? Bool else { return }
        Task { @MainActor in
            GoalSettings.shared.alwaysOnEnabled = enabled
            WatchSyncService.shared.onAlwaysOnReceived?(enabled)
        }
    }
}
#endif
