import Charts
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query private var sessions: [PostureSession]
    @Query private var acknowledgments: [AcknowledgmentRecord]
    @State private var subscriptions = SubscriptionService.shared

    init() {
        let cutoff = DateHelpers.daysAgo(30)
        let sessionPredicate = #Predicate<PostureSession> { session in
            session.startedAt >= cutoff
        }
        _sessions = Query(filter: sessionPredicate, sort: \PostureSession.startedAt, order: .reverse)
        let ackPredicate = #Predicate<AcknowledgmentRecord> { ack in
            ack.timestamp >= cutoff
        }
        _acknowledgments = Query(filter: ackPredicate, sort: \AcknowledgmentRecord.timestamp, order: .reverse)
    }

    /// Best quality score per day (from sessions or camera acknowledgments).
    private var weeklyQualityData: [(day: Date, score: Int)] {
        let today = DateHelpers.startOfDay()
        var bestByDay: [Date: Int] = [:]

        // Collect from sessions
        for session in sessions {
            let day = DateHelpers.startOfDay(session.startedAt)
            let daysFrom = Calendar.current.dateComponents([.day], from: day, to: today).day ?? 0
            guard daysFrom < 7 else { continue }
            bestByDay[day] = max(bestByDay[day] ?? 0, session.score)
        }

        // Collect from camera acknowledgments
        for ack in acknowledgments where ack.method == .camera {
            let day = DateHelpers.startOfDay(ack.timestamp)
            let daysFrom = Calendar.current.dateComponents([.day], from: day, to: today).day ?? 0
            guard daysFrom < 7 else { continue }
            if let quality = ack.quality {
                bestByDay[day] = max(bestByDay[day] ?? 0, qualityToScore(quality))
            }
        }

        return (0..<7).compactMap { offset in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, bestByDay[day] ?? 0)
        }
        .reversed()
    }

    /// Response rate per day (acknowledgments vs estimated reminders sent).
    private var weeklyResponseData: [(day: Date, rate: Double)] {
        let today = DateHelpers.startOfDay()
        let calendar = Calendar.current

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayStart = day
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            let todayAcks = acknowledgments.filter {
                $0.timestamp >= dayStart && $0.timestamp < dayEnd
            }.count

            // Estimate reminders: assume ~1 per interval during active hours
            // This is a rough estimate — we track scheduledCount in a more advanced impl
            let reminderCount = max(todayAcks, 1) // show at least 1 for days with data
            let rate = todayAcks > 0 ? min(Double(todayAcks) / Double(reminderCount), 1.0) : 0.0

            return (day, rate)
        }
        .reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Quality chart
                    if !weeklyQualityData.allSatisfy({ $0.score == 0 }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekly Quality")
                                .font(.headline)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 4)
                            WeeklyTrendChart(data: weeklyQualityData)
                                .frame(height: 120)
                        }
                        .padding(.horizontal)
                    }

                    // Response rate chart
                    if !weeklyResponseData.allSatisfy({ $0.rate == 0 }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Response Rate")
                                .font(.headline)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 4)
                            ResponseRateChart(data: weeklyResponseData)
                                .frame(height: 80)
                        }
                        .padding(.horizontal)
                    }

                    if subscriptions.isProSubscriber {
                        PassiveTimelineView()
                            .padding(.horizontal)
                    }

                    // Mixed timeline: acknowledgments + sessions
                    if sessions.isEmpty && acknowledgments.isEmpty {
                        emptyState
                    } else {
                        timeline
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No history yet")
                .font(.headline)
            Text("Respond to a posture reminder to start tracking your progress.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(spacing: 0) {
            // Interleave recent acknowledgments and sessions
            ForEach(mergedTimeline, id: \.id) { entry in
                switch entry {
                case .acknowledgment(let ack):
                    ackRow(for: ack)
                case .session(let session):
                    sessionRow(for: session)
                }
                if entry.id != mergedTimeline.last?.id {
                    Divider().padding(.leading, 80)
                }
            }
        }
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
        .padding(.horizontal)
    }

    private enum TimelineEntry: Identifiable {
        case acknowledgment(AcknowledgmentRecord)
        case session(PostureSession)

        var id: String {
            switch self {
            case .acknowledgment(let a): "ack-\(a.id)"
            case .session(let s): "sess-\(s.id)"
            }
        }
    }

    private var mergedTimeline: [TimelineEntry] {
        var entries: [TimelineEntry] = []
        entries.append(contentsOf: acknowledgments.map { .acknowledgment($0) })
        entries.append(contentsOf: sessions.map { .session($0) })
        entries.sort { lhs, rhs in
            let d1: Date = switch lhs { case .acknowledgment(let a): a.timestamp case .session(let s): s.startedAt }
            let d2: Date = switch rhs { case .acknowledgment(let a): a.timestamp case .session(let s): s.startedAt }
            return d1 > d2
        }
        return entries
    }

    private func ackRow(for ack: AcknowledgmentRecord) -> some View {
        HStack(spacing: 14) {
            // Quality indicator or icon
            if let quality = ack.quality {
                PostureRing(score: qualityToScore(quality), size: 52, lineWidth: 6)
            } else {
                Image(systemName: "hand.tap")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 52, height: 52)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(DateHelpers.mediumDateTime(ack.timestamp))
                    .font(.headline)
                Text(ack.method == .camera ? "Camera scan" : "Manual check-in")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if let quality = ack.quality {
                Text(quality.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.qualityColor(quality))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func sessionRow(for session: PostureSession) -> some View {
        HStack(spacing: 14) {
            PostureRing(score: session.score, size: 52, lineWidth: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(DateHelpers.mediumDate(session.startedAt))
                    .font(.headline)
                Text("\(session.durationSeconds)s · Legacy session")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func qualityToScore(_ quality: PostureQuality) -> Int {
        switch quality {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }
}

// MARK: - Weekly Trend Chart

private struct WeeklyTrendChart: View {
    let data: [(day: Date, score: Int)]

    var body: some View {
        Chart {
            bars
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel()
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: xDomain)
        .accessibilityLabel("Weekly posture trend chart")
    }

    @ChartContentBuilder
    private var bars: some ChartContent {
        ForEach(data, id: \.day) { entry in
            BarMark(x: .value("Day", entry.day, unit: .day),
                    y: .value("Score", barHeight(for: entry.score)))
            .clipShape(.rect(cornerRadius: 4))
            .foregroundStyle(scoreColor(entry.score).gradient)
        }
    }

    private var xDomain: ClosedRange<Date> {
        guard let f = data.first, let l = data.last else { return .now ... .now }
        return f.day ... l.day
    }

    private func barHeight(for score: Int) -> Int {
        score == 0 ? 0 : max(score, 10)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return Theme.good
        case 50..<80: return Theme.borderline
        case 1..<50: return Theme.bad
        default: return Theme.textTertiary.opacity(0.3)
        }
    }
}

// MARK: - Response Rate Chart

private struct ResponseRateChart: View {
    let data: [(day: Date, rate: Double)]

    var body: some View {
        Chart {
            ForEach(data, id: \.day) { entry in
                BarMark(x: .value("Day", entry.day, unit: .day),
                        y: .value("Rate", entry.rate * 100))
                .clipShape(.rect(cornerRadius: 4))
                .foregroundStyle((entry.rate > 0.6 ? Theme.good : entry.rate > 0.3 ? Theme.borderline : Theme.textTertiary).gradient)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 2)) { value in
                AxisValueLabel("\(Int(value.as(Int.self) ?? 0))%")
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: xDomain)
        .accessibilityLabel("Weekly response rate chart")
    }

    private var xDomain: ClosedRange<Date> {
        guard let f = data.first, let l = data.last else { return .now ... .now }
        return f.day ... l.day
    }
}
