import Foundation
import UserNotifications

enum NotificationService {
    /// Daylight voice - lowercase, observational, never imperative.
    /// ≤24 chars so the banner doesn't truncate.
    private static let reminderTitles: [String] = [
        String(localized: "a small check-in."),
        String(localized: "how are you sitting?"),
        String(localized: "crown of the head, up."),
        String(localized: "shoulders, soft."),
        String(localized: "a posture pause."),
        String(localized: "feet flat?"),
        String(localized: "how's the spine now?"),
        String(localized: "a breath. and a sit-up."),
        String(localized: "jaw and tongue, soft."),
        String(localized: "ears over shoulders."),
        String(localized: "how upright?"),
        String(localized: "a moment for the body."),
    ]

    /// Optional supporting line - a small tip, paired with a title. Kept gentle
    /// and observational to match the Daylight voice.
    private static let reminderBodies: [String] = [
        String(localized: "Lift the crown of your head a touch."),
        String(localized: "Let your shoulders drop away from your ears."),
        String(localized: "Stack your ears over your shoulders."),
        String(localized: "Unclench the jaw, soften the tongue."),
        String(localized: "A slow breath, and a small lift."),
        String(localized: "Feet flat, weight even."),
        String(localized: "Ease back from the screen an inch."),
        String(localized: "Long spine, easy neck."),
    ]

    /// Daily-practice reminder copy - the one notification that matters.
    private static let practiceTitles: [String] = [
        String(localized: "a few minutes of tall."),
        String(localized: "today's practice is waiting."),
        String(localized: "time to hold the shape."),
        String(localized: "your posture practice."),
        String(localized: "a short hold, done well."),
        String(localized: "practice, then carry it."),
    ]

    private static let practiceBodies: [String] = [
        String(localized: "AirPods in, spine long. The streak takes care of itself."),
        String(localized: "A few minutes held tall today beats an hour of trying tomorrow."),
        String(localized: "Sit or stand tall with live coaching. That's the whole habit."),
        String(localized: "Crown up, shoulders soft, begin."),
    ]

    static let categoryIdentifier = "posture.reminder"
    static let practiceCategoryIdentifier = "posture.practice"
    /// The single daily trigger used before the practice reminder was split
    /// by weekday. Still removed so an upgrade never leaves it behind.
    static let practiceReminderIdentifier = "posture.practice.daily"

    /// Max pending check-in slots. iOS allows 64 pending requests, and the
    /// practice reminder holds 7 (one per weekday); we schedule repeating
    /// daily triggers so the day's slots persist.
    private static let maxSlots = 57
    /// Check-in ids ever scheduled (the cap was 60), all cleared on reschedule.
    private static let slotIdentifierCeiling = 60

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

    struct PracticeTrigger: Equatable {
        let identifier: String
        let dateComponents: DateComponents
        let repeats: Bool
    }

    /// One repeating trigger per weekday, so a day whose practice is already
    /// done can be skipped while the rest keep firing even if the app is not
    /// reopened (audit P1-2). The skipped weekday gets a one-shot a week out;
    /// the next reschedule turns it back into a repeating one.
    static func practiceTriggers(
        hour: Int,
        minute: Int,
        practiceDoneToday: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PracticeTrigger] {
        let todayWeekday = calendar.component(.weekday, from: now)
        return (1...7).map { weekday in
            let identifier = "\(practiceReminderIdentifier).\(weekday)"
            if practiceDoneToday, weekday == todayWeekday,
               let nextWeek = calendar.date(byAdding: .day, value: 7, to: now) {
                var fire = calendar.dateComponents([.year, .month, .day], from: nextWeek)
                fire.hour = hour
                fire.minute = minute
                return PracticeTrigger(identifier: identifier, dateComponents: fire, repeats: false)
            }
            var fire = DateComponents()
            fire.weekday = weekday
            fire.hour = hour
            fire.minute = minute
            return PracticeTrigger(identifier: identifier, dateComponents: fire, repeats: true)
        }
    }

    /// Schedule the daily-practice reminder, skipping today when today's
    /// practice is done. The copy rotates by day-of-year (rescheduled on
    /// every foreground and after every practice).
    static func schedulePracticeReminder(hour: Int, minute: Int, practiceDoneToday: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: practiceReminderIdentifiers())

        let dayOffset = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let triggers = practiceTriggers(hour: hour, minute: minute, practiceDoneToday: practiceDoneToday)
        for (index, item) in triggers.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = practiceTitles[(dayOffset + index) % practiceTitles.count]
            content.body = practiceBodies[(dayOffset + index) % practiceBodies.count]
            content.sound = .default
            content.categoryIdentifier = practiceCategoryIdentifier
            content.userInfo = ["type": "practice-reminder"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.dateComponents, repeats: item.repeats)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelPracticeReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: practiceReminderIdentifiers())
    }

    private static func practiceReminderIdentifiers() -> [String] {
        [practiceReminderIdentifier] + (1...7).map { "\(practiceReminderIdentifier).\($0)" }
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
        (0..<slotIdentifierCeiling).map { "posture.reminder.\($0)" }
    }

    private static func deliveredReminderIdentifiers() -> [String] {
        (0..<slotIdentifierCeiling).map { "posture.reminder.\($0)" }
    }
}
