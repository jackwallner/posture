#if canImport(WatchConnectivity)
import Foundation
import SwiftData
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

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

    /// Called on the main actor when the iPhone sends a fresh streak and
    /// today's score. The watch app sets this to redraw.
    @MainActor var onTodayReceived: ((TodaySnapshot) -> Void)?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// iOS → watch: the always-on toggle, Pro status, and the streak with
    /// today's score. The watch has no RevenueCat session of its own, so
    /// without the Pro flag a paying user stays locked out there, and no
    /// store the phone writes, so without the snapshot it shows 0. Safe to
    /// call any time; no-ops until the session is activated, and activation
    /// pushes the latest state.
    @MainActor func pushState() {
        #if os(iOS)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext(Self.applicationContext(
            alwaysOnEnabled: GoalSettings.shared.alwaysOnEnabled,
            isPro: SubscriptionService.shared.isProSubscriber,
            today: currentTodaySnapshot()
        ))
        #endif
    }

    /// The application context the phone sends.
    static func applicationContext(
        alwaysOnEnabled: Bool,
        isPro: Bool,
        today: TodaySnapshot?,
        sentAt: Date = Date()
    ) -> [String: Any] {
        var context: [String: Any] = [
            "alwaysOnEnabled": alwaysOnEnabled,
            "isPro": isPro,
            // Keeps each push distinct, so it's delivered even when the
            // values match the last one (e.g. to a reinstalled watch app).
            "sentAt": sentAt.timeIntervalSince1970,
        ]
        if let data = today?.encoded { context[TodaySnapshot.storageKey] = data }
        return context
    }

    #if os(iOS)
    @MainActor private func currentTodaySnapshot() -> TodaySnapshot? {
        guard case .success(let container) = DataService.containerResult else { return nil }
        return TodaySnapshot.make(from: container.mainContext)
    }

    /// A practice, walk or check-in changed the streak or today's score:
    /// refresh the watch.
    @MainActor func todayDidChange() {
        pushState()
    }
    #endif

    #if os(watchOS)
    /// Keeps a background launch alive until WatchConnectivity has handed
    /// over what the phone sent (about 10 seconds at most).
    func waitForPendingContent() async {
        guard WCSession.isSupported() else { return }
        activate()
        let session = WCSession.default
        for _ in 0..<50 where session.activationState != .activated || session.hasContentPending {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }
    #endif

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
            || sent["alwaysOnEnabled"] as? Bool != GoalSettings.shared.alwaysOnEnabled
            || TodaySnapshot.decode(sent[TodaySnapshot.storageKey]) != currentTodaySnapshot() else { return }
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
        if let today = TodaySnapshot.decode(context[TodaySnapshot.storageKey]) {
            today.store()
            WidgetCenter.shared.reloadAllTimelines()
            Task { @MainActor in WatchSyncService.shared.onTodayReceived?(today) }
        }
        guard let enabled = context["alwaysOnEnabled"] as? Bool else { return }
        let isPro = context["isPro"] as? Bool
        // The phone now pushes after every practice and check-in, so apply
        // its always-on value only when it changed there. Otherwise a
        // toggle flipped on the watch would be undone by the next practice.
        let defaults = UserDefaults(suiteName: postureAppGroupID)
        let phoneChanged = defaults?.object(forKey: Self.lastPhoneAlwaysOnKey) as? Bool != enabled
        defaults?.set(enabled, forKey: Self.lastPhoneAlwaysOnKey)
        Task { @MainActor in
            if let isPro { SubscriptionService.shared.setLocalOverride(isPro: isPro) }
            if phoneChanged { GoalSettings.shared.alwaysOnEnabled = enabled }
            WatchSyncService.shared.onAlwaysOnReceived?(GoalSettings.shared.alwaysOnEnabled)
        }
        #endif
    }

    #if os(watchOS)
    private static let lastPhoneAlwaysOnKey = "lastPhoneAlwaysOnEnabled"
    #endif
}
#endif
