import SwiftUI

struct PostureRing: View {
    let score: Int
    let size: CGFloat
    var lineWidth: CGFloat = 16

    private var progress: Double { Double(score) / 100.0 }

    private var color: Color {
        switch score {
        case 80...: return Theme.good
        case 50..<80: return Theme.borderline
        default: return Theme.bad
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: .init(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(Theme.bigNumber(size * 0.32))
                    .foregroundStyle(color)
                Text("score")
                    .font(.caption)
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
