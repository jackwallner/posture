import SwiftUI

struct PostureRing: View {
    let score: Int
    let size: CGFloat
    var lineWidth: CGFloat = 16

    private var progress: Double { Double(score) / 100.0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: lineWidth)
            // Dawn: the sweep gradates sand → lavender across its arc, so
            // measurement and ritual blend (Stage A · C).
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.ringSweep, style: .init(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(Theme.bigNumber(size * 0.32))
                    .foregroundStyle(Theme.ink)
                Text("Score")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Posture score: \(score) out of 100")
        .accessibilityValue(qualityLabel)
    }

    private var qualityLabel: String {
        switch score {
        case 80...: return "Good"
        case 50..<80: return "Fair"
        default: return "Needs improvement"
        }
    }
}
