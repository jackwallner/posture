import Foundation
#if !os(watchOS)
import UserNotifications
#endif

extension Notification.Name {
    /// Posted after `ReminderScheduler.reschedule()` finishes rewriting the
    /// pending notification queue. UI that displays reminder status (next
    /// time, remaining count) must re-read on this - reading while the
    /// queue is mid-rewrite sees a partial (often empty) list.
    static let postureRemindersRescheduled = Notification.Name("com.jackwallner.posture.remindersRescheduled")

    /// Posted by Settings to replay the in-session coach marks: Today opens
    /// a practice session with `hasSeenSessionCoachMarks` reset.
    static let postureReplaySessionCoachMarks = Notification.Name("com.jackwallner.posture.replaySessionCoachMarks")
    static let postureSelectProgressTab = Notification.Name("com.jackwallner.posture.selectProgressTab")
}

/// Orchestrates posture reminder scheduling. Handles setting changes,
/// app foreground events, and provides status for the UI.
enum ReminderScheduler {
    /// Reschedule reminders based on current settings. Call this whenever
    /// settings change or the app comes to foreground.
    @MainActor
    static func reschedule() async {
        #if DEBUG
        // Don't fire the iOS permission alert during UI tests - it lives
        // outside the app process and would stall the harness.
        if LaunchArguments.contains("UITEST_FRESH") { return }
        #endif
        let settings = GoalSettings.shared
        // Never fire the iOS notification prompt before setup is complete.
        // Onboarding flips first, then calibration (or the no-AirPods escape)
        // owns the screen; prompting there contradicts the motion-permission copy.
        guard settings.hasCompletedOnboarding, settings.hasCalibrated else { return }
        defer { NotificationCenter.default.post(name: .postureRemindersRescheduled, object: nil) }

        // The practice session needs AirPods - no-AirPods users live on the
        // check-in loop, so a practice reminder would dead-end for them.
        let practiceWanted = settings.practiceReminderEnabled && settings.hasAirpods == true
        if !practiceWanted {
            NotificationService.cancelPracticeReminder()
        }
        if !settings.reminderEnabled {
            await NotificationService.cancelAllReminders()
        }
        guard practiceWanted || settings.reminderEnabled else { return }

        let authorized = await NotificationService.requestAuthorization()
        guard authorized else {
            // Denied - keep the preference on so Settings can surface a
            // "notifications are off" banner (audit P1-3) instead of the
            // toggle silently flipping back. Just don't schedule.
            return
        }

        if practiceWanted {
            await NotificationService.schedulePracticeReminder(
                hour: settings.practiceReminderHour,
                minute: settings.practiceReminderMinute
            )
        }
        if settings.reminderEnabled {
            await NotificationService.scheduleReminders(
                intervalMinutes: settings.reminderIntervalMinutes,
                activeHoursStart: settings.activeHoursStart,
                activeHoursEnd: settings.activeHoursEnd
            )
        }
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

    /// Number of reminders still due before midnight today.
    static func remainingCount() async -> Int {
        #if os(watchOS)
        return 0
        #else
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let endOfDay = Calendar.current.startOfDay(for: Date())
            .addingTimeInterval(24 * 60 * 60)
        return pending
            .filter { $0.identifier.hasPrefix("posture.reminder.") }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .filter { $0 < endOfDay }
            .count
        #endif
    }

    /// Cancel all scheduled posture reminders.
    static func cancelAll() async {
        await NotificationService.cancelAllReminders()
    }
}
