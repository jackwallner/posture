import SwiftData
import SwiftUI

/// The weekly posture report. Monitored days (minute aggregates) are the
/// story: how aligned each day was and how much of it was watched. Manual
/// check-ins appear as a secondary journal for the no-AirPods fallback.
struct HistoryView: View {
    @Environment(GoalSettings.self) private var settings
    @Query private var acknowledgments: [AcknowledgmentRecord]
    @Query private var minuteSamples: [PostureMinuteSample]
    @State private var showingAck = false

    init() {
        let cutoff = DateHelpers.daysAgo(14)
        _acknowledgments = Query(
            filter: #Predicate<AcknowledgmentRecord> { $0.timestamp >= cutoff },
            sort: \AcknowledgmentRecord.timestamp,
            order: .reverse
        )
        _minuteSamples = Query(
            filter: #Predicate<PostureMinuteSample> { $0.minuteStart >= cutoff }
        )
    }

    private let cal = Calendar.current

    // MARK: - Day buckets

    /// 7 day-starts, oldest → newest, ending today.
    private var weekDays: [Date] {
        let today = DateHelpers.startOfDay()
        return (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func dayStats(_ day: Date) -> PostureDayStats {
        let end = cal.date(byAdding: .day, value: 1, to: day) ?? day
        return PostureDayStats.compute(
            minutes: minuteSamples
                .filter { $0.minuteStart >= day && $0.minuteStart < end }
                .map(\.statsIngest)
        )
    }

    private var weekDayStats: [(day: Date, stats: PostureDayStats)] {
        weekDays.map { ($0, dayStats($0)) }
    }

    private var monitoredDaysThisWeek: Int {
        weekDayStats.filter { $0.stats.wearSeconds >= 600 }.count
    }

    /// Wear-weighted aligned % across a date range's monitored minutes.
    private func alignedPercent(from start: Date, to end: Date) -> Int? {
        let rows = minuteSamples.filter { $0.minuteStart >= start && $0.minuteStart < end }
        let wear = rows.reduce(0.0) { $0 + $1.monitoredSeconds }
        guard wear > 0 else { return nil }
        let weighted = rows.reduce(0.0) { $0 + $1.goodSeconds + $1.borderlineSeconds * 0.5 }
        return Int((weighted / wear * 100).rounded())
    }

    private var weekStart: Date { weekDays.first ?? DateHelpers.startOfDay() }

    private var weekAlignedPercent: Int? {
        alignedPercent(from: weekStart, to: .now)
    }

    private var deltaVsLastWeek: String? {
        guard let thisWeek = weekAlignedPercent else { return nil }
        let prevStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        guard let lastWeek = alignedPercent(from: prevStart, to: weekStart) else { return nil }
        let delta = thisWeek - lastWeek
        return delta >= 0 ? "+\(delta) vs last week" : "\(delta) vs last week"
    }

    private var weekWearSeconds: Double {
        weekDayStats.reduce(0) { $0 + $1.stats.wearSeconds }
    }

    // MARK: - Check-in journal (fallback + supplement)

    private var hasMonitoredData: Bool {
        minuteSamples.contains { $0.minuteStart >= weekStart }
    }

    private var weekAcks: [AcknowledgmentRecord] {
        acknowledgments.filter { $0.timestamp >= weekStart }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !hasMonitoredData && acknowledgments.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        weekHeader
                        // The wear/alignment chart only earns its space once
                        // monitoring has produced data; for check-in-only
                        // users the journal is the story.
                        if hasMonitoredData {
                            weekChart
                        }

                        if let percent = weekAlignedPercent {
                            HStack {
                                Text("\(percent)% aligned this week")
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                if let delta = deltaVsLastWeek {
                                    Text(delta)
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Theme.ink2)
                                }
                            }
                        }

                        if !acknowledgments.isEmpty {
                            Divider().background(Theme.paper3)
                            journalHeader
                            journalFeed
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .dawnBackground()
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingAck) {
                AcknowledgmentView(scheduledAt: .now, notificationIndex: nil)
            }
        }
    }

    // MARK: - Header

    private var weekRangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(f.string(from: first))–\(f.string(from: last))"
    }

    private var weekHeadline: String {
        if hasMonitoredData {
            switch monitoredDaysThisWeek {
            case 0..<3:
                return "Your first week is filling in."
            default:
                if let percent = weekAlignedPercent, percent >= 75 {
                    return "A strong week of sitting tall."
                }
                return "Here's how your week held up."
            }
        }
        return HistoryNarrative.sentence(for: weekAcks)
    }

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekRangeLabel)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            Text(weekHeadline)
                .font(Theme.display(24))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if weekWearSeconds > 0 {
                Text("\(PostureDayStats.wearLabel(seconds: weekWearSeconds)) monitored across \(monitoredDaysThisWeek) \(monitoredDaysThisWeek == 1 ? "day" : "days")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    // MARK: - Week chart

    /// One column per day: height = wear time, color = that day's alignment.
    /// Days without monitoring show a low stub.
    private var weekChart: some View {
        let stats = weekDayStats
        let maxWear = max(stats.map(\.stats.wearSeconds).max() ?? 0, 1)
        let wf = DateFormatter()
        wf.dateFormat = "EEEEE"

        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 6) {
                    dayColumn(entry.stats, maxWear: maxWear)
                    Text(wf.string(from: entry.day))
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(cal.isDateInToday(entry.day) ? Theme.ink : Theme.ink3)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .dawnCard(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekChartAccessibility)
    }

    private func dayColumn(_ stats: PostureDayStats, maxWear: Double) -> some View {
        let height: CGFloat = stats.wearSeconds > 0
            ? max(14, CGFloat(stats.wearSeconds / maxWear) * 96)
            : 8
        let color: Color = {
            guard let percent = stats.alignedPercent else { return Theme.paper3 }
            if percent >= 75 { return Theme.sage }
            if percent >= 45 { return Theme.sand }
            return Theme.clay
        }()
        return VStack(spacing: 4) {
            if let percent = stats.alignedPercent {
                Text("\(percent)")
                    .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink2)
            }
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(height: height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 118, alignment: .bottom)
    }

    private var weekChartAccessibility: String {
        let described = weekDayStats.compactMap { entry -> String? in
            guard let percent = entry.stats.alignedPercent else { return nil }
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return "\(f.string(from: entry.day)) \(percent) percent aligned"
        }
        guard !described.isEmpty else { return "No monitored days yet this week" }
        return "Week chart. " + described.joined(separator: ", ")
    }

    // MARK: - Journal

    private var journalHeader: some View {
        Text("Check-ins")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Theme.ink3)
    }

    private var journalFeed: some View {
        VStack(spacing: 0) {
            ForEach(Array(acknowledgments.prefix(20))) { ack in
                HStack(alignment: .top, spacing: 14) {
                    Text(timeString(ack.timestamp))
                        .font(.system(.footnote, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                        .frame(width: 76, alignment: .leading)
                    Text(rowLabel(ack))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Circle()
                        .fill(ack.quality.map(Theme.qualityColor) ?? .clear)
                        .frame(width: 8, height: 8)
                        .overlay {
                            if ack.quality == nil {
                                Circle().stroke(Theme.ink3, lineWidth: 1).frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 6)
                }
                .padding(.vertical, 12)
                if ack.id != acknowledgments.prefix(20).last?.id {
                    Divider().background(Theme.paper3)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HorizonStroke()
            Text("No history yet")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            Text(settings.hasAirpods == true
                 ? "Wear your AirPods today and this page starts writing itself."
                 : "Check in once and a story begins.")
                .font(Theme.display(28))
                .foregroundStyle(Theme.ink)
            Text("After a few days you'll see which days, and which hours, your posture holds up.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink2)
            if settings.hasAirpods != true {
                Button { showingAck = true } label: { Text("Check in now") }
                    .buttonStyle(.daylight(.primary))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func rowLabel(_ ack: AcknowledgmentRecord) -> String {
        let method: String
        switch ack.method {
        case .camera: method = "scan"
        case .airpods: method = "AirPods scan"
        case .manual: method = "logged"
        }
        guard let q = ack.quality else { return "Noted · \(method)" }
        let word: String
        switch q {
        case .good: word = "Aligned"
        case .borderline: word = "Drifting"
        case .bad: word = "Slouching"
        }
        return "\(word) · \(method)"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
