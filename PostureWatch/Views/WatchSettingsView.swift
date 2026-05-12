import SwiftData
import SwiftUI

struct WatchSettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var settings = GoalSettings.shared
    @State private var subscriptions = SubscriptionService.shared
    @State private var background = BackgroundPostureWorkout()

    var body: some View {
        Form {
            Section {
                if subscriptions.isProSubscriber {
                    Toggle("Always-on monitoring", isOn: Binding(
                        get: { settings.alwaysOnEnabled },
                        set: { newValue in
                            settings.alwaysOnEnabled = newValue
                            Task {
                                if newValue {
                                    let cal = CalibrationService(context: context).current()
                                        ?? Calibration(basePitch: 0, baseYaw: 0, baseRoll: 0, slouchPitchDelta: .pi / 6)
                                    _ = await background.requestAuthorization()
                                    await background.start(calibration: cal)
                                } else {
                                    background.stop()
                                }
                            }
                        }
                    ))
                    if background.isActive {
                        Label("Active", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.good)
                        Text("Slouch nudges today: \(background.totalSlouchEvents)")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    Label("Pro only", systemImage: "crown.fill")
                        .foregroundStyle(Theme.brandPrimary)
                    Text("Open Posture on iPhone to upgrade.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            } header: {
                Text("Background")
            }
        }
        .navigationTitle("Settings")
    }
}
