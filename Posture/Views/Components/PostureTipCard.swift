import SwiftUI

/// A compact card displaying a single posture education tip.
struct PostureTipCard: View {
    let tip: PostureTip

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconForCategory(tip.category))
                .font(Theme.font(.title3))
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)

            Text(tip.text)
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .dawnCard()
    }

    private func iconForCategory(_ category: TipCategory) -> String {
        switch category {
        case .ergonomics: return "desktopcomputer"
        case .habit: return "arrow.triangle.2.circlepath"
        case .stretch: return "figure.cooldown"
        case .awareness: return "brain"
        }
    }
}

#Preview {
    PostureTipCard(tip: PostureTipService.randomTip())
        .padding()
        .background(Theme.background)
}
