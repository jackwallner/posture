import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(GoalSettings.self) private var settings
    @Query private var acknowledgments: [AcknowledgmentRecord]
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingAck = false
    @State private var showingPaywall = false

    init() {
        let cutoff = DateHelpers.daysAgo(14)
        let ackPredicate = #Predicate<AcknowledgmentRecord> { ack in
            ack.timestamp >= cutoff
        }
        _acknowledgments = Query(filter: ackPredicate, sort: \AcknowledgmentRecord.timestamp, order: .reverse)
    }

    private let cal = Calendar.current

    private func qualityScore(_ q: PostureQuality) -> Int {
        switch q {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }

    /// 7 day buckets, oldest → newest, ending today.
    private var weekDays: [Date] {
        let today = DateHelpers.startOfDay()
        return (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    /// Mirror of `NotificationService.scheduleReminders` slot count, so the
    /// week strip's "fill" ratio matches the user's actual reminder cadence.
    private var expectedPerDay: Int {
        let windowMinutes = max(0, (settings.activeHoursEnd - settings.activeHoursStart)) * 60
        let interval = max(1, settings.reminderIntervalMinutes)
        return max(1, min(20, windowMinutes / interval))
    }

    private func acks(on day: Date) -> [AcknowledgmentRecord] {
        let end = cal.date(byAdding: .day, value: 1, to: day) ?? day
        return acknowledgments.filter { $0.timestamp >= day && $0.timestamp < end }
    }

    private var weekSummaries: [DaySummary] {
        let wf = DateFormatter()
        wf.dateFormat = "EEEEE"
        return weekDays.map { day in
            let dayAcks = acks(on: day)
            let scored = dayAcks.compactMap { $0.quality.map(qualityScore) }
            let avgQuality: PostureQuality? = scored.isEmpty ? nil : {
                let m = Double(scored.reduce(0, +)) / Double(scored.count)
                switch m {
                case 70...: return .good
                case 40..<70: return .borderline
                default: return .bad
                }
            }()
            let rate = min(1.0, Double(dayAcks.count) / Double(expectedPerDay))
            return DaySummary(label: wf.string(from: day), responseRate: rate, averageQuality: avgQuality)
        }
    }

    /// The query spans 14 days (for the vs-last-week delta); this is just
    /// the current 7-day window.
    private var weekAcks: [AcknowledgmentRecord] {
        let weekStart = weekDays.first ?? DateHelpers.startOfDay()
        return acknowledgments.filter { $0.timestamp >= weekStart }
    }

    private var weekScored: [Int] {
        weekAcks.compactMap { $0.quality.map(qualityScore) }
    }

    private var weekAlignmentPercent: Int {
        guard !weekScored.isEmpty else { return 0 }
        return Int((Double(weekScored.reduce(0, +)) / Double(weekScored.count)).rounded())
    }

    private var deltaVsLastWeek: String {
        let weekStart = weekDays.first ?? DateHelpers.startOfDay()
        let prevStart = cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let prev = acknowledgments
            .filter { $0.timestamp >= prevStart && $0.timestamp < weekStart }
            .compactMap { $0.quality.map(qualityScore) }
        guard !prev.isEmpty, !weekScored.isEmpty else { return "—" }
        let prevMean = Double(prev.reduce(0, +)) / Double(prev.count)
        let delta = Double(weekAlignmentPercent) - prevMean
        let rounded = Int(delta.rounded())
        return rounded >= 0 ? "+\(rounded) vs last" : "\(rounded) vs last"
    }

    private var weekRangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        return "\(f.string(from: first)) — \(f.string(from: last))".uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if acknowledgments.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        if subscriptions.isProSubscriber {
                            PassiveTimelineView()
                        } else {
                            proPreviewCard
                        }

                        weekHeader
                        WeekStrip(days: weekSummaries, todayIndex: 6)

                        HStack {
                            Text("\(weekAlignmentPercent)% aligned")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(deltaVsLastWeek)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink2)
                        }

                        Divider().background(Theme.paper3)

                        journalFeed
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .dawnBackground()
            .navigationTitle("history")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingAck) {
                AcknowledgmentView(scheduledAt: .now, notificationIndex: nil)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "posture_history_sheet")
            }
        }
    }

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekRangeLabel)
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text(HistoryNarrative.sentence(for: weekAcks))
                .font(Theme.displaySerif(24))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var journalFeed: some View {
        VStack(spacing: 0) {
            ForEach(Array(acknowledgments.prefix(20))) { ack in
                HStack(alignment: .top, spacing: 14) {
                    Text(timeString(ack.timestamp))
                        .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 64, alignment: .leading)
                    Text(rowLabel(ack))
                        .font(.subheadline)
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

    private var proPreviewCard: some View {
        Button { showingPaywall = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("TODAY'S RHYTHM · POSTURE+")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.sage)
                Text("See the hours your posture slips.")
                    .font(Theme.displaySerif(22))
                    .foregroundStyle(Theme.ink)
                Text("Posture+ adds an hour-by-hour rhythm from AirPods and Watch.")
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
                Text("see your rhythm →")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sage)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.sageTint, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HorizonStroke()
            Text("NO HISTORY YET")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text("Check in once and a story begins.")
                .font(Theme.displaySerif(28))
                .foregroundStyle(Theme.ink)
            Text("We need a few days before patterns are worth showing. Until then, today is plenty.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
            Button { showingAck = true } label: { Text("check in now") }
                .buttonStyle(.daylight(.primary))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowLabel(_ ack: AcknowledgmentRecord) -> String {
        let method: String
        switch ack.method {
        case .camera: method = "scan"
        case .airpods: method = "AirPods scan"
        case .manual: method = "logged"
        }
        guard let q = ack.quality else { return "noted · \(method)" }
        let word: String
        switch q {
        case .good: word = "aligned"
        case .borderline: word = "drifting"
        case .bad: word = "resting"
        }
        return "\(word) · \(method)"
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date).lowercased()
    }
}
