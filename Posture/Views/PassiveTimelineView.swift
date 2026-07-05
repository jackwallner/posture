import SwiftData
import SwiftUI

/// The monitored day, hour by hour, from per-minute aggregates. Each hour
/// cell is colored by how aligned that hour actually was — not just whether
/// a slouch event fired — so the card fills with the story of the day.
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
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink3)

            Text(headline(stats))
                .font(Theme.display(22))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            hourStrip(stats)

            HStack {
                Text("12a").font(.caption2).foregroundStyle(Theme.ink3)
                Spacer()
                Text("12p").font(.caption2).foregroundStyle(Theme.ink3)
                Spacer()
                Text("12a").font(.caption2).foregroundStyle(Theme.ink3)
            }

            if stats.wearSeconds > 0 {
                Text(detailLine(stats))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
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
            return "Your day fills in as you wear your AirPods."
        }
        switch percent {
        case 80...: return "\(percent)% aligned. Strong day."
        case 55..<80: return "\(percent)% aligned so far."
        default: return "\(percent)% aligned. Rough stretch."
        }
    }

    private func detailLine(_ stats: PostureDayStats) -> String {
        var parts = ["\(PostureDayStats.wearLabel(seconds: stats.wearSeconds)) monitored"]
        if stats.longestAlignedMinutes >= 5 {
            parts.append("best stretch \(stats.longestAlignedMinutes)m")
        }
        if !slouches.isEmpty {
            parts.append("\(slouches.count) slouch\(slouches.count == 1 ? "" : "es") caught")
        }
        return parts.joined(separator: " · ")
    }

    private func hourStripAccessibility(_ stats: PostureDayStats) -> String {
        guard let percent = stats.alignedPercent else { return "No monitoring yet today" }
        return "Hour by hour posture chart. \(percent) percent aligned today."
    }
}
