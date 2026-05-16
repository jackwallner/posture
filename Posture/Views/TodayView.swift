import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?
    @Query private var streaks: [StreakState]
    @Query(sort: \AcknowledgmentRecord.timestamp, order: .reverse) private var acknowledgments: [AcknowledgmentRecord]

    @State private var showingAck = false
    @State private var nextReminderText = "—"
    @State private var remainingReminders = 0
    @State private var currentTip = PostureTipService.randomTip()

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
                VStack(alignment: .leading, spacing: 22) {
                    alignmentReadout

                    if let monitor = airpodsMonitor, monitor.isMonitoring {
                        monitoringChip(monitor: monitor)
                    }

                    DayStrip(acks: todayAcks)

                    VStack(spacing: 10) {
                        Button { showingAck = true } label: { Text("check in now") }
                            .buttonStyle(.plain)
                            .daylightCTA(.primary)
                        metaRow
                    }

                    if todayAcks.isEmpty {
                        PostureBanner(
                            tone: .muted,
                            title: "A daylight habit takes about a week.",
                            message: "Check in a few times today. We'll show you the shape of it."
                        )
                    }

                    TipLine(tip: currentTip)
                        .onTapGesture {
                            withAnimation { currentTip = PostureTipService.randomTip() }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentStreak > 0 {
                        Text("\(currentStreak) days")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAck) {
                AcknowledgmentView(scheduledAt: .now, notificationIndex: nil)
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

    // MARK: - Alignment readout

    private var alignmentReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY'S ALIGNMENT")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(alignmentScore.map { "\($0)°" } ?? "—°")
                    .font(Theme.displaySerif(76))
                    .foregroundStyle(alignmentScore == nil ? Theme.ink3 : Theme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(readoutLabel)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(readoutColor)
                    Text(readoutSubtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
    }

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

    private var readoutColor: Color {
        guard let s = alignmentScore else { return Theme.ink3 }
        switch s {
        case 70...: return Theme.sage
        case 40..<70: return Theme.sand
        default: return Theme.clay
        }
    }

    private var readoutSubtitle: String {
        if scoredAcks.isEmpty {
            return todayAcks.isEmpty ? "Your first reading lands after a scan." : "manual check-ins only"
        }
        let onTrack = scoredAcks.filter { $0.quality == .good }.count
        return "\(onTrack) of \(scoredAcks.count) scans on track"
    }

    // MARK: - Monitoring chip

    @ViewBuilder
    private func monitoringChip(monitor: AirpodsBackgroundMonitor) -> some View {
        let live = monitor.isConnected
        HStack(spacing: 8) {
            Circle()
                .fill(live ? Theme.sage : Theme.sand)
                .frame(width: 6, height: 6)
            Text(live ? "monitoring · airpods linked" : "monitoring · waiting for airpods")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(live ? Theme.sage : Theme.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(live ? Theme.sageTint : Theme.sandTint, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Meta row

    @ViewBuilder
    private var metaRow: some View {
        if settings.reminderEnabled {
            Text("next nudge \(nextReminderText.lowercased()) · \(remainingReminders) left")
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
