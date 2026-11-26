import Foundation

/// Everything RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every variant
/// ships in the binary; a missing, non-string or unknown value is the control,
/// which is what the app shipped before the reader. Keys that a switch reads
/// must be set the same on every offering, or an Experiment arm would flip them
/// as a side effect. Wording tests go through the offering metadata key
/// `trial_cta`.
///
/// DEBUG builds can pin any key for captures: `-posture.rc.<key> <value>`.

/// The trial button's wording on the surfaces that carry one.
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: today's copy on every surface, with the real trial length
    /// ("Start 7-day free trial").
    case control = "seven_day"
    case my
    case your

    enum Surface: Sendable {
        /// The onboarding trial page, sentence case.
        case onboarding
        /// The paywall, title case.
        case paywall
        /// The one-tap trial sheet, title case.
        case sheet
    }

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .control)
    }

    /// The onboarding page's button. `controlLabel` is the eligible package's
    /// "Start 7-day free trial" copy, nil when no package is known to offer a
    /// trial. Then the page keeps its old wording on every arm, so a new arm
    /// never adds a trial promise the control did not make (3.1.2).
    func onboardingTitle(controlLabel: String?) -> String {
        guard let controlLabel else { return String(localized: "Start 7-day free trial") }
        return title(.onboarding, control: controlLabel)
    }

    /// The sheet's button has always read "Start My Free Trial".
    static var sheetControl: String { String(localized: "Start My Free Trial") }

    /// `control` is the surface's existing copy (it names the real trial
    /// length), returned untouched for the control arm. The other arms read the
    /// same on every plan.
    func title(_ surface: Surface, control: String) -> String {
        switch (self, surface) {
        case (.control, _): return control
        case (.my, .onboarding): return String(localized: "Start my free trial")
        case (.my, .paywall), (.my, .sheet): return String(localized: "Start My Free Trial")
        case (.your, .onboarding): return String(localized: "Start your free trial")
        case (.your, .paywall), (.your, .sheet): return String(localized: "Start Your Free Trial")
        }
    }
}

/// Remote off switches, for what is worth pausing without a release. On unless
/// the metadata says "off".
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's rating prompt after a good moment.
    case ratingPrompt = "rating_prompt"
}

enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string, or
    /// not one of the shipped variants.
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

extension SubscriptionService {
    var trialCTA: TrialCTA { TrialCTA.from(metadata: offeringMetadata) }

    func isOn(_ remoteSwitch: RemoteSwitch) -> Bool {
        RemoteConfig.isOn(remoteSwitch, in: offeringMetadata)
    }
}
