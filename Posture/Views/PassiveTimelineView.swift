import SwiftData
import SwiftUI

/// 24-hour slouch rhythm from Watch / AirPods passive samples. Pro.
/// Daylight: warm sand→clay ramp instead of a punitive red, with a
/// one-line narrative of the worst window.
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

    private var airpodsCount: Int { samples.filter { $0.source == .airpods }.count }
    private var watchCount: Int { samples.filter { $0.source == .watch }.count }

    private var hourBuckets: [Int: Int] {
        Dictionary(grouping: samples) { Calendar.current.component(.hour, from: $0.timestamp) }
            .mapValues { $0.count }
    }

    private var maxCount: Int { max(1, hourBuckets.values.max() ?? 1) }

    private var peakLabel: String? {
        guard let peak = hourBuckets.max(by: { $0.value < $1.value })?.key else { return nil }
        return "\(hourString(peak))–\(hourString(peak + 1))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S RHYTHM")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.sage)

            if samples.isEmpty {
                Text("No slouches yet. Steady so far.")
                    .font(Theme.displaySerif(22))
                    .foregroundStyle(Theme.ink)
            } else if let peak = peakLabel {
                Text("Most slouching: \(peak).")
                    .font(Theme.displaySerif(22))
                    .foregroundStyle(Theme.ink)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = hourBuckets[hour] ?? 0
                    let intensity = Double(count) / Double(maxCount)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: intensity))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(6, CGFloat(intensity) * 56 + 6))
                }
            }
            .frame(height: 64)

            HStack {
                Text("12a").font(.caption2).foregroundStyle(Theme.ink3)
                Spacer()
                Text("12p").font(.caption2).foregroundStyle(Theme.ink3)
                Spacer()
                Text("12a").font(.caption2).foregroundStyle(Theme.ink3)
            }

            HStack(spacing: 8) {
                if airpodsCount > 0 {
                    chip("\(airpodsCount) airpods", tint: Theme.sage, bg: Theme.sageTint)
                }
                if watchCount > 0 {
                    chip("\(watchCount) watch", tint: Theme.ink2, bg: Theme.paper3)
                }
            }
        }
        .padding(18)
        .dawnCard(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.paper3, lineWidth: 1))
    }

    private func chip(_ text: String, tint: Color, bg: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg, in: .capsule)
    }

    private func color(for intensity: Double) -> Color {
        if intensity == 0 { return Theme.paper3 }
        if intensity < 0.5 { return Theme.sand }
        return Theme.clay
    }

    private func hourString(_ hour: Int) -> String {
        let h = hour % 24
        switch h {
        case 0: return "12a"
        case 12: return "12p"
        case let x where x < 12: return "\(x)a"
        default: return "\(h - 12)p"
        }
    }
}
