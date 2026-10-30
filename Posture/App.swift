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
        if LaunchArguments.contains("UITEST_FRESH") {
            GoalSettings.shared.resetForUITest()
            SubscriptionService.shared.resetForUITest()
        }
        ScreenshotSeed.seedIfNeeded()
        #endif
        SubscriptionService.shared.configure()
        NotificationService.registerCategories()
        // The delegate must be in place before launch finishes, or the tap
        // that cold-launched the app is never delivered to didReceive. The
        // tap is buffered in the delegate until the root view wires up
        // `onReceive`.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        WatchSyncService.shared.activate()
        PhoneLockState.shared.start(locked: !UIApplication.shared.isProtectedDataAvailable)
        ReviewPromptTracker.recordAppLaunch()
        ConversionDiagnostics.recordAppOpen()
        #if DEBUG && HAS_REVENUECAT
        if RevenueCatProbe.isEnabled {
            // Same entry point the real paywall screens call, so what this
            // proves is the actual path and not a parallel one.
            SubscriptionService.shared.trackPaywallImpression(id: RevenueCatProbe.impressionID)
            if RevenueCatProbe.wantsPurchase {
                Task {
                    await SubscriptionService.shared.fetchProducts()
                    // Logged rather than asserted: when the Test Store sheet
                    // never appears, this separates "not configured" from
                    // "nothing came back" from "purchase threw".
                    NSLog("RCPROBE configured=%@ products=%d",
                          String(describing: SubscriptionService.shared.isConfigured),
                          SubscriptionService.shared.products.count)
                    guard let package = SubscriptionService.shared.products.first else { return }
                    do {
                        let state = try await SubscriptionService.shared.purchase(package)
                        NSLog("RCPROBE purchase outcome=%@", String(describing: state))
                    } catch {
                        NSLog("RCPROBE purchase error=%@", String(describing: error))
                    }
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            StorageContainerView {
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
        }
    }
}

// MARK: - Root with AirPods Monitor Setup

private struct AirpodsRootView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptions = SubscriptionService.shared
    // Process-scoped - see `AirpodsBackgroundMonitor.shared` for why this
    // can't be a `@State` default expression. SwiftUI re-evaluates @State
    // initial values on every parent rerender; with the monitor's audio
    // observers having no removal hook, those dropped instances would leak
    // observers into NotificationCenter forever.
    private let monitor = AirpodsBackgroundMonitor.shared
    @State private var didActivate = false
    @State private var ackScheduledAt: Date?
    @State private var ackNotificationIndex: Int?
    @State private var showingPracticeFromReminder = false
    private let intents = IntentRouter.shared

    var body: some View {
        RootView()
            .environment(monitor)
            .onAppear {
                guard !didActivate else { return }
                didActivate = true
                // P1-7: a cold launch fires no onChange hooks, so decide the
                // monitoring mode (Pro all-day vs free in-app live) here.
                reconcileMonitoring(monitor)
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
                PracticeSessionView(mode: settings.postureFocus.defaultMode)
            }
            .onChange(of: intents.pending, initial: true) { _, request in
                guard let request else { return }
                intents.pending = nil
                handle(request)
            }
            .onChange(of: ackScheduledAt != nil || showingPracticeFromReminder, initial: true) { _, covered in
                ReviewPromptCoordinator.shared.rootIsCovered = covered
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
                monitor.stop()
                reconcileMonitoring(monitor)
            }
            .onChange(of: settings.inAppLiveEnabled) { _, _ in
                monitor.stop()
                reconcileMonitoring(monitor)
            }
            .onChange(of: subscriptions.isProSubscriber) { _, _ in
                monitor.stop()
                reconcileMonitoring(monitor)
                WatchSyncService.shared.pushState()
            }
            .onChange(of: scenePhase) { _, _ in
                reconcileMonitoring(monitor)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await ReminderScheduler.reschedule() }
                reconcileMonitoring(monitor)
            }
    }

    /// A Shortcuts automation asked for monitoring or practice. Before setup
    /// is done (or without AirPods) the app just opens.
    private func handle(_ request: IntentRouter.Request) {
        guard settings.hasCompletedOnboarding, settings.hasCalibrated, settings.hasAirpods == true else { return }
        switch request {
        case .startPractice:
            // Already in a check-in or practice: a second cover can't present
            // and its flag would stick.
            guard ackScheduledAt == nil, !showingPracticeFromReminder else { return }
            showingPracticeFromReminder = true
        case .startMonitoring:
            // An explicit start overrides "Stop for now", including after the
            // Settings confirmation below, which reconciles on its own.
            monitor.userPaused = false
            switch IntentRouter.monitoringRoute(
                isPro: subscriptions.isProSubscriber,
                allDayEnabled: settings.airpodsBackgroundEnabled
            ) {
            case .start:
                reconcileMonitoring(monitor)
            case .settings(let prompt):
                // Settings sits under any open cover and couldn't present.
                guard ackScheduledAt == nil, !showingPracticeFromReminder else { return }
                intents.settingsPrompt = prompt
            }
        }
    }

    /// One place decides whether the shared monitor should be running and in
    /// which mode:
    /// - Pro + all-day toggle → background monitoring (silent-audio keep-alive).
    /// - Otherwise, the free in-app live readout (`inAppLiveEnabled`, default
    ///   on) runs motion while the app is foregrounded and stops when it
    ///   leaves - no keep-alive, no orange dot beyond the active session.
    /// - A manual Stop from the Today card (`userPaused`) beats both until
    ///   the user starts it again.
    private func reconcileMonitoring(_ m: AirpodsBackgroundMonitor) {
        guard settings.hasAirpods == true, !m.userPaused else {
            m.stop()
            return
        }
        if subscriptions.isProSubscriber, settings.airpodsBackgroundEnabled {
            if !m.isMonitoring || !m.isBackground {
                m.stop()
                _ = m.start(background: true)
                // Background slouch alerts arrive as notifications. Prompts
                // only if the user was never asked.
                Task { _ = await NotificationService.requestAuthorization() }
            }
            return
        }
        if settings.inAppLiveEnabled, scenePhase != .background {
            if !m.isMonitoring || m.isBackground {
                m.stop()
                _ = m.start(background: false)
            }
            return
        }
        m.stop()
    }
}

private struct AckCover: Identifiable {
    let scheduledAt: Date
    let index: Int
    // Stable identity derived from the reminder it represents. A random
    // UUID here would change on every parent re-render, and
    // `.fullScreenCover(item:)` keys presentation off `id` - a churning id
    // tears down and rebuilds the live AcknowledgmentView mid-check-in,
    // snapping it back from .scanning/.done to .choice.
    var id: String { "\(scheduledAt.timeIntervalSince1970)-\(index)" }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    /// A tap that arrived before the root view assigned `onReceive` - i.e.
    /// the notification cold-launched the app. Replayed on assignment.
    @MainActor private var pendingTap: (scheduledAt: Date, index: Int)?

    /// Same buffering for a practice-reminder tap that cold-launched the app.
    @MainActor private var pendingPracticeTap = false

    /// Called when a posture-reminder notification is tapped. Invoked on
    /// the main actor - it mutates SwiftUI state.
    @MainActor var onReceive: (@MainActor (Date, Int) -> Void)? {
        didSet {
            guard let onReceive, let tap = pendingTap else { return }
            pendingTap = nil
            onReceive(tap.scheduledAt, tap.index)
        }
    }

    /// Called when the daily-practice reminder is tapped - opens the session.
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
            // the slot's time-of-day is meaningful - pin it to today so the
            // check-in screen and the saved record show the right day.
            let slot = Calendar.current.dateComponents([.hour, .minute], from: stored)
            let scheduledAt = Calendar.current.date(
                bySettingHour: slot.hour ?? 0, minute: slot.minute ?? 0, second: 0, of: Date()
            ) ?? stored
            // P1-6: hop to the main actor - this delegate fires on UN's
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
    @State private var subscriptions = SubscriptionService.shared
    @State private var didMigrate = false

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingView()
                    .unfoldedLeadingPane { SetupFoldPanel() }
            } else if !settings.hasCalibrated {
                CalibrationView()
                    .unfoldedLeadingPane { SetupFoldPanel() }
            } else {
                // Let new users feel the calibrated practice before asking them
                // to subscribe. The first completed session is the proof moment;
                // PracticeSessionView presents the trial from its summary.
                MainTabView()
            }
        }
        .task {
            // End any Live Activity orphaned by a prior crash/force-quit before
            // anything can start a new one - otherwise a crashed walk's Dynamic
            // Island countdown lingers and the next walk stacks a second.
            await PracticeSessionController.endAllLiveActivities()
            guard !didMigrate else { return }
            settings.migrateFromDeprecatedKeys()
            settings.migrateToPracticeReminders()
            applyPracticePivotGraceIfNeeded()
            didMigrate = true
            // Hold the iOS notification prompt until after onboarding so
            // the user reads the reminder pitch before the system asks.
            if settings.hasCompletedOnboarding, settings.hasCalibrated {
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

/// The unfolded iPhone Duo's trailing pane during onboarding and calibration,
/// which stay a phone-width column on the leading side of the fold.
private struct SetupFoldPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.sage)
            Text("A few minutes a day.")
                .font(Theme.display(30))
                .foregroundStyle(Theme.ink)
            Text("Your AirPods coach each short session, and your streak grows with every day you show up.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MainTabView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @State private var subscriptions = SubscriptionService.shared
    @State private var selectedTab = 0
    @State private var reviewPromptShownThisSession = false
    /// The container's width and fold, measured so the unfolded iPhone Duo can
    /// put Today and History on opposite sides of the fold.
    @State private var paneGeometry = PaneGeometry()
    @Environment(\.requestReview) private var requestReview

    private var hasCompletedSetup: Bool {
        settings.hasCompletedOnboarding && settings.hasCalibrated
    }

    /// Unfolded, History has its own pane beside Today, so it is never a tab.
    private var split: UnfoldedSplit? {
        UnfoldedSplit.make(
            width: paneGeometry.width,
            isRegularWidth: horizontalSizeClass == .regular,
            fold: paneGeometry.fold
        )
    }

    /// Each unfolded pane is phone-width, so its screen lays out as on a phone.
    /// Applied to the tab contents, not the `TabView`, whose bar placement is
    /// left to the system.
    private var paneSizeClass: UserInterfaceSizeClass? {
        split == nil ? horizontalSizeClass : .compact
    }

    var body: some View {
        // Opening or closing the Duo only moves these frames, so the tab view
        // is never rebuilt and Today keeps its scroll position and sheets.
        ZStack(alignment: .topLeading) {
            // Behind the fold, which neither pane covers.
            Theme.dawnWash.ignoresSafeArea()
            tabs
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)
            if let split {
                HistoryView(opensSessionsInPane: true)
                    .phonePane(isSplit: true, sizeClass: .compact)
                    .unfoldedBarClearance(isSplit: true)
                    .frame(width: split.secondaryWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .measuresPaneGeometry($paneGeometry)
        .onChange(of: split != nil) { _, isSplit in
            if isSplit, selectedTab == 1 { selectedTab = 0 }
        }
        #if DEBUG
        .task(id: split != nil) { await runDuoTour(isSplit: split != nil) }
        #endif
        .tint(Theme.sage)
        .onReceive(NotificationCenter.default.publisher(for: .posturePositiveMomentForReview)) { _ in
            scheduleReviewPromptAfterPositiveMoment()
        }
        .task {
            // Entering the main tabs is the first calm moment after onboarding,
            // calibration, and the optional trial pitch.
            await ReminderScheduler.reschedule()
        }
        // Settings' "Replay practice coach marks" - the session opens from
        // Today, so switch there; TodayView receives the same notification
        // and presents the session.
        .onReceive(NotificationCenter.default.publisher(for: .postureReplaySessionCoachMarks)) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .postureSelectProgressTab)) { _ in
            selectedTab = 4
        }
        .onChange(of: IntentRouter.shared.settingsPrompt != nil, initial: true) { _, pending in
            if pending { selectedTab = 2 }
        }
        .onChange(of: selectedTab) { oldTab, tab in
            // A check-in from History leaves its moment pending; coming back to
            // Today picks it up. Never straight off the Posture+ paywall tab.
            if tab == 0, oldTab != 3 {
                scheduleReviewPromptAfterPositiveMoment()
            }
        }
    }

    /// The rating ask after a good check-in or streak milestone: Apple's own
    /// prompt, no question in front of it. Waits for the check-in to close,
    /// then asks only if Today is still clear. A blocked ask keeps the moment
    /// pending in the tracker; it never retries off a paywall or pitch.
    private func scheduleReviewPromptAfterPositiveMoment() {
        guard ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: hasCompletedSetup),
              !reviewPromptShownThisSession,
              isTodayClear
        else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard isTodayClear,
                  !reviewPromptShownThisSession,
                  ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: hasCompletedSetup)
            else { return }
            reviewPromptShownThisSession = true
            ReviewPromptTracker.markShown()
            requestReview()
        }
    }

    /// Today is on screen with no sheet, cover, paywall or trial pitch over it.
    private var isTodayClear: Bool {
        selectedTab == 0
            && !reviewPromptCoordinator.todayIsCovered
            && !reviewPromptCoordinator.rootIsCovered
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .phonePane(isSplit: split != nil, sizeClass: paneSizeClass)
                .unfoldedBarClearance(isSplit: split != nil)
                .tabItem { Label("Today", systemImage: "leaf.fill").accessibilityLabel("Today") }
                .tag(0)
            if split == nil {
                HistoryView()
                    .tabItem { Label("History", systemImage: "chart.bar.fill").accessibilityLabel("History") }
                    .tag(1)
            }
            ProgressTabView()
                .phonePane(isSplit: split != nil, sizeClass: paneSizeClass)
                .unfoldedBarClearance(isSplit: split != nil)
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis").accessibilityLabel("Progress") }
                .tag(4)
            // The upgrade pitch gets its own tab until the user subscribes.
            if !subscriptions.isProSubscriber {
                ProTabView()
                    .phonePane(isSplit: split != nil, sizeClass: paneSizeClass)
                    .unfoldedBarClearance(isSplit: split != nil)
                    .tabItem { Label("Posture+", systemImage: "lock.fill").accessibilityLabel("Posture+") }
                    .tag(3)
            }
            SettingsView(isSelectedTab: selectedTab == 2)
                .phonePane(isSplit: split != nil, sizeClass: paneSizeClass)
                .unfoldedBarClearance(isSplit: split != nil)
                .tabItem { Label("Settings", systemImage: "gearshape.fill").accessibilityLabel("Settings") }
                .tag(2)
        }
    }

    #if DEBUG
    /// See `DuoScreenshotTour`. Restarts when the panes split or join, so each
    /// display gets the whole walk, and holds the last route for the capture.
    private func runDuoTour(isSplit: Bool) async {
        guard DuoScreenshotTour.isEnabled else { return }
        try? await Task.sleep(for: .seconds(DuoScreenshotTour.firstDelay))
        for (index, route) in DuoScreenshotTour.routes(split: isSplit).enumerated() {
            if index > 0 { try? await Task.sleep(for: .seconds(DuoScreenshotTour.step)) }
            guard !Task.isCancelled else { return }
            NSLog("DUOTOUR %@ route=%@ width=%.1f fold=%@", isSplit ? "inner" : "outer", route,
                  paneGeometry.width, String(describing: paneGeometry.fold))
            // Unanimated, like a tab tap; an animated switch grows the new
            // tab in from a zero frame, which no user ever sees.
            openDuoRoute(route)
        }
    }

    private func openDuoRoute(_ route: String) {
        NotificationCenter.default.post(name: .postureDebugCloseSession, object: nil)
        switch route {
        case "history": selectedTab = split == nil ? 1 : 0
        case "progress": selectedTab = 4
        case "settings": selectedTab = 2
        case "session":
            // Split, the session opens in the History pane beside whichever tab is up.
            if split == nil { selectedTab = 1 }
            NotificationCenter.default.post(name: .postureDebugOpenLatestSession, object: nil)
        default: selectedTab = 0
        }
    }
    #endif
}

/// Lets Today and the app root report what they have on screen, so the
/// rating ask never lands on top of a sheet, cover or paywall.
@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    /// Set by `TodayView` while any of its sheets or covers is up.
    @Published var todayIsCovered = false
    /// Set by the app root while a reminder's check-in or practice cover is up.
    @Published var rootIsCovered = false

    private init() {}
}
