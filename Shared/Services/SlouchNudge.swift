#if os(iOS)

import AudioToolbox
import LocalAuthentication
import UIKit
import UserNotifications

/// Delivers a slouch nudge. The Taptic pop alone is easy to miss: it can't be
/// felt with the phone on a desk or in a bag, and iOS may drop it while the
/// app is in the background. So in the background a local notification
/// carries the nudge too, with sound, and iOS mirrors it to a paired Apple
/// Watch while the phone is locked. When the phone is unlocked (or the app is
/// open) iOS keeps the notification on the phone, so the nudge goes straight
/// to the Watch app over WatchConnectivity instead.
enum SlouchNudge {
    static let identifier = "posture.slouch"

    struct Delivery: Equatable {
        var notification: Bool
        var watchMessage: Bool
    }

    /// The watch message fills only the gap the notification mirror leaves,
    /// so the wrist never buzzes twice for one nudge.
    static func delivery(inBackground: Bool, phoneLocked: Bool, watchReachable: Bool) -> Delivery {
        let mirroredToWatch = inBackground && phoneLocked
        return Delivery(
            notification: inBackground,
            watchMessage: watchReachable && !mirroredToWatch
        )
    }

    @MainActor
    static func fire(inBackground: Bool) {
        AudioServicesPlaySystemSound(1520)
        let delivery = delivery(
            inBackground: inBackground,
            phoneLocked: PhoneLockState.shared.isLocked(inBackground: inBackground),
            watchReachable: WatchSyncService.shared.isWatchReachable
        )
        if delivery.watchMessage { WatchSyncService.shared.sendSlouchNudge() }
        guard delivery.notification else { return }
        let content = UNMutableNotificationContent()
        content.title = "slouch check."
        content.body = "Lift the crown of your head a touch."
        content.sound = .default
        content.userInfo = ["type": "slouch"]
        // One identifier: each nudge replaces the last, so Notification
        // Center never stacks up a pile of them.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Posture recovered or tracking ended: clear the banner so it doesn't
    /// linger, including one still pending delivery.
    static func clear() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

/// Whether the iPhone is locked, which decides if iOS mirrors a notification
/// to the Watch. Read from protected-data availability: with a passcode set,
/// it drops when the phone locks. `UIApplication.shared` is unavailable in
/// the extensions that also compile Shared/, so the app seeds the start value.
@MainActor
final class PhoneLockState {
    static let shared = PhoneLockState()

    private var protectedDataGone = false
    private var observers: [NSObjectProtocol] = []

    private init() {}

    /// Without a passcode, protected data never drops, so a backgrounded
    /// phone counts as locked: the mirror alone then reaches the wrist,
    /// never the mirror plus a relay.
    func isLocked(inBackground: Bool) -> Bool {
        if protectedDataGone { return true }
        return inBackground && !Self.hasPasscode()
    }

    private static func hasPasscode() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func start(locked: Bool) {
        guard observers.isEmpty else { return }
        protectedDataGone = locked
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: nil
            ) { @Sendable _ in
                Task { @MainActor in PhoneLockState.shared.protectedDataGone = true }
            },
            center.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: nil
            ) { @Sendable _ in
                Task { @MainActor in PhoneLockState.shared.protectedDataGone = false }
            },
        ]
    }
}

#endif
