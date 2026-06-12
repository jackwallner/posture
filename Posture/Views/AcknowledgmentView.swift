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
    @State private var recordedMethod: AcknowledgmentMethod?
    @State private var currentTip: PostureTip?
    @State private var earnedReviewPositiveMoment = false
    @State private var todayCheckInCount = 0
    @State private var streakAfterRecord = 0

    enum Phase { case choice, scanning, done }

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

            Text("A three-second scan with your AirPods. Or just tell us — we trust you.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 14)

            Spacer()

            Button {
                phase = .scanning
            } label: {
                Text("scan with AirPods")
            }
            .buttonStyle(.daylight(.primary))

            // Manual self-report — works without AirPods and still records a
            // real posture quality, so the alignment score and history fill in.
            VStack(spacing: 8) {
                Text("or tell us how you're sitting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 10) {
                    selfReportChip(label: "aligned", quality: .good, tint: Theme.sageTint, accent: Theme.sage)
                    selfReportChip(label: "drifting", quality: .borderline, tint: Theme.sandTint, accent: Theme.sand)
                    selfReportChip(label: "resting", quality: .bad, tint: Theme.clayTint, accent: Theme.clay)
                }
                Button {
                    recordManual(quality: nil)
                } label: {
                    Text("just log it →")
                        .font(.caption)
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dawnBackground()
    }

    private func selfReportChip(label: String, quality: PostureQuality, tint: Color, accent: Color) -> some View {
        Button {
            recordManual(quality: quality)
        } label: {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("I'm sitting \(label)")
    }

    private func recordManual(quality: PostureQuality?) {
        recordedQuality = quality
        recordAcknowledgment(method: .manual, quality: quality)
        withAnimation { phase = .done }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        AirpodsScanView(
            scheduledAt: scheduledAt,
            onComplete: { quality in
                recordedQuality = quality
                recordAcknowledgment(method: .airpods, quality: quality)
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
                    // The receipt — what this check-in just added, so a
                    // three-second ritual never feels like it vanished.
                    if todayCheckInCount > 0 {
                        Text(tallyLine)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink3)
                            .padding(.top, 2)
                    }
                }
                HorizonMeter(quality: recordedQuality)
                    .frame(height: 48)
                    .padding(.vertical, 8)
                if let tip = currentTip {
                    TipLine(tip: tip)
                }
                Spacer()
                Button { dismiss() } label: { Text("done") }
                    .buttonStyle(.daylight(.ghost))
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
            return "Logged for your streak. Next time, tell us how you're sitting or scan to add a score."
        }
    }

    private var tallyLine: String {
        let count = todayCheckInCount == 1
            ? "your first check-in today"
            : "\(todayCheckInCount) check-ins today"
        guard streakAfterRecord > 0 else { return count }
        return "\(count) · day \(streakAfterRecord) of your streak"
    }

    private var doneEyebrow: String {
        guard recordedQuality != nil else { return "noted" }
        let verb = recordedMethod == .airpods ? "scanned" : "logged"
        return "\(timeString(scheduledAt)) · \(verb)"
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
        recordedMethod = method
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
        streakAfterRecord = state.currentStreak

        let todayStart = DateHelpers.startOfDay()
        let todayDescriptor = FetchDescriptor<AcknowledgmentRecord>(
            predicate: #Predicate { $0.timestamp >= todayStart }
        )
        todayCheckInCount = (try? context.fetchCount(todayDescriptor)) ?? 0

        if quality == .good {
            earnedReviewPositiveMoment = true
        } else if state.currentStreak > streakBefore,
                  StreakService.streakMilestoneDays.contains(state.currentStreak) {
            earnedReviewPositiveMoment = true
        }

        AnalyticsService.acknowledgmentRecorded(method: method, quality: quality)
    }
}
