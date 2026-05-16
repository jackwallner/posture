import SwiftData
import SwiftUI
import UserNotifications

/// Full-screen view shown after a posture reminder notification tap
/// (or manually from TodayView). Offers a quick camera scan or a
/// manual acknowledgment, then records it and displays a posture tip.
struct AcknowledgmentView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// The time this reminder was scheduled for. Defaults to .now for manual check-ins.
    let scheduledAt: Date

    /// Optional — if this was triggered by a notification tap, the notification's index
    /// so we can remove it from the delivered list.
    let notificationIndex: Int?

    @State private var phase: Phase = .choice
    @State private var recordedQuality: PostureQuality?
    @State private var currentTip: PostureTip?

    enum Phase {
        case choice
        case scanning
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .choice:
                choiceView
            case .scanning:
                scanningView
            case .done:
                doneView
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            currentTip = PostureTipService.randomTip()
            // Remove the delivered notification if triggered by one
            if let idx = notificationIndex {
                UNUserNotificationCenter.current().removeDeliveredNotifications(
                    withIdentifiers: ["posture.reminder.\(idx)"]
                )
            }
        }
    }

    // MARK: - Choice View

    private var choiceView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.stand")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.brandGradient)

            Text("Time to check in")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("How's your posture right now?")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    phase = .scanning
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Scan")
                                .font(.headline)
                            Text("Uses front camera — 3 seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
                }

                Button {
                    recordAcknowledgment(method: .manual, quality: nil)
                    withAnimation { phase = .done }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I Sat Up Straight")
                                .font(.headline)
                            Text("Manual check — no camera")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Theme.cardSurface, in: .rect(cornerRadius: 14))
                    .foregroundStyle(Theme.textPrimary)
                }

                if let idx = notificationIndex, idx > 0 {
                    Button {
                        dismiss()
                    } label: {
                        Text("Dismiss")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 20) {
            Text("Checking your posture")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 24)

            QuickScanView(
                scheduledAt: scheduledAt,
                onComplete: { quality in
                    recordedQuality = quality
                    recordAcknowledgment(method: .camera, quality: quality)
                    withAnimation { phase = .done }
                },
                onFallback: {
                    recordedQuality = nil
                    recordAcknowledgment(method: .manual, quality: nil)
                    withAnimation { phase = .done }
                }
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Done View

    private var doneView: some View {
        VStack(spacing: 24) {
            let icon = recordedQuality.map { q -> (String, Color) in
                switch q {
                case .good: return ("checkmark.circle.fill", Theme.good)
                case .borderline: return ("exclamationmark.triangle.fill", Theme.borderline)
                case .bad: return ("xmark.octagon.fill", Theme.bad)
                }
            } ?? ("hand.wave.fill", Theme.brandPrimary)

            Image(systemName: icon.0)
                .font(.system(size: 72))
                .foregroundStyle(icon.1)

            VStack(spacing: 8) {
                if let quality = recordedQuality {
                    switch quality {
                    case .good:
                        Text("Looking good!")
                            .font(.title.bold())
                        Text("Your posture is on track.")
                            .foregroundStyle(Theme.textSecondary)
                    case .borderline:
                        Text("Shift back a bit")
                            .font(.title.bold())
                        Text("You're close but slightly forward.")
                            .foregroundStyle(Theme.textSecondary)
                    case .bad:
                        Text("Straighten up")
                            .font(.title.bold())
                        Text("Sit tall with your shoulders back.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    Text("Checked in!")
                        .font(.title.bold())
                    Text("Good job staying mindful.")
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Posture tip
            if let tip = currentTip {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Theme.borderline)
                        Text("Tip")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(tip.text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.cardPadding)
                .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
                .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Recording

    private func recordAcknowledgment(method: AcknowledgmentMethod, quality: PostureQuality?) {
        let record = AcknowledgmentRecord(
            method: method,
            quality: quality,
            scheduledAt: scheduledAt
        )
        context.insert(record)
        try? context.save()

        StreakService(context: context).recordAcknowledgment(at: .now)

        AnalyticsService.acknowledgmentRecorded(method: method, quality: quality)
    }
}


