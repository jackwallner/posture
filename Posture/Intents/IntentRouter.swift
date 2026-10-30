import Observation

/// Hands App Intent requests to the UI. An intent can cold-launch the app
/// before the root view exists, so requests wait here until a view consumes
/// them.
@MainActor
@Observable
final class IntentRouter {
    static let shared = IntentRouter()

    enum Request: Equatable {
        case startMonitoring
        case startPractice
    }

    /// What Settings should present for a monitoring request it can't start.
    enum SettingsPrompt: Equatable {
        /// Not Pro: the same trial gate as the all-day toggle.
        case proGate
        /// Pro, but all-day monitoring was never turned on: show its
        /// orange-dot disclosure once instead of skipping it.
        case confirmAllDay
    }

    enum MonitoringRoute: Equatable {
        case start
        case settings(SettingsPrompt)
    }

    /// Set by an intent's `perform()`; cleared by the root view.
    var pending: Request?
    /// Set by the root view; cleared by Settings once it presents.
    var settingsPrompt: SettingsPrompt?

    nonisolated static func monitoringRoute(isPro: Bool, allDayEnabled: Bool) -> MonitoringRoute {
        guard isPro else { return .settings(.proGate) }
        guard allDayEnabled else { return .settings(.confirmAllDay) }
        return .start
    }
}
