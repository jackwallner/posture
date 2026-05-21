import SwiftData
import SwiftUI
import UserNotifications

@main
struct PostureApp: App {
    @State private var settings = GoalSettings.shared
    @State private var subscriptions = SubscriptionService.shared

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITEST_FRESH") {
            GoalSettings.shared.resetForUITest()
        }
        #endif
        SubscriptionService.shared.configure()
        NotificationService.registerCategories()
        WatchSyncService.shared.activate()
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
    @Environment(GoalSettings.self) private var settings
    @State private var subscriptions = SubscriptionService.shared
    // Process-scoped — see `AirpodsBackgroundMonitor.shared` for why this
    // can't be a `@State` default expression. SwiftUI re-evaluates @State
    // initial values on every parent rerender; with the monitor's audio
    // observers having no removal hook, those dropped instances would leak
    // observers into NotificationCenter forever.
    private let monitor = AirpodsBackgroundMonitor.shared
    @State private var didActivate = false
    @State private var ackScheduledAt: Date?
    @State private var ackNotificationIndex: Int?

    var body: some View {
        RootView()
            .environment(monitor)
            .onAppear {
                guard !didActivate else { return }
                didActivate = true
                // Free users with AirPods get foreground-only coaching so
                // they can feel the haptics while the app is open. Pro +
                // toggle extends that with the silent-audio background
                // trick. P1-7: a cold launch fires no onChange hooks, so
                // do the right thing here.
                startMonitoringForCurrentTier(monitor)
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
                restartMonitoringForCurrentTier(monitor)
            }
            .onChange(of: subscriptions.isProSubscriber) { _, _ in
                restartMonitoringForCurrentTier(monitor)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await ReminderScheduler.reschedule() }
                if !monitor.isMonitoring {
                    startMonitoringForCurrentTier(monitor)
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
                .tabItem { Label("Today", systemImage: "leaf.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.sage)
    }
}
