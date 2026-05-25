import SwiftData
import SwiftUI
import UserNotifications

/// Full-screen check-in shown after a posture reminder tap (or manually
/// from TodayView). Daylight: one decision, always an escape hatch, a
/// reward moment that observes rather than scolds.
struct AcknowledgmentView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// The time this reminder was scheduled for. Defaults to .now for manual check-ins.
    let scheduledAt: Date

    /// Optional — notification index, so we can clear the delivered notification.
    let notificationIndex: Int?

    @State private var phase: Phase = .choice
    @State private var recordedQuality: PostureQuality?
    @State private var currentTip: PostureTip?
    @State private var forcedCamera = false
    @State private var earnedReviewPositiveMoment = false

    enum Phase { case choice, scanning, done }

    /// True when the user calibrated with AirPods — prefer the motion-based
    /// scan unless the user explicitly opted into the camera this time.
    private var preferAirpods: Bool {
        guard !forcedCamera else { return false }
        let cal = CalibrationService(context: context).current()
        return cal?.airpodsPitch != nil
    }

    /// A camera scan is meaningful only when the saved calibration captured
    /// a real camera baseline. AirPods-only calibrations leave basePitch
    /// at 0, which would produce garbage deviation in QuickScanView.
    private var hasCameraBaseline: Bool {
        let cal = CalibrationService(context: context).current()
        return (cal?.basePitch ?? 0) != 0
    }

    var body: some View {
        Group {
            switch phase {
            case .choice: choiceView
            case .scanning: scanningView
            case .done: doneView
            }
        }
        .onAppear {
            currentTip = PostureTipService.randomTip()
            if let idx = notificationIndex {
                UNUserNotificationCenter.current().removeDeliveredNotifications(
                    withIdentifiers: ["posture.reminder.\(idx)"]
                )
            }
        }
        .onDisappear {
            guard earnedReviewPositiveMoment else { return }
            ReviewPromptTracker.recordPositiveMoment()
            NotificationCenter.default.post(name: .posturePositiveMomentForReview, object: nil)
        }
    }

    // MARK: - Choice

    private var choiceView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow(scheduledAt))
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                closeButton
            }
            .padding(.top, 12)
            .padding(.bottom, 40)

            Text("how's your posture\nright now?")
                .font(Theme.displaySerif(42))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)

            Text("A three-second scan. Or just tell us — we trust you.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 14)

            Spacer()

            Button {
                phase = .scanning
            } label: {
                Text("scan")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)

            VStack(spacing: 4) {
                Button {
                    recordAcknowledgment(method: .manual, quality: nil)
                    recordedQuality = nil
                    withAnimation { phase = .done }
                } label: {
                    Text("just checking in — manual →")
                }
                .buttonStyle(.plain)
                .daylightCTA(.ghost)
                Text("Counts for your streak. Alignment score needs a quick scan.")
                    .font(.caption)
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dawnBackground()
    }

    // MARK: - Scanning

    @ViewBuilder
    private var scanningView: some View {
        if preferAirpods {
            AirpodsScanView(
                scheduledAt: scheduledAt,
                cameraScanAvailable: hasCameraBaseline,
                onComplete: { quality in
                    recordedQuality = quality
                    recordAcknowledgment(method: .airpods, quality: quality)
                    withAnimation { phase = .done }
                },
                onUseCamera: {
                    forcedCamera = true
                },
                onFallback: {
                    recordedQuality = nil
                    recordAcknowledgment(method: .manual, quality: nil)
                    withAnimation { phase = .done }
                },
                onClose: { dismiss() }
            )
        } else {
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
                },
                onClose: { dismiss() }
            )
        }
    }

    // MARK: - Done

    private var doneView: some View {
        ZStack {
            tintForDone.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Spacer()
                    closeButton
                }
                Spacer()
                VStack(alignment: .leading, spacing: 14) {
                    Text(doneEyebrow)
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(resultColor)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(resultWord)
                            .font(Theme.displaySerif(64))
                            .foregroundStyle(Theme.ink)
                        Text(".")
                            .font(Theme.displaySerif(64))
                            .foregroundStyle(resultColor)
                    }
                    Text(resultSubtitle)
                        .font(.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HorizonMeter(quality: recordedQuality)
                    .frame(height: 48)
                    .padding(.vertical, 8)
                if let tip = currentTip {
                    TipLine(tip: tip)
                }
                Spacer()
                Button { dismiss() } label: { Text("done") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: - Result copy

    private var resultWord: String {
        switch recordedQuality {
        case .good: return "aligned"
        case .borderline: return "drifting"
        case .bad: return "resting"
        case nil: return "noted"
        }
    }

    private var resultColor: Color {
        switch recordedQuality {
        case .good: return Theme.sage
        case .borderline: return Theme.sand
        case .bad: return Theme.clay
        case nil: return Theme.ink3
        }
    }

    private var tintForDone: Color {
        switch recordedQuality {
        case .good: return Theme.sageTint
        case .borderline: return Theme.sandTint
        case .bad: return Theme.clayTint
        case nil: return Theme.paper2
        }
    }

    private var resultSubtitle: String {
        switch recordedQuality {
        case .good:
            return "Crown over hips. Shoulders soft. You're holding the shape well."
        case .borderline:
            return "Head's a little forward. A small reset is all this needs."
        case .bad:
            return "Curled forward. Take a slow breath, lift the crown of your head."
        case nil:
            return "Logged without a scan. Counts for your streak; alignment score updates only on scanned check-ins."
        }
    }

    private var doneEyebrow: String {
        recordedQuality == nil ? "noted" : "\(timeString(scheduledAt)) · scanned"
    }

    private func eyebrow(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · h:mm a"
        return f.string(from: date).lowercased()
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date).lowercased()
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

        let streakService = StreakService(context: context)
        let streakBefore = streakService.currentState().currentStreak
        let state = streakService.recordAcknowledgment(at: .now)

        if quality == .good {
            earnedReviewPositiveMoment = true
        } else if state.currentStreak > streakBefore,
                  StreakService.streakMilestoneDays.contains(state.currentStreak) {
            earnedReviewPositiveMoment = true
        }

        AnalyticsService.acknowledgmentRecorded(method: method, quality: quality)
    }
}
