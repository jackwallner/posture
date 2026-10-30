import AppIntents

/// Starts Pro all-day AirPods monitoring. Built for a Shortcuts personal
/// automation on "When AirPods connect" or "Time of Day". Opens the app:
/// the silent-audio keep-alive and head-motion stream are only proven to
/// start reliably from the foreground.
struct StartMonitoringIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Posture Monitoring"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.pending = .startMonitoring
        return .result()
    }
}

/// Opens today's practice session.
struct StartPracticeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Practice"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.pending = .startPractice
        return .result()
    }
}

struct PostureShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMonitoringIntent(),
            phrases: [
                "Start \(.applicationName) monitoring",
                "Start posture monitoring in \(.applicationName)",
            ],
            shortTitle: "Start Monitoring",
            systemImageName: "airpods.gen3"
        )
        AppShortcut(
            intent: StartPracticeIntent(),
            phrases: [
                "Start \(.applicationName) practice",
                "Start practice in \(.applicationName)",
            ],
            shortTitle: "Start Practice",
            systemImageName: "figure.stand"
        )
    }
}
