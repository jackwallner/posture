import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?
    @Query private var streaks: [StreakState]
    @Query(sort: \AcknowledgmentRecord.timestamp, order: .reverse) private var acknowledgments: [AcknowledgmentRecord]

    @State private var showingAck = false
    @State private var showingRecalibrate = false
    @State private var nextReminderText = "—"
    @State private var remainingReminders = 0
    @State private var currentTip = PostureTipService.randomTip()
    @Query(sort: \Calibration.capturedAt, order: .reverse) private var calibrations: [Calibration]
    @Query private var passiveSamples: [PosturePassiveSample]

    private var hasPassiveSamplesToday: Bool {
        let today = DateHelpers.startOfDay()
        return passiveSamples.contains { $0.timestamp >= today }
    }

    /// Show a soft prompt to recalibrate after 30+ days — head pose drifts
    /// against the saved baseline (especially with AirPods which sit
    /// differently each time).
    private var needsRecalibration: Bool {
        guard let last = calibrations.first else { return false }
        let days = Calendar.current.dateComponents([.day], from: last.capturedAt, to: .now).day ?? 0
        return days >= 30
    }

    /// Display-only streak. Does not insert a StreakState during body
    /// evaluation (audit P1-10) — creation is owned by StreakService.
    private var currentStreak: Int { streaks.first?.currentStreak ?? 0 }

    private var todayAcks: [AcknowledgmentRecord] {
        let today = DateHelpers.startOfDay()
        return acknowledgments.filter { $0.timestamp >= today }
    }

    private var scoredAcks: [AcknowledgmentRecord] {
        todayAcks.compactMap { $0.quality == nil ? nil : $0 }
    }

    /// Mean of today's scored check-ins, 0–100, or nil if none scored.
    private var alignmentScore: Int? {
        let scores = scoredAcks.compactMap { $0.quality.map(qualityScore) }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerGreeting

                    alignmentCard

                    if let monitor = airpodsMonitor, monitor.isMonitoring {
                        monitoringPill(monitor: monitor)
                    }

                    weekCard

                    VStack(spacing: 12) {
                        Button { showingAck = true } label: { Text("check in now") }
                            .buttonStyle(.plain)
                            .daylightCTA(.primary)
                        metaRow
                    }
                    .padding(.top, 4)

                    if needsRecalibration {
                        softBanner(
                            title: "Time for a quick recalibrate.",
                            body: "AirPods sit a little differently over time, and posture shifts too. A five-second reset keeps scans honest.",
                            actionLabel: "recalibrate",
                            action: { showingRecalibrate = true }
                        )
                    } else if todayAcks.isEmpty {
                        softBanner(
                            title: "A new habit, gently.",
                            body: "Check in a couple of times today. The pattern shows up in about a week.",
                            actionLabel: nil,
                            action: nil
                        )
                    }

                    tipCard(tip: currentTip)
                        .onTapGesture {
                            withAnimation { currentTip = PostureTipService.randomTip() }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingAck) {
                AcknowledgmentView(scheduledAt: .now, notificationIndex: nil)
            }
            .sheet(isPresented: $showingRecalibrate) {
                CalibrationView(mode: .quickRecalibrate)
            }
            .task { await refreshReminderStatus() }
            .onChange(of: settings.reminderEnabled) { _, _ in
                Task { await refreshReminderStatus() }
            }
            .onChange(of: settings.reminderIntervalMinutes) { _, _ in
                Task { await refreshReminderStatus() }
            }
        }
    }

    // MARK: - Header

    private var headerGreeting: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeOfDayGreeting)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.ink3)
                Text("today")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            if currentStreak > 0 {
                Text("\(currentStreak) \(currentStreak == 1 ? "day" : "days")")
                    .font(Theme.displaySerif(18))
                    .foregroundStyle(Theme.ink2)
                    .accessibilityLabel("\(currentStreak) day streak")
            }
        }
        .padding(.top, 12)
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "good morning"
        case 12..<17: return "good afternoon"
        case 17..<22: return "good evening"
        default: return "hello, night owl"
        }
    }

    // MARK: - Alignment card

    private var alignmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("today's alignment")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(alignmentRingColor.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Text(alignmentScore.map { "\($0)" } ?? "—")
                        .font(.system(size: 42, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(readoutLabel)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(alignmentRingColor)
                    Text(readoutSubtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.paper2)
        )
    }

    private var alignmentRingColor: Color {
        guard let s = alignmentScore else { return Theme.ink3 }
        switch s {
        case 70...: return Theme.sage
        case 40..<70: return Theme.sand
        default: return Theme.clay
        }
    }

    // MARK: - Week card

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("this week")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Text("\(todayAcks.count) today")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink3)
            }
            DayStrip(
                acks: todayAcks,
                activeWindow: settings.activeHoursStart...settings.activeHoursEnd
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.paper2)
        )
    }

    // MARK: - Monitoring pill

    private func monitoringPill(monitor: AirpodsBackgroundMonitor) -> some View {
        let live = monitor.isConnected
        return HStack(spacing: 10) {
            Circle()
                .fill(live ? Theme.sage : Theme.sand)
                .frame(width: 7, height: 7)
            Text(live ? "AirPods linked · listening" : "waiting for AirPods")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(live ? Theme.sage : Theme.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(live ? Theme.sageTint : Theme.sandTint)
        )
    }

    // MARK: - Soft banner

    private func softBanner(title: String, body: String, actionLabel: String?, action: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel + " →")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.lavenderTint)
        )
    }

    private func tipCard(tip: PostureTip) -> some View {
        TipLine(tip: tip)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.paper2)
            )
    }

    // MARK: - Readout copy

    private var readoutLabel: String {
        guard let s = alignmentScore else {
            return todayAcks.isEmpty ? "no scans yet" : "checked in"
        }
        switch s {
        case 70...: return "aligned"
        case 40..<70: return "drifting"
        default: return "resting"
        }
    }

    private var readoutSubtitle: String {
        if scoredAcks.isEmpty {
            return todayAcks.isEmpty ? "your first reading lands after a scan." : "manual check-ins only"
        }
        let onTrack = scoredAcks.filter { $0.quality == .good }.count
        return "\(onTrack) of \(scoredAcks.count) scans on track"
    }

    // MARK: - Meta row

    @ViewBuilder
    private var metaRow: some View {
        if settings.reminderEnabled {
            Text("next reminder \(nextReminderText.lowercased()) · \(remainingReminders) more today")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.ink3)
        } else {
            HStack(spacing: 6) {
                Text("reminders are off.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink3)
                Button {
                    settings.reminderEnabled = true
                    Task { await ReminderScheduler.reschedule() }
                } label: {
                    Text("turn on →")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func qualityScore(_ q: PostureQuality) -> Int {
        switch q {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }

    private func refreshReminderStatus() async {
        if settings.reminderEnabled {
            let next = await ReminderScheduler.nextReminderDate()
            nextReminderText = next.map { formatReminderTime($0) } ?? "later today"
            remainingReminders = await ReminderScheduler.remainingCount()
        } else {
            nextReminderText = "—"
            remainingReminders = 0
        }
    }

    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
