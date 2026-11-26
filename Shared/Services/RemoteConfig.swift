import Foundation

/// Everything RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every
/// variant ships in the binary; a missing, non-string or unknown value is the
/// control, which is what the last release shipped. Keys that a switch reads
/// must be set the same on every offering, or an Experiment arm would flip
/// them as a side effect. Wording tests go through the offering metadata key
/// `trial_cta`.
///
/// DEBUG builds can pin any key for captures: `-posture.rc.<key> <value>`.
/// Pure Foundation, so the unit-test bundle compiles it without RevenueCat.

/// The trial button's wording. Onboarding uses sentence case, the paywall and
/// the trial sheet title case.
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: today's copy, character for character. The onboarding and
    /// paywall buttons name the trial length from the store package ("Start
    /// 7-day free trial", "Start My 7-Day Free Trial"); the sheet says "Start
    /// My Free Trial". The caller passes that text in.
    case control = "seven_day"
    case my
    case your

    enum Surface: Sendable {
        case onboarding, paywall, sheet
    }

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .control)
    }

    /// The button title. `control` is the text the surface showed before this
    /// test existed; the control arm returns it untouched.
    func title(_ surface: Surface, control controlTitle: String) -> String {
        switch (self, surface) {
        case (.control, _): return controlTitle
        case (.my, .onboarding): return String(localized: "Start my free trial")
        case (.my, .paywall), (.my, .sheet): return String(localized: "Start My Free Trial")
        case (.your, .onboarding): return String(localized: "Start your free trial")
        case (.your, .paywall), (.your, .sheet): return String(localized: "Start Your Free Trial")
        }
    }
}

/// Remote off switches, for what is worth pausing without a release. On
/// unless the metadata says "off".
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a good moment. "off" pauses the automatic ask.
    case ratingPrompt = "rating_prompt"
}

enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string,
    /// or not one of the shipped variants.
    static func value<T: RawRepresentable>(_ key: String, in metadata: [String: Any]?, default fallback: T) -> T
    where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-posture.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}
