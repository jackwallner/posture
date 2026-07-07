import Foundation
import Observation

/// What the user told onboarding they most want to fix.
enum PostureFocus: String, CaseIterable, Sendable {
    case sitting
    case standing
    case both

    /// Modes the user can train. A `.both` user gets both ladders; a
    /// single-focus user only their one, so no picker is shown.
    var trainableModes: [PostureMode] {
        switch self {
        case .standing: return [.standing]
        case .sitting: return [.sitting]
        case .both: return [.standing, .sitting]
        }
    }

    var trainsBoth: Bool { self == .both }

    /// Fallback mode when a picker isn't presented (single-focus users,
    /// notification-tap sessions). A `.both` user defaults to standing.
    var defaultMode: PostureMode {
        self == .sitting ? .sitting : .standing
    }
}

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
        static let hasSeenOnboardingTrial = "hasSeenOnboardingTrial"
        static let hasSeenTrainingTour = "hasSeenTrainingTour"
        static let hasSeenSessionCoachMarks = "hasSeenSessionCoachMarks"
        static let hasSeenPivotExplainer = "hasSeenPivotExplainer"
        static let didApplyPracticePivotGrace = "didApplyPracticePivotGrace"
        static let sensitivity = "sensitivity"
        static let alwaysOnEnabled = "alwaysOnEnabled"

        // Daily practice reminder
        static let practiceReminderEnabled = "practiceReminderEnabled"
        static let practiceReminderHour = "practiceReminderHour"
        static let practiceReminderMinute = "practiceReminderMinute"

        // Check-in reminder cadence (secondary since the practice pivot)
        static let reminderEnabled = "reminderEnabled"
        static let reminderIntervalMinutes = "reminderIntervalMinutes"
        static let activeHoursStart = "activeHoursStart"
        static let activeHoursEnd = "activeHoursEnd"

        // Pro features
        static let airpodsBackgroundEnabled = "airpodsBackgroundEnabled"

        // AirPods ownership (asked once at onboarding, nil if never asked)
        static let hasAirpods = "hasAirpods"

        // What the user wants to improve (asked at onboarding)
        static let postureFocus = "postureFocus"

        // Live in-app posture readout while the app is open (free, default on)
        static let inAppLiveEnabled = "inAppLiveEnabled"

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

    /// One-shot: the "7 days on us" trial screen shown once at the end of
    /// onboarding (after calibration) to non-subscribers. Dismissible - the
    /// core loop stays free - but it's the highest-intent moment to pitch the
    /// trial. Set when the user starts the trial or taps "Maybe later".
    var hasSeenOnboardingTrial: Bool {
        get { access(keyPath: \.hasSeenOnboardingTrial); return defaults.bool(forKey: Key.hasSeenOnboardingTrial) }
        set { withMutation(keyPath: \.hasSeenOnboardingTrial) { defaults.set(newValue, forKey: Key.hasSeenOnboardingTrial) } }
    }

    /// One-shot: the guided training tour runs on the first Today visit after
    /// the paywall, teaching the monitoring loop (live status → rhythm →
    /// feel the nudge). Replayable from Settings.
    var hasSeenTrainingTour: Bool {
        get { access(keyPath: \.hasSeenTrainingTour); return defaults.bool(forKey: Key.hasSeenTrainingTour) }
        set { withMutation(keyPath: \.hasSeenTrainingTour) { defaults.set(newValue, forKey: Key.hasSeenTrainingTour) } }
    }

    /// One-shot: the first practice session shows in-session coach marks
    /// (ring → slouch on purpose → hold) instead of the old TrainingTour.
    var hasSeenSessionCoachMarks: Bool {
        get { access(keyPath: \.hasSeenSessionCoachMarks); return defaults.bool(forKey: Key.hasSeenSessionCoachMarks) }
        set { withMutation(keyPath: \.hasSeenSessionCoachMarks) { defaults.set(newValue, forKey: Key.hasSeenSessionCoachMarks) } }
    }

    /// One-shot: pre-pivot users get a Today banner explaining that the
    /// streak now comes from the daily practice.
    var hasSeenPivotExplainer: Bool {
        get { access(keyPath: \.hasSeenPivotExplainer); return defaults.bool(forKey: Key.hasSeenPivotExplainer) }
        set { withMutation(keyPath: \.hasSeenPivotExplainer) { defaults.set(newValue, forKey: Key.hasSeenPivotExplainer) } }
    }

    /// One-shot: on the first launch after the practice pivot, an active
    /// streak gets today credited for free so the model switch can't kill it.
    var didApplyPracticePivotGrace: Bool {
        get { access(keyPath: \.didApplyPracticePivotGrace); return defaults.bool(forKey: Key.didApplyPracticePivotGrace) }
        set { withMutation(keyPath: \.didApplyPracticePivotGrace) { defaults.set(newValue, forKey: Key.didApplyPracticePivotGrace) } }
    }

    var sensitivity: Int {
        get { access(keyPath: \.sensitivity); return defaults.object(forKey: Key.sensitivity) as? Int ?? 1 }
        set { withMutation(keyPath: \.sensitivity) { defaults.set(newValue, forKey: Key.sensitivity) } }
    }

    var alwaysOnEnabled: Bool {
        get { access(keyPath: \.alwaysOnEnabled); return defaults.bool(forKey: Key.alwaysOnEnabled) }
        set { withMutation(keyPath: \.alwaysOnEnabled) { defaults.set(newValue, forKey: Key.alwaysOnEnabled) } }
    }

    // MARK: - Daily practice reminder

    /// The one reminder that matters: today's practice session.
    var practiceReminderEnabled: Bool {
        get { access(keyPath: \.practiceReminderEnabled); return defaults.object(forKey: Key.practiceReminderEnabled) as? Bool ?? true }
        set { withMutation(keyPath: \.practiceReminderEnabled) { defaults.set(newValue, forKey: Key.practiceReminderEnabled) } }
    }

    /// Hour (0-23) of the daily practice reminder.
    var practiceReminderHour: Int {
        get { access(keyPath: \.practiceReminderHour); return defaults.object(forKey: Key.practiceReminderHour) as? Int ?? 10 }
        set { withMutation(keyPath: \.practiceReminderHour) { defaults.set(newValue, forKey: Key.practiceReminderHour) } }
    }

    var practiceReminderMinute: Int {
        get { access(keyPath: \.practiceReminderMinute); return defaults.object(forKey: Key.practiceReminderMinute) as? Int ?? 0 }
        set { withMutation(keyPath: \.practiceReminderMinute) { defaults.set(newValue, forKey: Key.practiceReminderMinute) } }
    }

    // MARK: - Check-in reminder cadence (secondary)

    /// Toggle for the extra throughout-the-day check-in nudges. Off by
    /// default since the practice pivot - `migrateToPracticeReminders()`
    /// preserves the old implicit `true` for existing users.
    var reminderEnabled: Bool {
        get { access(keyPath: \.reminderEnabled); return defaults.object(forKey: Key.reminderEnabled) as? Bool ?? false }
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

    /// What the user said they want to improve. Coaching copy leans on it;
    /// calibration always captures both postures regardless.
    var postureFocus: PostureFocus {
        get {
            access(keyPath: \.postureFocus)
            return PostureFocus(rawValue: defaults.string(forKey: Key.postureFocus) ?? "") ?? .both
        }
        set { withMutation(keyPath: \.postureFocus) { defaults.set(newValue.rawValue, forKey: Key.postureFocus) } }
    }

    /// Show the live posture readout at the top of Today whenever the app is
    /// open with AirPods in. Free feature, on by default, motion stops the
    /// moment the app backgrounds (unless the Pro all-day toggle holds it).
    var inAppLiveEnabled: Bool {
        get { access(keyPath: \.inAppLiveEnabled); return defaults.object(forKey: Key.inAppLiveEnabled) as? Bool ?? true }
        set { withMutation(keyPath: \.inAppLiveEnabled) { defaults.set(newValue, forKey: Key.inAppLiveEnabled) } }
    }

    // MARK: - Migration from old reminder keys

    /// Migrate settings from the old daily-reminder model to the new cadence model.
    /// Call once on first launch after update. Only applies to installs that
    /// actually carry the deprecated keys - on a fresh install this must not
    /// write `reminderEnabled` (it would defeat the off-by-default check-in
    /// nudges introduced with the practice pivot).
    func migrateFromDeprecatedKeys() {
        guard defaults.object(forKey: Key.reminderEnabled) == nil else { return }
        guard defaults.object(forKey: Key.dailyReminderEnabled) != nil
            || defaults.object(forKey: Key.dailyReminderHour) != nil else { return }
        let oldEnabled = defaults.object(forKey: Key.dailyReminderEnabled) as? Bool ?? true
        reminderEnabled = oldEnabled
        if let oldHour = defaults.object(forKey: Key.dailyReminderHour) as? Int {
            // Clamp to the Settings stepper range (6...22) and keep the
            // window valid - an evening reminder hour (e.g. 21) would
            // otherwise produce start >= end, which schedules nothing.
            activeHoursStart = min(max(oldHour, 6), 22)
            if activeHoursEnd <= activeHoursStart {
                activeHoursEnd = activeHoursStart + 1
            }
        }
        defaults.removeObject(forKey: Key.dailyReminderEnabled)
        defaults.removeObject(forKey: Key.dailyReminderHour)
    }

    /// Practice-pivot migration. The check-in reminder default flipped from
    /// implicit `true` to `false`; a pre-pivot user who never touched the
    /// toggle expects their ~every-30-min nudges to keep firing, so write the
    /// old implicit value explicitly before the new default takes over.
    /// One-shot, keyed on `practiceReminderEnabled` never having been set.
    func migrateToPracticeReminders() {
        guard defaults.object(forKey: Key.practiceReminderEnabled) == nil else { return }
        practiceReminderEnabled = true
        if hasCompletedOnboarding, defaults.object(forKey: Key.reminderEnabled) == nil {
            reminderEnabled = true
        }
    }

    #if DEBUG
    /// Wipe onboarding/calibration state so a UI test starts at the
    /// welcome screen regardless of prior installs. Test-only.
    func resetForUITest() {
        for key in [Key.hasCompletedOnboarding, Key.hasCalibrated, Key.calibrationDeferred, Key.hasSeenIntroPaywall, Key.hasSeenTrainingTour, Key.hasSeenSessionCoachMarks, Key.hasSeenPivotExplainer, Key.didApplyPracticePivotGrace, Key.practiceReminderEnabled, Key.practiceReminderHour, Key.practiceReminderMinute, Key.hasAirpods] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
