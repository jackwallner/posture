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

    var body: some View {
        if !GoalSettings.shared.hasCompletedOnboarding {
            OnboardingView()
        } else if !GoalSettings.shared.hasCalibrated {
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
