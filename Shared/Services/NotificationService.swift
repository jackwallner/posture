import Foundation
import UserNotifications

enum NotificationService {
    /// Daylight voice — lowercase, observational, never imperative.
    /// ≤24 chars so the banner doesn't truncate.
    private static let reminderTitles: [String] = [
        "a small check-in.",
        "how are you sitting?",
        "crown of the head, up.",
        "shoulders, soft.",
        "a posture pause.",
        "feet flat?",
        "how's the spine now?",
        "a breath. and a sit-up.",
        "jaw and tongue, soft.",
        "ears over shoulders.",
        "how upright?",
        "a moment for the body.",
    ]

    static let categoryIdentifier = "posture.reminder"

    /// Max pending reminder slots. iOS allows 64 pending requests; we
    /// schedule repeating daily triggers so the day's slots persist.
    private static let maxSlots = 60

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func registerCategories() {
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Schedule **repeating daily** posture reminders across the active
    /// window. Repeating triggers mean reminders keep firing on later
    /// days even if the app isn't reopened (audit P1-2), and the slot
    /// cap covers permanent daily slots rather than a single day's queue
    /// (audit P1-4).
    static func scheduleReminders(
        intervalMinutes: Int,
        activeHoursStart: Int,
        activeHoursEnd: Int
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: pendingReminderIdentifiers())
        center.removeDeliveredNotifications(withIdentifiers: deliveredReminderIdentifiers())

        guard intervalMinutes > 0, activeHoursEnd > activeHoursStart else { return }

        // Build (hour, minute) slots across the active window.
        var slots: [(hour: Int, minute: Int)] = []
        var minutes = activeHoursStart * 60
        let endMinutes = activeHoursEnd * 60
        while minutes < endMinutes && slots.count < maxSlots {
            slots.append((minutes / 60, minutes % 60))
            minutes += intervalMinutes
        }

        for (index, slot) in slots.enumerated() {
            let title = reminderTitles[index % reminderTitles.count]
            let content = UNMutableNotificationContent()
            content.title = title
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            var fire = DateComponents()
            fire.hour = slot.hour
            fire.minute = slot.minute

            let scheduledAt = Calendar.current.date(
                bySettingHour: slot.hour, minute: slot.minute, second: 0, of: Date()
            ) ?? Date()
            content.userInfo = [
                "type": "posture-reminder",
                "index": index,
                "scheduledAt": scheduledAt.timeIntervalSince1970,
            ]

            let trigger = UNCalendarNotificationTrigger(dateMatching: fire, repeats: true)
            let request = UNNotificationRequest(
                identifier: "posture.reminder.\(index)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
        AnalyticsService.remindersScheduled(count: slots.count)
    }

    static func cancelAllReminders() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: pendingReminderIdentifiers())
    }

    // MARK: - Helpers

    private static func pendingReminderIdentifiers() -> [String] {
        (0..<maxSlots).map { "posture.reminder.\($0)" }
    }

    private static func deliveredReminderIdentifiers() -> [String] {
        (0..<maxSlots).map { "posture.reminder.\($0)" }
    }
}
