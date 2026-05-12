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
        static let dailyReminderEnabled = "dailyReminderEnabled"
        static let dailyReminderHour = "dailyReminderHour"
        static let sensitivity = "sensitivity"  // 0=relaxed, 1=normal, 2=strict
        static let alwaysOnEnabled = "alwaysOnEnabled"
    }

    var alwaysOnEnabled: Bool {
        get { access(keyPath: \.alwaysOnEnabled); return defaults.bool(forKey: Key.alwaysOnEnabled) }
        set { withMutation(keyPath: \.alwaysOnEnabled) { defaults.set(newValue, forKey: Key.alwaysOnEnabled) } }
    }

    var hasCompletedOnboarding: Bool {
        get { access(keyPath: \.hasCompletedOnboarding); return defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { withMutation(keyPath: \.hasCompletedOnboarding) { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) } }
    }

    var hasCalibrated: Bool {
        get { access(keyPath: \.hasCalibrated); return defaults.bool(forKey: Key.hasCalibrated) }
        set { withMutation(keyPath: \.hasCalibrated) { defaults.set(newValue, forKey: Key.hasCalibrated) } }
    }

    var dailyReminderEnabled: Bool {
        get { access(keyPath: \.dailyReminderEnabled); return defaults.object(forKey: Key.dailyReminderEnabled) as? Bool ?? true }
        set { withMutation(keyPath: \.dailyReminderEnabled) { defaults.set(newValue, forKey: Key.dailyReminderEnabled) } }
    }

    var dailyReminderHour: Int {
        get { access(keyPath: \.dailyReminderHour); return defaults.object(forKey: Key.dailyReminderHour) as? Int ?? 9 }
        set { withMutation(keyPath: \.dailyReminderHour) { defaults.set(newValue, forKey: Key.dailyReminderHour) } }
    }

    var sensitivity: Int {
        get { access(keyPath: \.sensitivity); return defaults.object(forKey: Key.sensitivity) as? Int ?? 1 }
        set { withMutation(keyPath: \.sensitivity) { defaults.set(newValue, forKey: Key.sensitivity) } }
    }
}
