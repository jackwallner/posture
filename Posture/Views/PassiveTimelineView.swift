import SwiftData
import SwiftUI

/// 24-hour heatmap showing when the watch logged slouch events. Pro feature.
struct PassiveTimelineView: View {
    @Query(sort: \PosturePassiveSample.timestamp, order: .reverse) private var samples: [PosturePassiveSample]

    private var todaysSamples: [PosturePassiveSample] {
        samples.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    private var hourBuckets: [Int: Int] {
        Dictionary(grouping: todaysSamples) { Calendar.current.component(.hour, from: $0.timestamp) }
            .mapValues { $0.count }
    }

    private var maxCount: Int { max(1, hourBuckets.values.max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's slouches")
                    .font(.headline)
                Spacer()
                Text("\(todaysSamples.count)")
                    .font(.headline)
                    .foregroundStyle(Theme.bad)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = hourBuckets[hour] ?? 0
                    let intensity = Double(count) / Double(maxCount)
                    Rectangle()
                        .fill(color(for: intensity))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(6, CGFloat(intensity) * 60 + 6))
                        .clipShape(.rect(cornerRadius: 2))
                }
            }
            .frame(height: 70)

            HStack {
                Text("12a").font(.caption2).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("12p").font(.caption2).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("12a").font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
        .padding()
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private func color(for intensity: Double) -> Color {
        if intensity == 0 { return Theme.ringTrack }
        return Theme.bad.opacity(0.25 + 0.75 * intensity)
    }
}
