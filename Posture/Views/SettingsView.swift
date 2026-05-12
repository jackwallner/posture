import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var notificationsAuthorized: Bool = false
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    if subscriptions.isProSubscriber {
                        Toggle("Always-on Watch monitoring", isOn: $settings.alwaysOnEnabled)
                        Text("Your Apple Watch will quietly track posture in the background and haptic-nudge you when you slouch.")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill").foregroundStyle(Theme.brandPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Posture Pro").font(.headline)
                                    Text("Always-on Watch monitoring + photo analysis").font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                } header: {
                    Text("Pro")
                }

                Section("Daily reminder") {
                    Toggle("Remind me each day", isOn: $settings.dailyReminderEnabled)
                    if settings.dailyReminderEnabled {
                        Stepper("At \(settings.dailyReminderHour):00", value: $settings.dailyReminderHour, in: 5...22)
                    }
                }

                Section("Sensitivity") {
                    Picker("Sensitivity", selection: $settings.sensitivity) {
                        Text("Relaxed").tag(0)
                        Text("Normal").tag(1)
                        Text("Strict").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Calibration") {
                    Button("Recalibrate") {
                        CalibrationService(context: context).clear()
                        settings.hasCalibrated = false
                    }
                    .foregroundStyle(Theme.brandPrimary)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: settings.dailyReminderEnabled) { _, enabled in
                Task { await applyReminderSettings(enabled: enabled, hour: settings.dailyReminderHour) }
            }
            .onChange(of: settings.dailyReminderHour) { _, hour in
                Task { await applyReminderSettings(enabled: settings.dailyReminderEnabled, hour: hour) }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private func applyReminderSettings(enabled: Bool, hour: Int) async {
        if enabled {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleDailyReminder(hour: hour)
        } else {
            await NotificationService.cancelDailyReminder()
        }
    }
}
