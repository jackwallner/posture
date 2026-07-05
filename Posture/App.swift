import StoreKit
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
        // The delegate must be in place before launch finishes, or the tap
        // that cold-launched the app is never delivered to didReceive. The
        // tap is buffered in the delegate until the root view wires up
        // `onReceive`.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        WatchSyncService.shared.activate()
        ReviewPromptTracker.recordAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let mode = PaywallScreenshotMode.current {
                PaywallScreenshotHarness(mode: mode)
                    .environment(settings)
                    .preferredColorScheme(.light)
            } else {
                AirpodsRootView()
                    .environment(settings)
                    .preferredColorScheme(.light)
            }
            #else
            AirpodsRootView()
                .environment(settings)
                .preferredColorScheme(.light)
            #endif
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
    @State private var showingPracticeFromReminder = false

    var body: some View {
        RootView()
            .environment(monitor)
            .onAppear {
                guard !didActivate else { return }
                didActivate = true
                // All-day monitoring runs only for Pro users who turned the
                // Settings toggle on — since the practice pivot it is an
                // optional extra, not the default. P1-7: a cold launch fires
                // no onChange hooks, so do the right thing here.
                startMonitoringForCurrentTier(monitor)
                NotificationDelegate.shared.onReceive = { scheduledAt, index in
                    ackScheduledAt = scheduledAt
                    ackNotificationIndex = index
                }
                NotificationDelegate.shared.onPracticeTap = {
                    showingPracticeFromReminder = true
                }
            }
            .fullScreenCover(item: .init(
                get: { ackScheduledAt.map { AckCover(scheduledAt: $0, index: ackNotificationIndex ?? 0) } },
                set: { if $0 == nil { ackScheduledAt = nil } }
            )) { cover in
                AcknowledgmentView(scheduledAt: cover.scheduledAt, notificationIndex: cover.index)
            }
            .fullScreenCover(isPresented: $showingPracticeFromReminder) {
                PracticeSessionView()
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
            .onChange(of: settings.practiceReminderEnabled) { _, _ in
                Task { await ReminderScheduler.reschedule() }
            }
            .onChange(of: settings.practiceReminderHour) { _, _ in
                Task { await ReminderScheduler.reschedule() }
            }
            .onChange(of: settings.practiceReminderMinute) { _, _ in
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

    /// All-day monitoring is an opt-in Pro extra since the practice pivot:
    /// it runs only when the user has AirPods, is subscribed, AND flipped
    /// the Settings toggle. It never auto-starts just because someone is Pro
    /// — that would compete with practice sessions for the motion stream.
    private func startMonitoringForCurrentTier(_ m: AirpodsBackgroundMonitor) {
        guard settings.hasAirpods == true,
              subscriptions.isProSubscriber,
              settings.airpodsBackgroundEnabled else { return }
        _ = m.start(background: true)
    }

    private func restartMonitoringForCurrentTier(_ m: AirpodsBackgroundMonitor) {
        m.stop()
        startMonitoringForCurrentTier(m)
    }
}

private struct AckCover: Identifiable {
    let scheduledAt: Date
    let index: Int
    // Stable identity derived from the reminder it represents. A random
    // UUID here would change on every parent re-render, and
    // `.fullScreenCover(item:)` keys presentation off `id` — a churning id
    // tears down and rebuilds the live AcknowledgmentView mid-check-in,
    // snapping it back from .scanning/.done to .choice.
    var id: String { "\(scheduledAt.timeIntervalSince1970)-\(index)" }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    /// A tap that arrived before the root view assigned `onReceive` — i.e.
    /// the notification cold-launched the app. Replayed on assignment.
    @MainActor private var pendingTap: (scheduledAt: Date, index: Int)?

    /// Same buffering for a practice-reminder tap that cold-launched the app.
    @MainActor private var pendingPracticeTap = false

    /// Called when a posture-reminder notification is tapped. Invoked on
    /// the main actor — it mutates SwiftUI state.
    @MainActor var onReceive: (@MainActor (Date, Int) -> Void)? {
        didSet {
            guard let onReceive, let tap = pendingTap else { return }
            pendingTap = nil
            onReceive(tap.scheduledAt, tap.index)
        }
    }

    /// Called when the daily-practice reminder is tapped — opens the session.
    @MainActor var onPracticeTap: (@MainActor () -> Void)? {
        didSet {
            guard let onPracticeTap, pendingPracticeTap else { return }
            pendingPracticeTap = false
            onPracticeTap()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["type"] as? String == "practice-reminder" {
            Task { @MainActor in
                if let onPracticeTap = self.onPracticeTap {
                    onPracticeTap()
                } else {
                    self.pendingPracticeTap = true
                }
            }
        } else if userInfo["type"] as? String == "posture-reminder" {
            let stored = Date(timeIntervalSince1970: userInfo["scheduledAt"] as? TimeInterval ?? 0)
            let index = userInfo["index"] as? Int ?? 0
            // Repeating triggers carry the date they were *scheduled*, which
            // can be days old if the app hasn't been foregrounded since. Only
            // the slot's time-of-day is meaningful — pin it to today so the
            // check-in screen and the saved record show the right day.
            let slot = Calendar.current.dateComponents([.hour, .minute], from: stored)
            let scheduledAt = Calendar.current.date(
                bySettingHour: slot.hour ?? 0, minute: slot.minute ?? 0, second: 0, of: Date()
            ) ?? stored
            // P1-6: hop to the main actor — this delegate fires on UN's
            // private queue and the callback touches @State.
            Task { @MainActor in
                if let onReceive = self.onReceive {
                    onReceive(scheduledAt, index)
                } else {
                    self.pendingTap = (scheduledAt, index)
                }
            }
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
    @Environment(\.modelContext) private var context
    @State private var didMigrate = false

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingView()
            } else if !settings.hasCalibrated {
                CalibrationView()
            } else {
                // No hard gate since the practice pivot: the core daily loop
                // is free, the paywall appears after the first completed
                // session and at Pro feature gates.
                MainTabView()
            }
        }
        .task {
            guard !didMigrate else { return }
            settings.migrateFromDeprecatedKeys()
            settings.migrateToPracticeReminders()
            applyPracticePivotGraceIfNeeded()
            didMigrate = true
            // Hold the iOS notification prompt until after onboarding so
            // the user reads the reminder pitch before the system asks.
            if settings.hasCompletedOnboarding {
                await ReminderScheduler.reschedule()
            }
        }
    }

    /// One-shot on the first launch after the practice pivot: an active
    /// streak gets today credited for free, so switching the streak source
    /// from monitoring to sessions can't kill an existing run overnight.
    private func applyPracticePivotGraceIfNeeded() {
        guard !settings.didApplyPracticePivotGrace else { return }
        settings.didApplyPracticePivotGrace = true
        guard settings.hasCompletedOnboarding else { return }
        let service = StreakService(context: context)
        if StreakService.displayStreak(for: service.currentState()) > 0 {
            _ = service.recordAcknowledgment(at: .now)
        }
    }
}

struct MainTabView: View {
    @Environment(GoalSettings.self) private var settings
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var selectedTab = 0
    @State private var showReviewPrompt = false
    @State private var reviewPromptInitialStep: ReviewPromptSheet.Step = .enjoyment
    @State private var reviewPromptShownThisSession = false
    @State private var pendingNativeReviewAfterDismiss = false
    @Environment(\.requestReview) private var requestReview

    private var hasCompletedSetup: Bool {
        settings.hasCompletedOnboarding && settings.hasCalibrated
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "leaf.fill") }
                .tag(0)
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .tint(Theme.sage)
        .onReceive(NotificationCenter.default.publisher(for: .posturePositiveMomentForReview)) { _ in
            scheduleReviewPromptAfterPositiveMoment()
        }
        // Settings' "Replay the Walkthrough" — the tour lives on Today, so
        // switch there; TodayView receives the same notification and starts it.
        .onReceive(NotificationCenter.default.publisher(for: .postureReplayTrainingTour)) { _ in
            selectedTab = 0
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == 0 {
                scheduleReviewPromptAfterPositiveMoment()
            }
        }
        .onChange(of: reviewPromptCoordinator.pendingPresentation) { _, presentation in
            guard let presentation else { return }
            defer { reviewPromptCoordinator.clear() }
            switch presentation {
            case .enjoymentPrompt:
                presentReviewPrompt(step: .enjoyment)
            case .feedbackOnly:
                presentReviewPrompt(step: .feedback)
            }
        }
        .sheet(isPresented: $showReviewPrompt, onDismiss: {
            // Swipe-to-dismiss skips every button path — start the cooldown
            // here too, or the prompt can come back at the next positive
            // moment. Redundant after a button outcome, which is harmless.
            ReviewPromptTracker.markShown()
            if pendingNativeReviewAfterDismiss {
                pendingNativeReviewAfterDismiss = false
                requestReview()
            }
        }) {
            ReviewPromptSheet(initialStep: reviewPromptInitialStep, onFinish: handleReviewPromptFinish)
        }
    }

    private func scheduleReviewPromptAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedSetup),
              !reviewPromptShownThisSession,
              selectedTab == 0,
              !showReviewPrompt
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard selectedTab == 0,
                  !showReviewPrompt,
                  ReviewPromptTracker.shouldShowAfterPositiveMoment(hasCompletedSetup: hasCompletedSetup)
            else { return }
            ReviewPromptTracker.consumePendingPositiveMoment()
            reviewPromptInitialStep = .enjoyment
            reviewPromptShownThisSession = true
            showReviewPrompt = true
        }
    }

    private func handleReviewPromptFinish(_ outcome: ReviewPromptDismissOutcome) {
        showReviewPrompt = false
        if outcome == .enjoyedMaybeLater {
            pendingNativeReviewAfterDismiss = true
        }
    }

    private func presentReviewPrompt(step: ReviewPromptSheet.Step) {
        reviewPromptInitialStep = step
        reviewPromptShownThisSession = true
        showReviewPrompt = true
    }
}
