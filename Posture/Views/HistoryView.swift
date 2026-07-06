import SwiftData
import SwiftUI

/// The posture history page. Practice is the story since the pivot: minutes
/// practiced per day up top, then every session as a tappable receipt.
/// Rich trends (14-day alignment, week delta, hour rhythm, monitoring wear)
/// are Posture+; check-in journal stays free for the no-AirPods loop.
struct HistoryView: View {
    @Environment(GoalSettings.self) private var settings
    @Query private var acknowledgments: [AcknowledgmentRecord]
    @Query private var minuteSamples: [PostureMinuteSample]
    @Query(sort: \PostureSession.startedAt, order: .reverse) private var sessions: [PostureSession]
    @State private var showingAck = false
    @State private var showingTrendsPaywall = false
    @State private var selectedSession: PostureSession?
    @State private var subscriptions = SubscriptionService.shared

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
    private var isPro: Bool { subscriptions.isProSubscriber }

    // MARK: - Day buckets

    /// 7 day-starts, oldest → newest, ending today.
    private var weekDays: [Date] {
        let today = DateHelpers.startOfDay()
        return (0..<7).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private var weekStart: Date { weekDays.first ?? DateHelpers.startOfDay() }

    /// Practice + walk sessions bucketed per day of this week.
    private func daySessions(_ day: Date) -> [PostureSession] {
        let end = cal.date(byAdding: .day, value: 1, to: day) ?? day
        return sessions.filter {
            $0.kind != .legacy && $0.startedAt >= day && $0.startedAt < end
        }
    }

    private struct PracticeDay {
        let day: Date
        let minutes: Int
        let sessionCount: Int
        /// Duration-weighted aligned % across the day's sessions, nil if none.
        let alignedPercent: Int?
        let anyPassed: Bool
    }

    private var practiceWeek: [PracticeDay] {
        weekDays.map { day in
            let rows = daySessions(day)
            let seconds = rows.reduce(0) { $0 + $1.durationSeconds }
            let weighted = rows.reduce(0.0) {
                $0 + Double($1.alignedPercent) * Double($1.durationSeconds)
            }
            return PracticeDay(
                day: day,
                minutes: seconds / 60,
                sessionCount: rows.count,
                alignedPercent: seconds > 0 ? Int((weighted / Double(seconds)).rounded()) : nil,
                anyPassed: rows.contains(where: \.passed)
            )
        }
    }

    private var weekPracticeMinutes: Int { practiceWeek.reduce(0) { $0 + $1.minutes } }
    private var weekSessionCount: Int { practiceWeek.reduce(0) { $0 + $1.sessionCount } }

    /// Every practice/walk session, newest first, for the receipts list.
    private var sessionHistory: [PostureSession] {
        sessions.filter { $0.kind != .legacy }
    }

    // MARK: - Monitoring stats (trends)

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

    /// Days with at least one monitored minute. The old 10-minute floor
    /// produced nonsense like "3m monitored across 0 days".
    private var monitoredDaysThisWeek: Int {
        weekDayStats.filter { $0.stats.wearSeconds >= 60 }.count
    }

    /// Wear-weighted aligned % across a date range's monitored minutes.
    private func alignedPercent(from start: Date, to end: Date) -> Int? {
        let rows = minuteSamples.filter { $0.minuteStart >= start && $0.minuteStart < end }
        let wear = rows.reduce(0.0) { $0 + $1.monitoredSeconds }
        guard wear > 0 else { return nil }
        let weighted = rows.reduce(0.0) { $0 + $1.goodSeconds + $1.borderlineSeconds * 0.5 }
        return Int((weighted / wear * 100).rounded())
    }

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

    private var hasMonitoredData: Bool {
        minuteSamples.contains { $0.minuteStart >= weekStart }
    }

    private var weekAcks: [AcknowledgmentRecord] {
        acknowledgments.filter { $0.timestamp >= weekStart }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessionHistory.isEmpty && !hasMonitoredData && acknowledgments.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        weekHeader
                        practiceChart
                        sessionList
                        trendsSection

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
            .sheet(isPresented: $showingTrendsPaywall) {
                PaywallView(paywallImpressionId: "posture_trends_gate")
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
                    .presentationDetents([.medium, .large])
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
        if weekSessionCount == 0 {
            return hasMonitoredData || !acknowledgments.isEmpty
                ? "This week is waiting for a practice."
                : "Your first week is filling in."
        }
        if weekPracticeMinutes >= 30 { return "A strong week of practice." }
        return "Here's your week of practice."
    }

    private var weekHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(weekRangeLabel)
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            Text(weekHeadline)
                .font(Theme.display(24))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if weekSessionCount > 0 {
                Text("\(weekPracticeMinutes) practice \(weekPracticeMinutes == 1 ? "minute" : "minutes") across \(weekSessionCount) \(weekSessionCount == 1 ? "session" : "sessions") this week")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    // MARK: - Practice chart (minutes per day - the metric that matters)

    /// One column per day: height = minutes practiced. Color reflects whether
    /// the day's practice held up (sage ≥ 50% aligned, sand under). The
    /// number is minutes, because minutes of practice are what move posture.
    private var practiceChart: some View {
        let days = practiceWeek
        let maxMinutes = max(days.map(\.minutes).max() ?? 0, 1)
        let wf = DateFormatter()
        wf.dateFormat = "EEEEE"

        return VStack(alignment: .leading, spacing: 10) {
            Text("Minutes practiced")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink3)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 6) {
                        practiceColumn(entry, maxMinutes: maxMinutes)
                        Text(wf.string(from: entry.day))
                            .font(Theme.font(.caption2, weight: .semibold))
                            .foregroundStyle(cal.isDateInToday(entry.day) ? Theme.ink : Theme.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .dawnCard(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(practiceChartAccessibility)
    }

    private func practiceColumn(_ entry: PracticeDay, maxMinutes: Int) -> some View {
        let height: CGFloat = entry.minutes > 0
            ? max(14, CGFloat(entry.minutes) / CGFloat(maxMinutes) * 96)
            : 8
        let color: Color = {
            guard let percent = entry.alignedPercent else { return Theme.paper3 }
            return percent >= 50 ? Theme.sage : Theme.sand
        }()
        return VStack(spacing: 4) {
            if entry.minutes > 0 {
                Text("\(entry.minutes)m")
                    .font(Theme.font(.caption2, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink2)
            }
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(height: height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 118, alignment: .bottom)
    }

    private var practiceChartAccessibility: String {
        let described = practiceWeek.compactMap { entry -> String? in
            guard entry.minutes > 0 else { return nil }
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return "\(f.string(from: entry.day)) \(entry.minutes) minutes"
        }
        guard !described.isEmpty else { return "No practice yet this week" }
        return "Practice minutes chart. " + described.joined(separator: ", ")
    }

    // MARK: - Session receipts

    @ViewBuilder
    private var sessionList: some View {
        if !sessionHistory.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sessions")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                    .padding(.bottom, 6)
                ForEach(Array(sessionHistory.prefix(30))) { session in
                    Button { selectedSession = session } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                    if session.id != sessionHistory.prefix(30).last?.id {
                        Divider().background(Theme.paper3)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: PostureSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.kind == .walk ? "figure.walk" : "figure.stand")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(session.completed ? Theme.goodText : Theme.ink3)
                .frame(width: 30, height: 30)
                .background(session.completed ? Theme.sageTint : Theme.paper3, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(sessionTitle(session))
                    .font(Theme.font(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(sessionSubtitle(session))
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            Text("\(session.alignedPercent)%")
                .font(Theme.font(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(session.passed ? Theme.goodText : Theme.ink2)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func sessionTitle(_ session: PostureSession) -> String {
        let minutes = max(1, session.durationSeconds / 60)
        let kind = session.kind == .walk ? "walk" : "practice"
        return "\(minutes)-minute \(kind)"
    }

    private func sessionSubtitle(_ session: PostureSession) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        var line = f.string(from: session.startedAt)
        if session.kind == .practice {
            if session.passed { line += " · passed" }
            else if session.completed { line += " · completed" }
            else { line += " · ended early" }
        }
        return line
    }

    // MARK: - Trends (Posture+)

    @ViewBuilder
    private var trendsSection: some View {
        if isPro {
            proTrends
        } else {
            trendsTeaser
        }
    }

    @ViewBuilder
    private var proTrends: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trends")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                Spacer()
                if let delta = deltaVsLastWeek {
                    Text(delta)
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                }
            }

            if hasMonitoredData {
                if let percent = weekAlignedPercent {
                    Text("\(percent)% aligned this week")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                monitoringChart
                if weekWearSeconds > 0 {
                    Text("\(PostureDayStats.wearLabel(seconds: weekWearSeconds)) monitored across \(monitoredDaysThisWeek) \(monitoredDaysThisWeek == 1 ? "day" : "days")")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink2)
                }
                hourRhythm
            } else {
                Text("Turn on monitoring or practice with the app open and your alignment trends build here, hour by hour.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Free tier: one honest teaser (today's aligned %) and the gate.
    private var trendsTeaser: some View {
        Button { showingTrendsPaywall = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Trends")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                // Silhouette columns - the shape of the feature, no numbers.
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array([38, 64, 46, 80, 58, 88, 70].enumerated()), id: \.offset) { _, h in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.paper3)
                            .frame(height: CGFloat(h))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 88, alignment: .bottom)
                Text("See your alignment trends with Posture+")
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Week-over-week alignment, your strong and slouchy hours, and every monitored minute, scored.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alignment trends, a Posture plus feature. Tap to see plans.")
    }

    /// One column per day: height = wear time, color = that day's alignment.
    private var monitoringChart: some View {
        let stats = weekDayStats
        let maxWear = max(stats.map(\.stats.wearSeconds).max() ?? 0, 1)
        let wf = DateFormatter()
        wf.dateFormat = "EEEEE"

        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 6) {
                    monitoringColumn(entry.stats, maxWear: maxWear)
                    Text(wf.string(from: entry.day))
                        .font(Theme.font(.caption2, weight: .semibold))
                        .foregroundStyle(cal.isDateInToday(entry.day) ? Theme.ink : Theme.ink3)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .dawnCard(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitoringChartAccessibility)
    }

    private func monitoringColumn(_ stats: PostureDayStats, maxWear: Double) -> some View {
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
                    .font(Theme.font(.caption2, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink2)
            }
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(height: height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 118, alignment: .bottom)
    }

    private var monitoringChartAccessibility: String {
        let described = weekDayStats.compactMap { entry -> String? in
            guard let percent = entry.stats.alignedPercent else { return nil }
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return "\(f.string(from: entry.day)) \(percent) percent aligned"
        }
        guard !described.isEmpty else { return "No monitored days yet this week" }
        return "Monitoring chart. " + described.joined(separator: ", ")
    }

    /// Strong hours vs slouch hours across the week's monitored minutes.
    @ViewBuilder
    private var hourRhythm: some View {
        let byHour = weekHourAlignment
        if byHour.count >= 3 {
            let sorted = byHour.sorted { $0.value > $1.value }
            let strong = sorted.prefix(3).map(\.key).sorted()
            let slouchy = sorted.suffix(3).map(\.key).sorted()
            VStack(alignment: .leading, spacing: 8) {
                rhythmLine(icon: "sun.max", color: Theme.sage,
                           label: "Strong hours", hours: strong)
                rhythmLine(icon: "cloud", color: Theme.clay,
                           label: "Slouchy hours", hours: slouchy)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard(cornerRadius: 14)
        }
    }

    private func rhythmLine(icon: String, color: Color, label: String, hours: [Int]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(hours.map(hourLabel).joined(separator: " · "))
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12)\(hour < 12 ? "am" : "pm")"
    }

    /// Wear-weighted alignment fraction per hour across the whole week.
    private var weekHourAlignment: [Int: Double] {
        var weighted: [Int: Double] = [:]
        var total: [Int: Double] = [:]
        for m in minuteSamples where m.minuteStart >= weekStart {
            let seconds = m.goodSeconds + m.borderlineSeconds + m.badSeconds
            guard seconds > 0 else { continue }
            let hour = cal.component(.hour, from: m.minuteStart)
            weighted[hour, default: 0] += m.goodSeconds + m.borderlineSeconds * 0.5
            total[hour, default: 0] += seconds
        }
        var result: [Int: Double] = [:]
        for (hour, t) in total where t >= 300 {  // ≥5 monitored min to judge an hour
            result[hour] = (weighted[hour] ?? 0) / t
        }
        return result
    }

    // MARK: - Journal

    private var journalHeader: some View {
        Text("Check-ins")
            .font(Theme.font(.footnote, weight: .semibold))
            .foregroundStyle(Theme.ink3)
    }

    private var journalFeed: some View {
        VStack(spacing: 0) {
            ForEach(Array(acknowledgments.prefix(20))) { ack in
                HStack(alignment: .top, spacing: 14) {
                    Text(timeString(ack.timestamp))
                        .font(Theme.font(.footnote).monospacedDigit())
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                        .frame(width: 76, alignment: .leading)
                    Text(rowLabel(ack))
                        .font(Theme.font(.subheadline))
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
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            Text(settings.hasAirpods == true
                 ? "Finish today's practice and this page starts writing itself."
                 : "Check in once and a story begins.")
                .font(Theme.display(28))
                .foregroundStyle(Theme.ink)
            Text("After a few days you'll see your practice minutes stack up, day after day.")
                .font(Theme.font(.body))
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

// MARK: - Session detail

/// The receipt for any past session: what it was, how it held up, and the
/// time split, from the persisted row.
struct SessionDetailView: View {
    let session: PostureSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    /// Per-minute aligned fraction across the session's window, oldest first -
    /// the minute-by-minute story of where you held tall vs slouched.
    @State private var minuteFractions: [Double] = []

    private var totalSeconds: Int {
        max(session.goodSeconds + session.borderlineSeconds + session.badSeconds, 1)
    }

    private var isWalk: Bool { session.kind == .walk }

    private var metric: Bool { Locale.current.measurementSystem == .metric }
    private var distanceValue: String {
        let d = metric ? session.distanceMeters / 1000 : session.distanceMeters / 1609.34
        return String(format: d < 10 ? "%.2f" : "%.1f", d)
    }

    /// Load the minute rows overlapping this session's clock. Sessions write
    /// one `PostureMinuteSample` per minute (source .airpods), so the walk's
    /// (or practice's) minute-by-minute alignment is already on disk.
    private func loadMinutes() {
        let start = session.startedAt.addingTimeInterval(-30)
        let end = session.startedAt.addingTimeInterval(Double(session.durationSeconds) + 90)
        let descriptor = FetchDescriptor<PostureMinuteSample>(
            predicate: #Predicate { $0.minuteStart >= start && $0.minuteStart <= end },
            sortBy: [SortDescriptor(\.minuteStart)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        minuteFractions = rows.filter { $0.monitoredSeconds > 0 }.map(\.alignmentFraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dateLine)
                        .font(Theme.font(.caption, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                    Text(headline)
                        .font(Theme.display(26))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .frame(width: 30, height: 30)
                        .background(Theme.paper2, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            HStack(spacing: 12) {
                statCard(value: "\(session.alignedPercent)%", label: "aligned",
                         color: session.passed ? Theme.sage : Theme.ink)
                statCard(value: minutesLabel, label: "duration", color: Theme.ink)
                if session.kind == .practice, session.targetPercent > 0 {
                    statCard(value: "\(session.targetPercent)%", label: "target", color: Theme.ink)
                }
            }

            if isWalk, session.steps > 0 || session.distanceMeters > 0 {
                HStack(spacing: 12) {
                    statCard(value: distanceValue, label: metric ? "km walked" : "mi walked", color: Theme.ink)
                    statCard(value: "\(session.steps)", label: "steps", color: Theme.ink)
                }
            }

            if minuteFractions.count >= 2 {
                minuteStrip
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Where the time went")
                    .font(Theme.font(.caption, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.ink3)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        splitSegment(seconds: session.goodSeconds, color: Theme.sage, width: geo.size.width)
                        splitSegment(seconds: session.borderlineSeconds, color: Theme.sand, width: geo.size.width)
                        splitSegment(seconds: session.badSeconds, color: Theme.clay, width: geo.size.width)
                    }
                }
                .frame(height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                HStack(spacing: 14) {
                    legend(color: Theme.sage, label: "aligned", seconds: session.goodSeconds)
                    legend(color: Theme.sand, label: "drifting", seconds: session.borderlineSeconds)
                    legend(color: Theme.clay, label: "slouching", seconds: session.badSeconds)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard(cornerRadius: 14)

            Text(verdictLine)
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dawnBackground()
        .task { loadMinutes() }
    }

    /// Minute-by-minute alignment: one bar per minute of the session, so you
    /// can see which stretches held tall and where you slouched.
    private var minuteStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isWalk ? "The walk, minute by minute" : "Minute by minute")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink3)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(minuteFractions.enumerated()), id: \.offset) { _, fraction in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(minuteBarColor(fraction))
                        .frame(height: 10 + 26 * fraction)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40, alignment: .bottom)
            HStack {
                Text("start")
                Spacer()
                Text("end")
            }
            .font(Theme.font(.caption2))
            .foregroundStyle(Theme.ink3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }

    private func minuteBarColor(_ fraction: Double) -> Color {
        switch fraction {
        case 0.75...: return Theme.sage
        case 0.45..<0.75: return Theme.sand
        default: return Theme.clay
        }
    }

    private var headline: String {
        let minutes = max(1, session.durationSeconds / 60)
        return session.kind == .walk
            ? "\(minutes)-minute walk"
            : "\(minutes)-minute practice"
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d · h:mm a"
        return f.string(from: session.startedAt)
    }

    private var minutesLabel: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    private var verdictLine: String {
        if session.kind == .walk {
            return session.completed
                ? "Walk finished. It counted toward that day's streak."
                : "Walk ended early. The minutes still count in the day's timeline."
        }
        if session.passed {
            return "Target met. This pass counted toward your level."
        }
        if session.completed {
            return "Completed under the \(session.targetPercent)% target. The streak day was credited."
        }
        return "Ended early, so no streak credit. The minutes still count."
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.font(size: 26, weight: .regular))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .dawnCard(cornerRadius: 14)
    }

    @ViewBuilder
    private func splitSegment(seconds: Int, color: Color, width: CGFloat) -> some View {
        if seconds > 0 {
            Rectangle()
                .fill(color)
                .frame(width: max(4, width * CGFloat(seconds) / CGFloat(totalSeconds)))
        }
    }

    private func legend(color: Color, label: String, seconds: Int) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(label) \(seconds / 60)m")
                .font(Theme.font(.caption2))
                .foregroundStyle(Theme.ink2)
        }
    }
}
