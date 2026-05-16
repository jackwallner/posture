import SwiftData
import SwiftUI
import UserNotifications

@main
struct PostureApp: App {
    @State private var settings = GoalSettings.shared
    @State private var subscriptions = SubscriptionService.shared

    init() {
        SubscriptionService.shared.configure()
        NotificationService.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            AirpodsRootView()
                .environment(settings)
        }
        .modelContainer(DataService.sharedModelContainer)
    }
}

// MARK: - Root with AirPods Monitor Setup

private struct AirpodsRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @State private var subscriptions = SubscriptionService.shared
    @State private var monitor: AirpodsBackgroundMonitor?
    @State private var ackScheduledAt: Date?
    @State private var ackNotificationIndex: Int?

    var body: some View {
        RootView()
            .environment(monitor)
            .onAppear {
                guard monitor == nil else { return }
                monitor = AirpodsBackgroundMonitor(modelContext: context)
                // Set up notification delegate callback
                UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                NotificationDelegate.shared.onReceive = { [self] scheduledAt, index in
                    ackScheduledAt = scheduledAt
                    ackNotificationIndex = index
                }
            }
            .fullScreenCover(item: .init(
                get: { ackScheduledAt.map { AckCover(scheduledAt: $0, index: ackNotificationIndex ?? 0) } },
                set: { if $0 == nil { ackScheduledAt = nil } }
            )) { cover in
                AcknowledgmentView(scheduledAt: cover.scheduledAt, notificationIndex: cover.index)
            }
            .onChange(of: settings.reminderEnabled) { _, _ in
                Task { await ReminderScheduler.reschedule() }
            }
            .onChange(of: settings.reminderIntervalMinutes) { _, _ in
                Task { await ReminderScheduler.reschedule() }
            }
            .onChange(of: settings.activeHoursStart) { _, _ in
                Task { await ReminderScheduler.reschedule() }
            }
            .onChange(of: settings.activeHoursEnd) { _, _ in
                Task { await ReminderScheduler.reschedule() }
            }
            .onChange(of: settings.airpodsBackgroundEnabled) { _, enabled in
                updateMonitoring(enabled: enabled && subscriptions.isProSubscriber)
            }
            .onChange(of: subscriptions.isProSubscriber) { _, isPro in
                updateMonitoring(enabled: settings.airpodsBackgroundEnabled && isPro)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await ReminderScheduler.reschedule() }
                if settings.airpodsBackgroundEnabled && subscriptions.isProSubscriber {
                    _ = monitor?.start()
                }
            }
    }

    private func updateMonitoring(enabled: Bool) {
        if enabled {
            _ = monitor?.start()
        } else {
            monitor?.stop()
        }
    }
}

private struct AckCover: Identifiable {
    let id = UUID()
    let scheduledAt: Date
    let index: Int
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    /// Called when a posture-reminder notification is tapped.
    var onReceive: ((Date, Int) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["type"] as? String == "posture-reminder" {
            let scheduledAt = Date(timeIntervalSince1970: userInfo["scheduledAt"] as? TimeInterval ?? 0)
            let index = userInfo["index"] as? Int ?? 0
            onReceive?(scheduledAt, index)
        }
        completionHandler()
    }

    /// Show the notification as a banner even if the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound in foreground
        completionHandler([.banner, .sound])
    }
}

// MARK: - Root View

struct RootView: View {
    @State private var didMigrate = false

    var body: some View {
        Group {
            if !GoalSettings.shared.hasCompletedOnboarding {
                OnboardingView()
            } else if !GoalSettings.shared.hasCalibrated {
                CalibrationView()
            } else {
                MainTabView()
            }
        }
        .task {
            guard !didMigrate else { return }
            GoalSettings.shared.migrateFromDeprecatedKeys()
            didMigrate = true
            await ReminderScheduler.reschedule()
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
