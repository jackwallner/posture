import Foundation
import Observation

@MainActor
@Observable
final class GoalSettings {
    static let shared = GoalSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: postureAppGroupID) ?? .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasCalibrated = "hasCalibrated"
        static let calibrationDeferred = "calibrationDeferred"
        static let hasSeenIntroPaywall = "hasSeenIntroPaywall"
        static let sensitivity = "sensitivity"
        static let alwaysOnEnabled = "alwaysOnEnabled"

        // Reminder cadence
        static let reminderEnabled = "reminderEnabled"
        static let reminderIntervalMinutes = "reminderIntervalMinutes"
        static let activeHoursStart = "activeHoursStart"
        static let activeHoursEnd = "activeHoursEnd"

        // Pro features
        static let airpodsBackgroundEnabled = "airpodsBackgroundEnabled"

        // AirPods ownership (asked once at onboarding, nil if never asked)
        static let hasAirpods = "hasAirpods"

        // Deprecated (kept for migration)
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderHour = "dailyReminderHour"
    }

    // MARK: - Core

    var hasCompletedOnboarding: Bool {
        get { access(keyPath: \.hasCompletedOnboarding); return defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { withMutation(keyPath: \.hasCompletedOnboarding) { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) } }
    }

    var hasCalibrated: Bool {
        get { access(keyPath: \.hasCalibrated); return defaults.bool(forKey: Key.hasCalibrated) }
        set { withMutation(keyPath: \.hasCalibrated) { defaults.set(newValue, forKey: Key.hasCalibrated) } }
    }

    /// True when the user entered the app via "Continue without AirPods" and is
    /// running on a neutral baseline. Today shows a persistent "finish setup"
    /// banner until a real calibration capture clears it.
    var calibrationDeferred: Bool {
        get { access(keyPath: \.calibrationDeferred); return defaults.bool(forKey: Key.calibrationDeferred) }
        set { withMutation(keyPath: \.calibrationDeferred) { defaults.set(newValue, forKey: Key.calibrationDeferred) } }
    }

    /// One-shot: the intro paywall is shown once on the first entry to the main
    /// app for non-subscribers, so every new user sees the trial offer at least once.
    var hasSeenIntroPaywall: Bool {
        get { access(keyPath: \.hasSeenIntroPaywall); return defaults.bool(forKey: Key.hasSeenIntroPaywall) }
        set { withMutation(keyPath: \.hasSeenIntroPaywall) { defaults.set(newValue, forKey: Key.hasSeenIntroPaywall) } }
    }

    var sensitivity: Int {
        get { access(keyPath: \.sensitivity); return defaults.object(forKey: Key.sensitivity) as? Int ?? 1 }
        set { withMutation(keyPath: \.sensitivity) { defaults.set(newValue, forKey: Key.sensitivity) } }
    }

    var alwaysOnEnabled: Bool {
        get { access(keyPath: \.alwaysOnEnabled); return defaults.bool(forKey: Key.alwaysOnEnabled) }
        set { withMutation(keyPath: \.alwaysOnEnabled) { defaults.set(newValue, forKey: Key.alwaysOnEnabled) } }
    }

    // MARK: - Reminder Cadence

    /// Master toggle for periodic posture reminders.
    var reminderEnabled: Bool {
        get { access(keyPath: \.reminderEnabled); return defaults.object(forKey: Key.reminderEnabled) as? Bool ?? true }
        set { withMutation(keyPath: \.reminderEnabled) { defaults.set(newValue, forKey: Key.reminderEnabled) } }
    }

    /// Minutes between posture reminders. One of: 15, 30, 60.
    var reminderIntervalMinutes: Int {
        get { access(keyPath: \.reminderIntervalMinutes); return defaults.object(forKey: Key.reminderIntervalMinutes) as? Int ?? 30 }
        set { withMutation(keyPath: \.reminderIntervalMinutes) { defaults.set(newValue, forKey: Key.reminderIntervalMinutes) } }
    }

    /// Hour (0-23) when daily reminders start firing.
    var activeHoursStart: Int {
        get { access(keyPath: \.activeHoursStart); return defaults.object(forKey: Key.activeHoursStart) as? Int ?? 9 }
        set { withMutation(keyPath: \.activeHoursStart) { defaults.set(newValue, forKey: Key.activeHoursStart) } }
    }

    /// Hour (0-23) when daily reminders stop firing.
    var activeHoursEnd: Int {
        get { access(keyPath: \.activeHoursEnd); return defaults.object(forKey: Key.activeHoursEnd) as? Int ?? 20 }
        set { withMutation(keyPath: \.activeHoursEnd) { defaults.set(newValue, forKey: Key.activeHoursEnd) } }
    }

    // MARK: - Pro Features

    /// Background AirPods monitoring (Pro). Tracks head motion passively with haptic/chime feedback.
    var airpodsBackgroundEnabled: Bool {
        get { access(keyPath: \.airpodsBackgroundEnabled); return defaults.bool(forKey: Key.airpodsBackgroundEnabled) }
        set { withMutation(keyPath: \.airpodsBackgroundEnabled) { defaults.set(newValue, forKey: Key.airpodsBackgroundEnabled) } }
    }

    /// Tri-state: nil = never asked (legacy install or upgrade path), true/false
    /// = answer from onboarding. Read by CalibrationView and the foreground
    /// monitor decision in App.swift.
    var hasAirpods: Bool? {
        get {
            access(keyPath: \.hasAirpods)
            guard defaults.object(forKey: Key.hasAirpods) != nil else { return nil }
            return defaults.bool(forKey: Key.hasAirpods)
        }
        set {
            withMutation(keyPath: \.hasAirpods) {
                if let value = newValue { defaults.set(value, forKey: Key.hasAirpods) }
                else { defaults.removeObject(forKey: Key.hasAirpods) }
            }
        }
    }

    // MARK: - Migration from old reminder keys

    /// Migrate settings from the old daily-reminder model to the new cadence model.
    /// Call once on first launch after update.
    func migrateFromDeprecatedKeys() {
        guard defaults.object(forKey: Key.reminderEnabled) == nil else { return }
        let oldEnabled = defaults.object(forKey: Key.dailyReminderEnabled) as? Bool ?? true
        reminderEnabled = oldEnabled
        if let oldHour = defaults.object(forKey: Key.dailyReminderHour) as? Int {
            activeHoursStart = oldHour
        }
        defaults.removeObject(forKey: Key.dailyReminderEnabled)
        defaults.removeObject(forKey: Key.dailyReminderHour)
    }

    #if DEBUG
    /// Wipe onboarding/calibration state so a UI test starts at the
    /// welcome screen regardless of prior installs. Test-only.
    func resetForUITest() {
        for key in [Key.hasCompletedOnboarding, Key.hasCalibrated, Key.calibrationDeferred, Key.hasSeenIntroPaywall, Key.hasAirpods] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
