import Foundation
import UserNotifications

enum NotificationService {
    /// Rotating pool of reminder bodies to keep notifications from feeling robotic.
    private static let reminderMessages: [String] = [
        "Time to check your posture. Quick scan or tap to acknowledge.",
        "Sit up straight — how's your alignment?",
        "Posture check! Take a moment to straighten up.",
        "Are you slouching? Check in with a quick scan.",
        "Heads up — check your posture.",
        "Straighten that spine. Quick check-in time.",
    ]

    static let categoryIdentifier = "posture.reminder"

    /// Request notification authorization (alert + sound).
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Register the notification category for posture reminders.
    /// Call this once at app launch (e.g., in App.init).
    static func registerCategories() {
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Schedule posture reminders from `now` through `activeHoursEnd`,
    /// spaced by `intervalMinutes`.
    static func scheduleReminders(
        intervalMinutes: Int,
        activeHoursStart: Int,
        activeHoursEnd: Int
    ) async {
        let center = UNUserNotificationCenter.current()
        // Cancel all existing posture reminders first
        center.removePendingNotificationRequests(
            withIdentifiers: pendingReminderIdentifiers()
        )
        center.removeDeliveredNotifications(
            withIdentifiers: deliveredReminderIdentifiers()
        )

        // Compute reminder times from now to activeHoursEnd
        let now = Date()
        let calendar = Calendar.current
        var times: [Date] = []

        guard let startToday = calendar.date(
            bySettingHour: activeHoursStart, minute: 0, second: 0, of: now
        ), let endToday = calendar.date(
            bySettingHour: activeHoursEnd, minute: 0, second: 0, of: now
        ) else { return }

        // Clamp start to now if we're past the start hour
        let effectiveStart = max(now, startToday)

        guard effectiveStart < endToday else { return }

        // Walk from effectiveStart to endToday in intervalMinutes steps
        var cursor = effectiveStart
        while cursor < endToday {
            times.append(cursor)
            guard let next = calendar.date(byAdding: .minute, value: intervalMinutes, to: cursor) else { break }
            cursor = next
        }

        // Don't schedule more than 20 reminders (prevents over-scheduling for very long windows)
        if times.count > 20 {
            times = Array(times.prefix(20))
        }

        for (index, fireDate) in times.enumerated() {
            let message = reminderMessages[index % reminderMessages.count]
            let content = UNMutableNotificationContent()
            content.title = "Posture check"
            content.body = message
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = [
                "type": "posture-reminder",
                "index": index,
                "scheduledAt": fireDate.timeIntervalSince1970,
            ]

            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "posture.reminder.\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Cancel all pending posture reminders.
    static func cancelAllReminders() async {
        let identifiers = pendingReminderIdentifiers()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    // MARK: - Helpers

    private static func pendingReminderIdentifiers() -> [String] {
        // We can't list pending requests synchronously, so we use a known prefix pattern.
        // This is best-effort — redundant IDs are harmless.
        // On foreground re-schedule we call removeAllPendingNotificationRequests anyway.
        (0..<20).map { "posture.reminder.\($0)" }
    }

    private static func deliveredReminderIdentifiers() -> [String] {
        // Same pattern for delivered notifications we want to clear.
        (0..<20).map { "posture.reminder.\($0)" }
    }
}
