import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?

    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var showingQuickRecalibrate = false
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
                    if subscriptions.isProSubscriber {
                        Toggle("Always-on Watch monitoring", isOn: $settings.alwaysOnEnabled)
                            .onChange(of: settings.alwaysOnEnabled) { _, isOn in
                                WatchSyncService.shared.pushAlwaysOn(isOn)
                                if isOn { showingWatchSyncInfo = true }
                            }
                        Text("Your Apple Watch quietly tracks posture in the background and haptic-nudges you when you slouch. Open Posture on your Watch to begin, and your phone keeps it in sync from there.")
                            .font(.caption)
                            .foregroundStyle(Theme.ink2)

                        Toggle("Quiet AirPods background", isOn: Binding(
                            get: { settings.airpodsBackgroundEnabled },
                            set: { newValue in
                                if newValue && !settings.airpodsBackgroundEnabled {
                                    // First-flip confirmation — explain the orange dot
                                    // before the silent tone (and the indicator) start.
                                    showingAirpodsBackgroundConfirm = true
                                } else {
                                    settings.airpodsBackgroundEnabled = newValue
                                }
                            }
                        ))
                        Text("Tracks head motion silently while AirPods are in. iOS shows an orange dot. That's Posture playing a silent tone to keep the AirPods sensor awake. No audio is recorded. This uses extra battery.")
                            .font(.caption)
                            .foregroundStyle(Theme.ink2)

                        if settings.airpodsBackgroundEnabled, let monitor = airpodsMonitor {
                            AirpodsStatusChip(monitor: monitor)
                        }
                    } else {
                        proPostcard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Posture+")
                }

                // MARK: - Reminders

                Section("Reminders") {
                    Toggle("Remind me throughout the day", isOn: $settings.reminderEnabled)
                        .onChange(of: settings.reminderEnabled) { _, _ in
                            Task {
                                await ReminderScheduler.reschedule()
                                await refreshNotificationStatus()
                            }
                        }

                    if settings.reminderEnabled && notificationsDenied {
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
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                }

                // MARK: - Calibration

                Section("Calibration") {
                    // Don't clear the old calibration here — if the user
                    // cancels the sheet they'd be left scoring against a
                    // zero baseline. A completed capture supersedes the old
                    // row anyway (`current()` returns the newest).
                    Button("Recalibrate") {
                        showingQuickRecalibrate = true
                    }
                    .foregroundStyle(Theme.sage)
                }

                // MARK: - Help

                Section("Help") {
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
            .scrollContentBackground(.hidden)
            .dawnBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshNotificationStatus() }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "posture_settings_sheet")
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
            .sheet(isPresented: $showingQuickRecalibrate) {
                CalibrationView(mode: .quickRecalibrate)
            }
        }
    }

    private var proPostcard: some View {
        Button { showingPaywall = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("POSTURE+")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.sage)
                Text("Keep the whole year.\nSee your slouch hours.")
                    .font(Theme.displaySerif(22))
                    .foregroundStyle(Theme.ink)
                Text(proPostcardPriceLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.sageTint, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    /// Price line for the Posture+ postcard, read from the loaded store
    /// products so the copy is right in every storefront currency and only
    /// promises a trial to users who are actually eligible. Hardcoding
    /// "$29.99/yr" here showed USD to everyone.
    private var proPostcardPriceLine: String {
        #if HAS_REVENUECAT
        if let yearly = subscriptions.products.first(where: { $0.posturePackageKind == .yearly }) {
            if subscriptions.isEligibleForIntroOffer(yearly), let trial = yearly.postureIntroOfferLabel {
                return "\(trial) · \(yearly.posturePriceLabel) →"
            }
            return "\(yearly.posturePriceLabel) →"
        }
        #endif
        return "see plans →"
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
                .font(.caption.weight(.semibold))
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

