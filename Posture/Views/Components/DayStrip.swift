import SwiftUI

/// A horizon of the day, hour by hour. Each bar's color is the quality of
/// that hour's most-recent check-in; height encodes how many. Future
/// hours render as dashed placeholders. Replaces the response-rate
/// progress bar and the today-summary tile row.
struct DayStrip: View {
    let acks: [AcknowledgmentRecord]
    var now: Date = .now
    var activeWindow: ClosedRange<Int> = 8...20

    private var hours: [Int] { Array(activeWindow.lowerBound...activeWindow.upperBound) }
    private var currentHour: Int { Calendar.current.component(.hour, from: now) }

    private func acks(in hour: Int) -> [AcknowledgmentRecord] {
        acks
            .filter { Calendar.current.component(.hour, from: $0.timestamp) == hour }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func barHeight(count: Int, max maxH: CGFloat) -> CGFloat {
        guard count > 0 else { return 6 }
        let capped = min(count, 4)
        return 6 + (maxH - 6) * CGFloat(capped) / 4
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let maxH = geo.size.height
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(hours, id: \.self) { hour in
                        let bucket = acks(in: hour)
                        if hour > currentHour {
                            // Future — dashed baseline
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                .frame(height: 1)
                                .foregroundStyle(Theme.paper3)
                                .frame(maxWidth: .infinity, alignment: .bottom)
                                .frame(height: maxH, alignment: .bottom)
                        } else if let latest = bucket.first {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(latest.quality.map(Theme.qualityColor) ?? Theme.ink3)
                                .frame(maxWidth: .infinity)
                                .frame(height: barHeight(count: bucket.count, max: maxH))
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Theme.paper3)
                                .frame(maxWidth: .infinity)
                                .frame(height: 6)
                        }
                    }
                }
                .frame(height: maxH, alignment: .bottom)
            }
            .frame(height: 64)

            HStack(spacing: 4) {
                ForEach(hours, id: \.self) { hour in
                    Text(hour % 2 == 0 ? hourLabel(hour) : " ")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's check-ins by hour")
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 12: return "12p"
        case let h where h < 12: return "\(h)a"
        default: return "\(hour - 12)p"
        }
    }
}

#Preview {
    DayStrip(acks: [])
        .padding(24)
        .background(Theme.paper)
}
