#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// Bridges the `alwaysOnEnabled` preference and Pro status between the
/// iPhone and the Apple Watch. App Group `UserDefaults` are per-device - they do *not*
/// sync across the phone/watch boundary - so without this the iOS toggle
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

    /// Called on the main actor when the iPhone relays a slouch nudge, with
    /// the time it was sent. The watch app sets this to tap the wrist.
    @MainActor var onSlouchNudge: ((Date) -> Void)?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// iOS → watch: the always-on toggle plus Pro status. The watch has no
    /// RevenueCat session of its own, so without the Pro flag a paying user
    /// stays locked out there. Safe to call any time; no-ops until the
    /// session is activated, and activation pushes the latest state.
    @MainActor func pushState() {
        #if os(iOS)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext([
            "alwaysOnEnabled": GoalSettings.shared.alwaysOnEnabled,
            "isPro": SubscriptionService.shared.isProSubscriber,
            // Keeps each push distinct, so it's delivered even when the
            // values match the last one (e.g. to a reinstalled watch app).
            "sentAt": Date().timeIntervalSince1970,
        ])
        #endif
    }

    #if os(iOS)
    /// The watch app is running now (foreground, or an always-on workout).
    /// A nudge is only worth sending then: a queued one would land late.
    @MainActor var isWatchReachable: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isReachable
    }

    /// iOS → watch: tap the wrist for a slouch. See `SlouchNudge.delivery`.
    @MainActor func sendSlouchNudge() {
        guard isWatchReachable else { return }
        WCSession.default.sendMessage(
            ["type": "slouch", "sentAt": Date().timeIntervalSince1970],
            replyHandler: nil,
            errorHandler: nil
        )
    }
    #endif

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        #if os(watchOS)
        guard message["type"] as? String == "slouch",
              let sentAt = message["sentAt"] as? TimeInterval else { return }
        let date = Date(timeIntervalSince1970: sentAt)
        Task { @MainActor in WatchSyncService.shared.onSlouchNudge?(date) }
        #endif
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // Replay whatever the counterpart last pushed while we were asleep.
        deliver(from: session.receivedApplicationContext)
        #if os(iOS)
        watchAppInstalled = session.isWatchAppInstalled
        Task { @MainActor in WatchSyncService.shared.pushStateIfStale() }
        #endif
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(from: applicationContext)
    }

    #if os(iOS)
    /// Delegate callbacks arrive serially on WatchConnectivity's queue.
    private var watchAppInstalled = false

    /// Fires on complication and pairing changes too; only a fresh install
    /// (no Pro status, no toggle of its own to override) gets a push.
    func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        defer { watchAppInstalled = installed }
        guard installed, !watchAppInstalled else { return }
        Task { @MainActor in WatchSyncService.shared.pushState() }
    }

    /// Activation-time catch-up: push only when the phone's state changed
    /// since the last send (e.g. a toggle flipped before activation), so a
    /// toggle changed on the watch is left alone otherwise.
    @MainActor private func pushStateIfStale() {
        let sent = WCSession.default.applicationContext
        guard sent["isPro"] as? Bool != SubscriptionService.shared.isProSubscriber
            || sent["alwaysOnEnabled"] as? Bool != GoalSettings.shared.alwaysOnEnabled else { return }
        pushState()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so a swapped watch keeps syncing.
        session.activate()
    }
    #endif

    private func deliver(from context: [String: Any]) {
        #if os(watchOS)
        guard let enabled = context["alwaysOnEnabled"] as? Bool else { return }
        let isPro = context["isPro"] as? Bool
        Task { @MainActor in
            if let isPro { SubscriptionService.shared.setLocalOverride(isPro: isPro) }
            GoalSettings.shared.alwaysOnEnabled = enabled
            WatchSyncService.shared.onAlwaysOnReceived?(enabled)
        }
        #endif
    }
}
#endif
