#if os(iOS)

import AudioToolbox
import UserNotifications

/// Delivers a slouch nudge. The Taptic pop alone is easy to miss: it can't be
/// felt with the phone on a desk or in a bag, and iOS may drop it while the
/// app is in the background. So in the background a local notification
/// carries the nudge too, with sound, and iOS mirrors it to a paired Apple
/// Watch while the phone is locked.
enum SlouchNudge {
    static let identifier = "posture.slouch"

    static func fire(inBackground: Bool) {
        AudioServicesPlaySystemSound(1520)
        guard inBackground else { return }
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

#endif
