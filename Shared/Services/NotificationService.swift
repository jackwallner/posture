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

    /// Optional supporting line — a small tip, paired with a title. Kept gentle
    /// and observational to match the Daylight voice.
    private static let reminderBodies: [String] = [
        "Lift the crown of your head a touch.",
        "Let your shoulders drop away from your ears.",
        "Stack your ears over your shoulders.",
        "Unclench the jaw, soften the tongue.",
        "A slow breath, and a small lift.",
        "Feet flat, weight even.",
        "Ease back from the screen an inch.",
        "Long spine, easy neck.",
    ]

    /// Daily-practice reminder copy — the one notification that matters.
    private static let practiceTitles: [String] = [
        "a few minutes of tall.",
        "today's practice is waiting.",
        "time to hold the shape.",
        "your posture practice.",
        "a short hold, done well.",
        "practice, then carry it.",
    ]

    private static let practiceBodies: [String] = [
        "AirPods in, spine long. The streak takes care of itself.",
        "A few minutes held tall today beats an hour of trying tomorrow.",
        "Sit or stand tall with live coaching. That's the whole habit.",
        "Crown up, shoulders soft, begin.",
    ]

    static let categoryIdentifier = "posture.reminder"
    static let practiceCategoryIdentifier = "posture.practice"
    static let practiceReminderIdentifier = "posture.practice.daily"

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
        let checkIn = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        let practice = UNNotificationCategory(
            identifier: practiceCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([checkIn, practice])
    }

    /// Schedule the single repeating daily-practice reminder. The copy
    /// rotates by day-of-year (rescheduled on every foreground).
    static func schedulePracticeReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [practiceReminderIdentifier])

        let dayOffset = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let content = UNMutableNotificationContent()
        content.title = practiceTitles[dayOffset % practiceTitles.count]
        content.body = practiceBodies[dayOffset % practiceBodies.count]
        content.sound = .default
        content.categoryIdentifier = practiceCategoryIdentifier
        content.userInfo = ["type": "practice-reminder"]

        var fire = DateComponents()
        fire.hour = hour
        fire.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: fire, repeats: true)
        let request = UNNotificationRequest(
            identifier: practiceReminderIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func cancelPracticeReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [practiceReminderIdentifier])
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

        // Offset the rotation by the day of the year so the same phrase doesn't
        // land at the same time every day (reschedule runs on foreground/day
        // change). Avoids the "mechanical, same 12 lines" feel.
        let dayOffset = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

        for (index, slot) in slots.enumerated() {
            let rotation = index + dayOffset
            let title = reminderTitles[rotation % reminderTitles.count]
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = reminderBodies[rotation % reminderBodies.count]
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
