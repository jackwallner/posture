import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int) async {
        let center = UNUserNotificationCenter.current()
        await cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Posture check-in"
        content.body = "Stand tall — your daily posture session is waiting."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "posture.daily-reminder", content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelDailyReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["posture.daily-reminder"]
        )
    }
}
