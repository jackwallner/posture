import SwiftData
import SwiftUI

/// The monitored day, hour by hour, from per-minute aggregates. Each hour
/// cell is colored by how aligned that hour actually was - not just whether
/// a slouch event fired - so the card fills with the story of the day.
struct PassiveTimelineView: View {
    @Query private var minutes: [PostureMinuteSample]
    @Query private var slouches: [PosturePassiveSample]

    init() {
        let today = DateHelpers.startOfDay()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        _minutes = Query(filter: #Predicate<PostureMinuteSample> {
            $0.minuteStart >= today && $0.minuteStart < tomorrow
        })
        _slouches = Query(filter: #Predicate<PosturePassiveSample> {
            $0.timestamp >= today && $0.timestamp < tomorrow
        })
    }

    private var stats: PostureDayStats {
        PostureDayStats.compute(minutes: minutes.map(\.statsIngest))
    }

    var body: some View {
        let stats = stats
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's rhythm")
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink3)

            Text(headline(stats))
                .font(Theme.display(22))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            hourStrip(stats)

            HStack {
                Text(Self.axisLabel(0)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink3)
                Spacer()
                Text(Self.axisLabel(12)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink3)
                Spacer()
                Text(Self.axisLabel(0)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink3)
            }

            if stats.wearSeconds > 0 {
                Text(detailLine(stats))
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }

    /// Compact hour tick in the user's locale ("12a", "0").
    private static func axisLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .narrow)))
    }

    private func hourStrip(_ stats: PostureDayStats) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<24, id: \.self) { hour in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: stats.hourAlignment[hour]))
                    .frame(maxWidth: .infinity)
                    .frame(height: stats.hourAlignment[hour] == nil ? 14 : 34)
            }
        }
        .frame(height: 36, alignment: .bottom)
        .accessibilityLabel(hourStripAccessibility(stats))
    }

    private func color(for alignment: Double?) -> Color {
        guard let alignment else { return Theme.paper3 }
        if alignment >= 0.75 { return Theme.sage }
        if alignment >= 0.45 { return Theme.sand }
        return Theme.clay
    }

    private func headline(_ stats: PostureDayStats) -> String {
        guard let percent = stats.alignedPercent else {
            return String(localized: "Your day fills in as you wear your AirPods.")
        }
        switch percent {
        case 80...: return String(localized: "\(percent)% aligned. Strong day.")
        case 55..<80: return String(localized: "\(percent)% aligned so far.")
        default: return String(localized: "\(percent)% aligned. Rough stretch.")
        }
    }

    private func detailLine(_ stats: PostureDayStats) -> String {
        let wear = PostureDayStats.wearLabel(seconds: stats.wearSeconds)
        var parts = [String(localized: "\(wear) monitored")]
        if stats.longestAlignedMinutes >= 5 {
            let stretch = PostureDayStats.wearLabel(seconds: Double(stats.longestAlignedMinutes * 60))
            parts.append(String(localized: "best stretch \(stretch)"))
        }
        if !slouches.isEmpty {
            parts.append(String(localized: "\(slouches.count) slouches caught"))
        }
        return parts.joined(separator: " · ")
    }

    private func hourStripAccessibility(_ stats: PostureDayStats) -> String {
        guard let percent = stats.alignedPercent else { return String(localized: "No monitoring yet today") }
        return String(localized: "Hour by hour posture chart. \(percent) percent aligned today.")
    }
}
