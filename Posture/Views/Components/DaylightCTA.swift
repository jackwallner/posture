import SwiftUI

/// Soft pastel CTA - rounded card, gentle shadow on primary, white text on
/// sage. Secondary is a lavender-tinted card. Tonal mirrors a quiet
/// hint chip. Ghost is plain text for tertiary moves.
struct DaylightCTA: ViewModifier {
    enum Style { case primary, secondary, tonal, ghost }
    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            base(content, fg: Color.white)
                .background(
                    RoundedRectangle(cornerRadius: Theme.ctaRadius, style: .continuous)
                        .fill(Theme.sage)
                )
                .shadow(color: Theme.sage.opacity(0.35), radius: 14, y: 6)
        case .secondary:
            base(content, fg: Theme.ink)
                .background(
                    RoundedRectangle(cornerRadius: Theme.ctaRadius, style: .continuous)
                        .fill(Theme.lavenderTint)
                )
        case .tonal:
            base(content, fg: Theme.sage)
                .background(
                    RoundedRectangle(cornerRadius: Theme.ctaRadius, style: .continuous)
                        .fill(Theme.sageTint)
                )
        case .ghost:
            content
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
    }

    private func base(_ content: Content, fg: Color) -> some View {
        content
            .font(Theme.font(.headline, weight: .semibold))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
    }
}

extension View {
    func daylightCTA(_ style: DaylightCTA.Style = .primary) -> some View {
        modifier(DaylightCTA(style: style))
    }
}

/// Button style that applies the CTA chrome to the *label*, so the whole
/// styled card is the hit target. Applying `.daylightCTA` outside a
/// `Button` leaves only the bare text tappable - the visible 56-pt card
/// ignores any touch that misses the label (TF feedback: "check in now
/// does nothing").
struct DaylightButtonStyle: ButtonStyle {
    let style: DaylightCTA.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(DaylightCTA(style: style))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == DaylightButtonStyle {
    static func daylight(_ style: DaylightCTA.Style = .primary) -> DaylightButtonStyle {
        DaylightButtonStyle(style: style)
    }
}

#Preview {
    VStack(spacing: 14) {
        Text("Check in now").daylightCTA(.primary)
        Text("Quick · 5 seconds").daylightCTA(.secondary)
        Text("See your slouch hours").daylightCTA(.tonal)
        Text("Maybe later").daylightCTA(.ghost)
    }
    .padding(24)
    .background(Theme.paper)
}
