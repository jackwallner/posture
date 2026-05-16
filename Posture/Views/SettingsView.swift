import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var showingRecalibrate = false
    @State private var showingQuickRecalibrate = false

    private let intervalOptions = [15, 30, 60]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: - Pro Section

                Section {
                    if subscriptions.isProSubscriber {
                        Toggle("Always-on Watch monitoring", isOn: $settings.alwaysOnEnabled)
                        Text("Your Apple Watch will quietly track posture in the background and haptic-nudge you when you slouch.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Toggle("AirPods background monitoring", isOn: $settings.airpodsBackgroundEnabled)
                        Text("When AirPods are in, tracks head motion silently in the background with haptic feedback when you slouch.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        if settings.airpodsBackgroundEnabled {
                            AirpodsStatusView(monitor: airpodsMonitor)
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill").foregroundStyle(Theme.brandPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Posture Pro").font(.headline)
                                    Text("Always-on monitoring + AirPods background tracking").font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                } header: {
                    Text("Pro")
                }

                // MARK: - Reminders

                Section("Posture reminders") {
                    Toggle("Remind me throughout the day", isOn: $settings.reminderEnabled)
                        .onChange(of: settings.reminderEnabled) { _, _ in
                            Task { await ReminderScheduler.reschedule() }
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
                }

                // MARK: - Calibration

                Section("Calibration") {
                    Button("Recalibrate") {
                        showingRecalibrate = true
                    }
                    .foregroundStyle(Theme.brandPrimary)
                    .confirmationDialog("Recalibrate posture?", isPresented: $showingRecalibrate) {
                        Button("Quick — recapture baseline") {
                            CalibrationService(context: context).clear()
                            showingQuickRecalibrate = true
                        }
                        Button("Full — start over") {
                            CalibrationService(context: context).clear()
                            settings.hasCalibrated = false
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Quick recalibrate skips the AirPods question and goes straight to capture. Full recalibrate walks through the entire setup again.")
                    }
                }
                .sheet(isPresented: $showingQuickRecalibrate) {
                    CalibrationView(mode: .quickRecalibrate)
                }

                // MARK: - About

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - AirPods Status View

private struct AirpodsStatusView: View {
    let monitor: AirpodsBackgroundMonitor?

    var body: some View {
        Group {
            if let monitor {
                HStack {
                    Image(systemName: monitor.isConnected ? "airpodspro" : "airpodspro.badge.exclamationmark")
                        .foregroundStyle(monitor.isConnected ? Theme.good : Theme.textSecondary)
                    Text(monitor.isConnected ? "AirPods connected" : "AirPods not detected")
                        .font(.caption)
                    Spacer()
                    if monitor.isMonitoring {
                        if monitor.currentQuality != .good {
                            Circle()
                                .fill(Theme.qualityColor(monitor.currentQuality))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                if monitor.isMonitoring && !monitor.isConnected {
                    Text("Put on your AirPods to start passive monitoring.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
                if monitor.isMonitoring && monitor.isConnected {
                    Text("Orange audio indicator appears while monitoring — this is expected per Apple's background audio requirements.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Initializing…")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
