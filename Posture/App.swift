import SwiftData
import SwiftUI

@main
struct PostureApp: App {
    @State private var settings = GoalSettings.shared

    init() {
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
        .modelContainer(DataService.sharedModelContainer)
    }
}

struct RootView: View {
    @Environment(GoalSettings.self) private var settings

    var body: some View {
        if !settings.hasCompletedOnboarding {
            OnboardingView()
        } else if !settings.hasCalibrated {
            CalibrationView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.stand") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
