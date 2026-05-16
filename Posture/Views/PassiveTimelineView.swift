import SwiftData
import SwiftUI

/// 24-hour heatmap showing when slouch events were detected from watch or AirPods. Pro feature.
struct PassiveTimelineView: View {
    @Query private var samples: [PosturePassiveSample]

    init() {
        let today = DateHelpers.startOfDay()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<PosturePassiveSample> { sample in
            sample.timestamp >= today && sample.timestamp < tomorrow
        }
        _samples = Query(filter: predicate, sort: \PosturePassiveSample.timestamp, order: .reverse)
    }

    private var todaysSamples: [PosturePassiveSample] { samples }

    private var airpodsSamples: [PosturePassiveSample] {
        todaysSamples.filter { $0.source == .airpods }
    }

    private var watchSamples: [PosturePassiveSample] {
        todaysSamples.filter { $0.source == .watch }
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

            // Source breakdown
            HStack(spacing: 16) {
                if !airpodsSamples.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "airpodspro")
                            .font(.caption2)
                        Text("\(airpodsSamples.count) from AirPods")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.bad)
                }
                if !watchSamples.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch")
                            .font(.caption2)
                        Text("\(watchSamples.count) from Watch")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.brandPrimary)
                }
                if todaysSamples.isEmpty {
                    Text("No slouches detected — great posture!")
                        .font(.caption)
                        .foregroundStyle(Theme.good)
                }
            }

            // Heatmap
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
