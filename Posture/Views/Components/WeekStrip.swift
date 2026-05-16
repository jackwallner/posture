import SwiftUI

struct DaySummary: Identifiable {
    let id = UUID()
    let label: String          // "M", "T", …
    let responseRate: Double   // 0...1 — bar height
    let averageQuality: PostureQuality?
}

/// Seven-day history hero. Bar height = response rate, fill color =
/// average quality. Today is marked with a small ink dot above the bar,
/// never a different bar style. Replaces the two duplicate bar charts.
struct WeekStrip: View {
    let days: [DaySummary]
    let todayIndex: Int

    var body: some View {
        GeometryReader { geo in
            let maxH = geo.size.height - 14
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(idx == todayIndex ? Theme.ink : .clear)
                            .frame(width: 4, height: 4)
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.paper3)
                                .frame(height: maxH)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(day.averageQuality.map(Theme.qualityColor) ?? Theme.ink3)
                                .frame(height: max(4, maxH * day.responseRate))
                        }
                        Text(day.label)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 110)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week's check-in rate and quality by day")
    }
}

#Preview {
    WeekStrip(
        days: (0..<7).map { i in
            DaySummary(
                label: ["M", "T", "W", "T", "F", "S", "S"][i],
                responseRate: [0.2, 0.7, 0.4, 1.0, 0.15, 0.1, 0.55][i],
                averageQuality: [.bad, .good, .borderline, .good, .bad, nil, .good][i]
            )
        },
        todayIndex: 6
    )
    .padding(24)
    .background(Theme.paper)
}
