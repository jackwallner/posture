import SwiftData
import SwiftUI
import UserNotifications
#if HAS_REVENUECAT
import RevenueCat
#endif

struct SettingsView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?

    @State private var subscriptions = SubscriptionService.shared
    @State private var showTrialOffer = false
    @State private var showTrialPaywall = false
    @State private var paywallImpressionId = "posture_settings_sheet"
    @State private var trialOfferFocus: PosturePlusFeature?
    @State private var pendingFeatureEnable: PosturePlusFeature?
    @State private var pendingPaywallAfterTrialDismiss = false
    @State private var trialPurchaseInFlight = false
    @State private var trialPurchaseError: String?
    @State private var trialOfferDetent: PresentationDetent = .fraction(0.68)
    #if HAS_REVENUECAT
    @State private var trialOfferPackage: Package?
    #endif
    @State private var showingQuickRecalibrate = false
    @State private var showingWalkBaselineReset = false
    @State private var hasWalkBaseline = false
    @State private var notificationsDenied = false
    @State private var showingWatchSyncInfo = false
    @State private var showingAirpodsBackgroundConfirm = false

    private let intervalOptions = [15, 30, 60]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: - Pro

                Section {
                    Toggle(isOn: alwaysOnBinding) {
                        plusToggleLabel("Always-on Watch monitoring")
                    }
                    Text("Your Apple Watch quietly tracks posture in the background and haptic-nudges you when you slouch. Open Posture on your Watch to begin, and your phone keeps it in sync from there.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink2)

                    Toggle(isOn: airpodsBackgroundBinding) {
                        plusToggleLabel("Quiet AirPods background")
                    }
                    Text("Tracks head motion silently while AirPods are in. iOS shows an orange dot. That's Posture playing a silent tone to keep the AirPods sensor awake. No audio is recorded. This uses extra battery.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink2)

                    if subscriptions.isProSubscriber,
                       settings.airpodsBackgroundEnabled,
                       let monitor = airpodsMonitor {
                        AirpodsStatusChip(monitor: monitor)
                    }
                } header: {
                    Text("Posture+")
                }

                // MARK: - Live readout (free, in-app)

                if settings.hasAirpods == true {
                    Section("Live readout") {
                        Toggle("Show my posture while the app is open", isOn: $settings.inAppLiveEnabled)
                        Text("With AirPods in, the top of Today shows your alignment live, so you can glance at how you're sitting. It's just a readout: these minutes don't count toward your day report or trends. Reading stops when you leave the app.")
                            .font(Theme.font(.caption))
                            .foregroundStyle(Theme.ink2)
                    }
                }

                // MARK: - Daily practice
                // No-AirPods users live on the check-in loop; the practice
                // reminder would dead-end for them, so hide the section.

                if settings.hasAirpods == true {
                    Section("Daily practice") {
                        Toggle("Practice reminder", isOn: $settings.practiceReminderEnabled)
                            .onChange(of: settings.practiceReminderEnabled) { _, _ in
                                Task {
                                    await ReminderScheduler.reschedule()
                                    await refreshNotificationStatus()
                                }
                            }
                        if settings.practiceReminderEnabled {
                            DatePicker(
                                "Remind me at",
                                selection: practiceReminderTime,
                                displayedComponents: .hourAndMinute
                            )
                        }
                        Text("One reminder a day for your posture practice, a few minutes held tall with live AirPods coaching. Finishing it keeps your streak.")
                            .font(Theme.font(.caption))
                            .foregroundStyle(Theme.ink2)
                    }
                }

                // MARK: - Extra check-in nudges (secondary)

                Section("Extra check-in nudges") {
                    Toggle("Nudge me throughout the day", isOn: $settings.reminderEnabled)
                        .onChange(of: settings.reminderEnabled) { _, _ in
                            Task {
                                await ReminderScheduler.reschedule()
                                await refreshNotificationStatus()
                            }
                        }

                    if (settings.reminderEnabled || settings.practiceReminderEnabled) && notificationsDenied {
                        PostureBanner(
                            tone: .warn,
                            title: "Notifications are off.",
                            message: "Reminders won't fire until you allow notifications.",
                            action: ("allow", { Task { await allowNotifications() } })
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowBackground(Color.clear)
                    }

                    if settings.reminderEnabled {
                        Picker("Every", selection: $settings.reminderIntervalMinutes) {
                            ForEach(intervalOptions, id: \.self) { minutes in
                                Text("\(minutes) minutes").tag(minutes)
                            }
                        }
                        .onChange(of: settings.reminderIntervalMinutes) { _, _ in
                            Task { await ReminderScheduler.reschedule() }
                        }

                        Stepper("Start at \(settings.activeHoursStart):00",
                                value: $settings.activeHoursStart, in: 6...settings.activeHoursEnd - 1)
                            .onChange(of: settings.activeHoursStart) { _, _ in
                                Task { await ReminderScheduler.reschedule() }
                            }

                        Stepper("End at \(settings.activeHoursEnd):00",
                                value: $settings.activeHoursEnd, in: settings.activeHoursStart + 1...23)
                            .onChange(of: settings.activeHoursEnd) { _, _ in
                                Task { await ReminderScheduler.reschedule() }
                            }
                    }
                }

                // MARK: - Sensitivity

                Section("Sensitivity") {
                    Picker("Sensitivity", selection: $settings.sensitivity) {
                        Text("Relaxed").tag(0)
                        Text("Normal").tag(1)
                        Text("Strict").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Text("Relaxed forgives small forward head tilt. Strict flags it sooner.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink2)
                }

                // MARK: - Calibration

                Section("Calibration") {
                    // Don't clear the old calibration here - if the user
                    // cancels the sheet they'd be left scoring against a
                    // zero baseline. A completed capture supersedes the old
                    // row anyway (`current()` returns the newest).
                    Button("Recalibrate") {
                        showingQuickRecalibrate = true
                    }
                    .foregroundStyle(Theme.goodText)

                    if hasWalkBaseline {
                        Button("Reset walking posture") {
                            showingWalkBaselineReset = true
                        }
                        .foregroundStyle(Theme.ink)
                        Text("Forgets your saved walking posture. Your next walk runs the 30-second walking setup again.")
                            .font(Theme.font(.caption))
                            .foregroundStyle(Theme.ink2)
                    }
                }

                // MARK: - Help

                Section("Help") {
                    Button {
                        // Reset the one-shot, then let Today open a session -
                        // the coach marks run on the next live hold.
                        settings.hasSeenSessionCoachMarks = false
                        NotificationCenter.default.post(name: .postureReplaySessionCoachMarks, object: nil)
                    } label: {
                        Label("Replay practice coach marks", systemImage: "sparkles")
                    }
                    .foregroundStyle(Theme.ink)

                    Button {
                        ReviewPromptCoordinator.shared.requestEnjoymentPrompt()
                    } label: {
                        Label("Rate or Send Feedback", systemImage: "star.bubble")
                    }
                    .foregroundStyle(Theme.ink)

                    Link(destination: URL(string: "https://jackwallner.github.io/posture/support.html")!) {
                        Label("Support", systemImage: "questionmark.circle")
                    }

                    Link(destination: PaywallLinks.privacyPolicy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                // MARK: - About

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                }
            }
            // Form controls (Toggle/Picker/Stepper/LabeledContent labels) render
            // in system SF by default, clashing with the Nunito captions. Set the
            // Form's environment font so every unstyled label inherits Nunito;
            // explicit `Theme.font(...)` on the captions still overrides this.
            .font(Theme.font(.body))
            .scrollContentBackground(.hidden)
            .dawnBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshNotificationStatus()
                refreshWalkBaseline()
            }
            .onChange(of: subscriptions.isProSubscriber) { _, isPro in
                if isPro { applyPendingFeatureEnable() }
            }
            .sheet(isPresented: $showTrialOffer, onDismiss: {
                trialPurchaseInFlight = false
                trialPurchaseError = nil
                #if HAS_REVENUECAT
                trialOfferPackage = nil
                #endif
                if pendingPaywallAfterTrialDismiss {
                    pendingPaywallAfterTrialDismiss = false
                    showTrialPaywall = true
                } else if !subscriptions.isProSubscriber {
                    pendingFeatureEnable = nil
                }
            }) {
                TrialOfferSheet(
                    focus: trialOfferFocus,
                    offerLabel: trialOfferIntroLabel,
                    priceLabel: trialOfferPriceLabel,
                    directPurchase: trialOfferIsDirect,
                    isPurchasing: trialPurchaseInFlight,
                    errorMessage: trialPurchaseError,
                    onStartTrial: {
                        if trialOfferIsDirect {
                            startDirectTrialPurchase()
                        } else {
                            pendingPaywallAfterTrialDismiss = true
                            showTrialOffer = false
                        }
                    },
                    onSeeAllPlans: {
                        pendingPaywallAfterTrialDismiss = true
                        showTrialOffer = false
                    },
                    onDismiss: { showTrialOffer = false }
                )
                .presentationDetents([.fraction(0.68), .large], selection: $trialOfferDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(trialPurchaseInFlight)
            }
            .sheet(isPresented: $showTrialPaywall, onDismiss: {
                trialOfferFocus = nil
                if !subscriptions.isProSubscriber { pendingFeatureEnable = nil }
            }) {
                PaywallView(paywallImpressionId: paywallImpressionId)
            }
            .alert("Open Posture on your Watch", isPresented: $showingWatchSyncInfo) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("Open Posture on your Apple Watch once to start background tracking. Your phone has already sent the setting over.")
            }
            .alert("Turn on quiet background?", isPresented: $showingAirpodsBackgroundConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Turn on") { settings.airpodsBackgroundEnabled = true }
            } message: {
                Text("Posture will play a silent tone to keep the AirPods sensor awake. iOS shows an orange dot in the status bar to let you know audio is in use. No audio is recorded. Always-on tracking uses extra battery.")
            }
            .sheet(isPresented: $showingQuickRecalibrate, onDismiss: { refreshWalkBaseline() }) {
                CalibrationView(mode: .quickRecalibrate)
            }
            .alert("Reset walking posture?", isPresented: $showingWalkBaselineReset) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    CalibrationService(context: context).clearWalkingBaseline()
                    refreshWalkBaseline()
                }
            } message: {
                Text("Your next walk starts with the 30-second walking setup, so walks are scored against a fresh baseline.")
            }
        }
    }

    private func refreshWalkBaseline() {
        hasWalkBaseline = CalibrationService(context: context).current()?.airpodsWalkingPitch != nil
    }

    @ViewBuilder
    private func plusToggleLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            if !subscriptions.isProSubscriber {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
    }

    private var alwaysOnBinding: Binding<Bool> {
        Binding(
            get: { subscriptions.isProSubscriber && settings.alwaysOnEnabled },
            set: { enabled in
                if subscriptions.isProSubscriber {
                    settings.alwaysOnEnabled = enabled
                    WatchSyncService.shared.pushAlwaysOn(enabled)
                    if enabled { showingWatchSyncInfo = true }
                } else if enabled {
                    requestTrialOffer(for: .alwaysOnWatch)
                }
            }
        )
    }

    private var airpodsBackgroundBinding: Binding<Bool> {
        Binding(
            get: { subscriptions.isProSubscriber && settings.airpodsBackgroundEnabled },
            set: { enabled in
                if subscriptions.isProSubscriber {
                    if enabled && !settings.airpodsBackgroundEnabled {
                        showingAirpodsBackgroundConfirm = true
                    } else {
                        settings.airpodsBackgroundEnabled = enabled
                    }
                } else if enabled {
                    requestTrialOffer(for: .airpodsBackground)
                }
            }
        )
    }

    #if HAS_REVENUECAT
    private var hasTrialOffer: Bool {
        subscriptions.products.contains { subscriptions.isEligibleForIntroOffer($0) }
    }

    private var directTrialPackage: Package? {
        let trialPackages = subscriptions.products.filter { subscriptions.isEligibleForIntroOffer($0) }
        return trialPackages.first { $0.posturePackageKind == .yearly } ?? trialPackages.first
    }

    private var trialOfferIsDirect: Bool {
        directTrialPackage != nil
    }

    private var trialOfferIntroLabel: String? {
        trialOfferPackage?.postureIntroOfferLabel
            ?? subscriptions.products.compactMap(\.postureIntroOfferLabel).first
    }

    private var trialOfferPriceLabel: String? {
        trialOfferPackage?.posturePriceLabel ?? directTrialPackage?.posturePriceLabel
    }
    #else
    private var trialOfferIsDirect: Bool { false }
    private var trialOfferIntroLabel: String? { nil }
    private var trialOfferPriceLabel: String? { nil }
    #endif

    private func requestTrialOffer(for feature: PosturePlusFeature) {
        guard !subscriptions.isProSubscriber else { return }
        pendingFeatureEnable = feature
        trialOfferFocus = feature
        paywallImpressionId = feature.paywallImpressionId
        trialOfferDetent = .fraction(0.68)
        #if HAS_REVENUECAT
        if hasTrialOffer {
            trialOfferPackage = directTrialPackage
            showTrialOffer = true
        } else {
            showTrialPaywall = true
        }
        #else
        showTrialPaywall = true
        #endif
    }

    private func startDirectTrialPurchase() {
        #if HAS_REVENUECAT
        guard let package = trialOfferPackage ?? directTrialPackage else {
            pendingPaywallAfterTrialDismiss = true
            showTrialOffer = false
            return
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = true
        Task { @MainActor in
            defer { trialPurchaseInFlight = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased, .pending:
                    showTrialOffer = false
                case .cancelled:
                    trialPurchaseError = "Trial wasn't started. Tap again, or pick a different plan."
                }
            } catch {
                trialPurchaseError = "Couldn't start your trial. Please try again."
            }
        }
        #endif
    }

    private func applyPendingFeatureEnable() {
        guard let feature = pendingFeatureEnable else { return }
        pendingFeatureEnable = nil
        switch feature {
        case .alwaysOnWatch:
            settings.alwaysOnEnabled = true
            WatchSyncService.shared.pushAlwaysOn(true)
            showingWatchSyncInfo = true
        case .airpodsBackground:
            showingAirpodsBackgroundConfirm = true
        case .walkMode:
            // Walk mode gates from Today, not Settings; nothing to toggle here.
            break
        }
    }

    /// Bridge the stored hour/minute to the DatePicker's Date binding.
    private var practiceReminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.practiceReminderHour,
                    minute: settings.practiceReminderMinute,
                    second: 0, of: .now
                ) ?? .now
            },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                settings.practiceReminderHour = parts.hour ?? 10
                settings.practiceReminderMinute = parts.minute ?? 0
            }
        )
    }

    private func refreshNotificationStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notificationsDenied = s.authorizationStatus == .denied
    }

    private func allowNotifications() async {
        let granted = await NotificationService.requestAuthorization()
        if granted {
            await ReminderScheduler.reschedule()
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url)
        }
        await refreshNotificationStatus()
    }
}

// MARK: - AirPods status chip

private struct AirpodsStatusChip: View {
    let monitor: AirpodsBackgroundMonitor

    private enum State { case live, armed, off }
    private var state: State {
        if !monitor.isMonitoring { return .off }
        return monitor.isConnected ? .live : .armed
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(label)
                .font(Theme.font(.caption, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(background, in: .capsule)
    }

    private var label: String {
        switch state {
        case .live: return "Live · AirPods linked"
        case .armed: return "Ready · waiting for AirPods"
        case .off: return "Monitoring off"
        }
    }
    private var dotColor: Color {
        switch state {
        case .live: return Theme.sage
        case .armed: return Theme.sand
        case .off: return Theme.ink3
        }
    }
    private var textColor: Color {
        switch state {
        case .live: return Theme.sage
        case .armed, .off: return Theme.ink2
        }
    }
    private var background: Color {
        switch state {
        case .live: return Theme.sageTint
        case .armed: return Theme.sandTint
        case .off: return Theme.paper3
        }
    }
}

