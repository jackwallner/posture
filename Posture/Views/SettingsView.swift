import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?

    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var showingRecalibrateSheet = false
    @State private var showingQuickRecalibrate = false
    @State private var notificationsDenied = false

    private let intervalOptions = [15, 30, 60]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: - Pro

                Section {
                    if subscriptions.isProSubscriber {
                        Toggle("Always-on Watch monitoring", isOn: $settings.alwaysOnEnabled)
                        Text("Your Apple Watch quietly tracks posture in the background and haptic-nudges you when you slouch. Enable it from the Watch app.")
                            .font(.caption)
                            .foregroundStyle(Theme.ink2)

                        Toggle("Quiet AirPods background", isOn: $settings.airpodsBackgroundEnabled)
                        Text("Tracks head motion silently while AirPods are in. iOS shows an orange dot when this is on — that's Posture listening to silence so it can feel your slouch.")
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
                    Text("posture · pro")
                }

                // MARK: - Reminders

                Section("reminders") {
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

                Section("sensitivity") {
                    Picker("Sensitivity", selection: $settings.sensitivity) {
                        Text("Relaxed").tag(0)
                        Text("Normal").tag(1)
                        Text("Strict").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - Calibration

                Section("calibration") {
                    Button("Recalibrate") { showingRecalibrateSheet = true }
                        .foregroundStyle(Theme.sage)
                }

                // MARK: - About

                Section("about") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshNotificationStatus() }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
            .sheet(isPresented: $showingQuickRecalibrate) {
                CalibrationView(mode: .quickRecalibrate)
            }
            .sheet(isPresented: $showingRecalibrateSheet) {
                RecalibrationOptionsView(
                    onQuick: {
                        CalibrationService(context: context).clear()
                        showingRecalibrateSheet = false
                        showingQuickRecalibrate = true
                    },
                    onFull: {
                        CalibrationService(context: context).clear()
                        settings.hasCalibrated = false
                        showingRecalibrateSheet = false
                    },
                    onCancel: { showingRecalibrateSheet = false }
                )
                .presentationDetents([.height(280)])
            }
        }
    }

    private var proPostcard: some View {
        Button { showingPaywall = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("POSTURE · PRO")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.sage)
                Text("Keep the whole year.\nSee your slouch hours.")
                    .font(Theme.displaySerif(22))
                    .foregroundStyle(Theme.ink)
                Text("try 7 days · $29.99/yr →")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.sageTint, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
        case .live: return "live · airpods linked"
        case .armed: return "ready · waiting for airpods"
        case .off: return "monitoring off"
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

// MARK: - Recalibration options sheet

private struct RecalibrationOptionsView: View {
    let onQuick: () -> Void
    let onFull: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recalibrate")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Quick recaptures your baseline in five seconds. Full walks through setup again.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)

            Button { onQuick() } label: { Text("quick — 5 seconds") }
                .buttonStyle(.plain)
                .daylightCTA(.secondary)
            Button { onFull() } label: { Text("full — start over") }
                .buttonStyle(.plain)
                .daylightCTA(.secondary)
            Button { onCancel() } label: { Text("cancel") }
                .buttonStyle(.plain)
                .daylightCTA(.ghost)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.paper.ignoresSafeArea())
    }
}
