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
                let m = AirpodsBackgroundMonitor(modelContext: context)
                monitor = m
                // Free users with AirPods get foreground-only coaching so
                // they can feel the haptics while the app is open. Pro +
                // toggle extends that with the silent-audio background
                // trick. P1-7: a cold launch fires no onChange hooks, so
                // do the right thing here.
                startMonitoringForCurrentTier(m)
                UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
                NotificationDelegate.shared.onReceive = { scheduledAt, index in
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
            .onChange(of: settings.hasCompletedOnboarding) { _, completed in
                // First time the user finishes onboarding — now the
                // "a few nudges a day" copy has been read, so the iOS
                // notification prompt has context.
                if completed { Task { await ReminderScheduler.reschedule() } }
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
            .onChange(of: settings.airpodsBackgroundEnabled) { _, _ in
                if let m = monitor { restartMonitoringForCurrentTier(m) }
            }
            .onChange(of: subscriptions.isProSubscriber) { _, _ in
                if let m = monitor { restartMonitoringForCurrentTier(m) }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await ReminderScheduler.reschedule() }
                if let m = monitor, !m.isMonitoring {
                    startMonitoringForCurrentTier(m)
                }
            }
    }

    /// Free users with AirPods get foreground-only coaching. Pro + toggle
    /// gets the silent-audio background extension. Users without AirPods
    /// get nothing.
    private func startMonitoringForCurrentTier(_ m: AirpodsBackgroundMonitor) {
        guard settings.hasAirpods == true else { return }
        let allowBackground = settings.airpodsBackgroundEnabled
            && subscriptions.isProSubscriber
        _ = m.start(background: allowBackground)
    }

    private func restartMonitoringForCurrentTier(_ m: AirpodsBackgroundMonitor) {
        m.stop()
        startMonitoringForCurrentTier(m)
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

    /// Called when a posture-reminder notification is tapped. Invoked on
    /// the main actor — it mutates SwiftUI state.
    var onReceive: (@MainActor (Date, Int) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["type"] as? String == "posture-reminder" {
            let scheduledAt = Date(timeIntervalSince1970: userInfo["scheduledAt"] as? TimeInterval ?? 0)
            let index = userInfo["index"] as? Int ?? 0
            // P1-6: hop to the main actor — this delegate fires on UN's
            // private queue and the callback touches @State.
            Task { @MainActor in onReceive?(scheduledAt, index) }
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
    @Environment(GoalSettings.self) private var settings
    @State private var didMigrate = false

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingView()
            } else if !settings.hasCalibrated {
                CalibrationView()
            } else {
                MainTabView()
            }
        }
        .task {
            guard !didMigrate else { return }
            settings.migrateFromDeprecatedKeys()
            didMigrate = true
            // Hold the iOS notification prompt until after onboarding so
            // the user reads "a few nudges a day" before the system asks.
            if settings.hasCompletedOnboarding {
                await ReminderScheduler.reschedule()
            }
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
