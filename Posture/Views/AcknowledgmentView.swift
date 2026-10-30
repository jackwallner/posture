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

    /// Optional - notification index, so we can clear the delivered notification.
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
            // AirPods owners get an objective scan as the check-in - no
            // self-report. Manual self-report is the no-AirPods mode only.
            if settings.hasAirpods == true, phase == .choice {
                phase = .scanning
            }
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
        fillingScroll {
            choiceContent
        }
        .dawnBackground()
    }

    private var choiceContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow(scheduledAt))
                    .font(Theme.font(.caption, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                closeButton
            }
            .padding(.top, 12)
            .padding(.bottom, 40)

            Text("How's your posture\nright now?")
                .font(Theme.display(42))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Sit tall, then tell us how you're holding it. Your check-in keeps your streak alive.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            checkInMotivationCard
                .padding(.top, 28)

            Spacer()

            // No AirPods, so self-report is the check-in. AirPods owners never
            // see this screen; their check-in is an objective scan.
            HStack(spacing: 10) {
                selfReportChip(label: String(localized: "Aligned"), quality: .good, tint: Theme.sageTint, accent: Theme.sage)
                selfReportChip(label: String(localized: "Drifting"), quality: .borderline, tint: Theme.sandTint, accent: Theme.sand)
                selfReportChip(label: String(localized: "Slouching"), quality: .bad, tint: Theme.clayTint, accent: Theme.clay)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    private func selfReportChip(label: String, quality: PostureQuality, tint: Color, accent: Color) -> some View {
        Button {
            recordManual(quality: quality)
        } label: {
            Text(label)
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selfReportAccessibilityLabel(quality))
    }

    private func selfReportAccessibilityLabel(_ quality: PostureQuality) -> String {
        switch quality {
        case .good: return String(localized: "I'm sitting aligned")
        case .borderline: return String(localized: "I'm sitting drifting")
        case .bad: return String(localized: "I'm sitting slouching")
        }
    }

    private var checkInMotivationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.streakFlame)
                .frame(width: 32, height: 32)
                .background(Theme.sandTint, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("A tiny reset counts.")
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("One honest check-in protects today's streak and helps the pattern show up over time.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .dawnCard(cornerRadius: 16)
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
            fillingScroll {
                doneContent
            }
        }
    }

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Spacer()
                closeButton
            }
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text(doneEyebrow)
                    .font(Theme.font(.caption, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(resultColor)
                // One Text so large sizes shrink the word whole, never break it.
                Text("\(Text(resultWord).foregroundStyle(Theme.ink))\(Text(".").foregroundStyle(resultColor))")
                    .font(Theme.display(64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(resultSubtitle)
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                // The receipt - what this check-in just added, so a
                // three-second ritual never feels like it vanished.
                if todayCheckInCount > 0 {
                    Text(tallyLine)
                        .font(Theme.font(.footnote, weight: .semibold))
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
            Button { dismiss() } label: { Text("Done") }
                .buttonStyle(.daylight(.ghost))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }

    // MARK: - Chrome

    /// Fills the screen so the Spacers still push the actions down, and
    /// scrolls once large text makes the content taller than the screen.
    private func fillingScroll<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let content = content()
        return GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(Theme.font(.body, weight: .medium))
                .foregroundStyle(Theme.ink3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    // MARK: - Result copy

    private var resultWord: String {
        switch recordedQuality {
        case .good: return String(localized: "Aligned")
        case .borderline: return String(localized: "Drifting")
        case .bad: return String(localized: "Slouching")
        case nil: return String(localized: "Noted")
        }
    }

    private var resultColor: Color {
        guard let recordedQuality else { return Theme.ink3 }
        return Theme.qualityTextColor(recordedQuality)
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
            return String(localized: "Crown over hips. Shoulders soft. You're holding the shape well.")
        case .borderline:
            return String(localized: "Head's a little forward. A small reset is all this needs.")
        case .bad:
            return String(localized: "Curled forward. Take a slow breath, lift the crown of your head.")
        case nil:
            return String(localized: "Logged for your streak. Next time, tell us how you're sitting or scan to add a score.")
        }
    }

    private var tallyLine: String {
        let count = todayCheckInCount
        let day = streakAfterRecord
        switch (count == 1, day > 0) {
        case (true, false): return String(localized: "your first check-in today")
        case (true, true): return String(localized: "your first check-in today · day \(day) of your streak")
        case (false, false): return String(localized: "\(count) check-ins today")
        case (false, true): return String(localized: "\(count) check-ins today · day \(day) of your streak")
        }
    }

    private var doneEyebrow: String {
        guard recordedQuality != nil else { return String(localized: "Noted") }
        let time = timeString(scheduledAt)
        return recordedMethod == .airpods
            ? String(localized: "\(time) · scanned")
            : String(localized: "\(time) · logged")
    }

    private func eyebrow(_ date: Date) -> String {
        "\(date.formatted(.dateTime.weekday(.wide))) · \(timeString(date))"
    }

    private func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Recording

    private func recordAcknowledgment(method: AcknowledgmentMethod, quality: PostureQuality?) {
        recordedMethod = method
        let now = AppClock.now
        let record = AcknowledgmentRecord(
            timestamp: now,
            method: method,
            quality: quality,
            scheduledAt: scheduledAt
        )
        context.insert(record)
        try? context.save()

        let streakService = StreakService(context: context)
        let streakBefore = streakService.currentState().currentStreak
        let state = streakService.recordAcknowledgment(at: now)
        streakAfterRecord = state.currentStreak

        let todayStart = DateHelpers.startOfDay(now)
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
