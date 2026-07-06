import SwiftUI

/// Target-met sessions toward the next level — filled pips replace "pass" copy.
struct LevelPipsView: View {
    enum Size {
        case compact, regular, prominent

        var diameter: CGFloat {
            switch self {
            case .compact: return 8
            case .regular: return 11
            case .prominent: return 14
            }
        }

        var spacing: CGFloat {
            switch self {
            case .compact: return 5
            case .regular: return 7
            case .prominent: return 9
            }
        }
    }

    let filled: Int
    let total: Int
    var size: Size = .regular
    var animateIndex: Int? = nil
    @State private var animateScale: CGFloat = 1

    var body: some View {
        HStack(spacing: size.spacing) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                let isFilled = index < filled
                Circle()
                    .fill(isFilled ? Theme.sage : Theme.paper3)
                    .overlay {
                        if !isFilled {
                            Circle().strokeBorder(Theme.ink3.opacity(0.25), lineWidth: 1)
                        }
                    }
                    .frame(width: size.diameter, height: size.diameter)
                    .scaleEffect(animateIndex == index ? animateScale : 1)
            }
        }
        .onAppear {
            guard let animateIndex, animateIndex >= 0, animateIndex < total else { return }
            animateScale = 0.4
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                animateScale = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(filled, total)) of \(total) target-met sessions toward the next level")
    }
}

struct LevelPipsLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            legendItem(filled: false, label: "finish")
            legendItem(filled: true, label: "target met")
        }
        .font(Theme.font(.caption2))
        .foregroundStyle(Theme.ink3)
    }

    private func legendItem(filled: Bool, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(filled ? Theme.sage : Theme.paper3)
                .overlay {
                    if !filled {
                        Circle().strokeBorder(Theme.ink3.opacity(0.25), lineWidth: 1)
                    }
                }
                .frame(width: 7, height: 7)
            Text(label)
        }
    }
}

enum PracticeProgressCopy {
    static func levelUpCaption(done: Int, needed: Int, nextLevel: Int) -> String {
        let remaining = max(0, needed - done)
        if remaining == 0 { return "Level \(nextLevel) unlocked" }
        if remaining == 1 { return "1 target-met session to Level \(nextLevel)" }
        return "\(remaining) target-met sessions to Level \(nextLevel)"
    }
}
