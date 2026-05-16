import Foundation
#if !os(watchOS)
import UserNotifications
#endif

/// Orchestrates posture reminder scheduling. Handles setting changes,
/// app foreground events, and provides status for the UI.
enum ReminderScheduler {
    /// Reschedule reminders based on current settings. Call this whenever
    /// settings change or the app comes to foreground.
    @MainActor
    static func reschedule() async {
        let settings = GoalSettings.shared
        guard settings.reminderEnabled else {
            await NotificationService.cancelAllReminders()
            return
        }

        let authorized = await NotificationService.requestAuthorization()
        guard authorized else {
            // User denied notifications — disable reminders silently
            settings.reminderEnabled = false
            return
        }

        await NotificationService.scheduleReminders(
            intervalMinutes: settings.reminderIntervalMinutes,
            activeHoursStart: settings.activeHoursStart,
            activeHoursEnd: settings.activeHoursEnd
        )
    }

    /// The date of the next scheduled posture reminder, or nil if none.
    static func nextReminderDate() async -> Date? {
        #if os(watchOS)
        return nil
        #else
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let reminders = pending
            .filter { $0.identifier.hasPrefix("posture.reminder.") }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
        return reminders.min()
        #endif
    }

    /// Number of reminders scheduled for the remainder of today.
    static func remainingCount() async -> Int {
        #if os(watchOS)
        return 0
        #else
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.filter { $0.identifier.hasPrefix("posture.reminder.") }.count
        #endif
    }

    /// Cancel all scheduled posture reminders.
    static func cancelAll() async {
        await NotificationService.cancelAllReminders()
    }
}
