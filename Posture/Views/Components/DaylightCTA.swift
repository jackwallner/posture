import SwiftUI

/// Daylight's call-to-action treatment. A solid sage pill by default;
/// `ghost` / `secondary` / `tonal` for lower-emphasis actions. Replaces
/// the brand-gradient rectangle used across the old UI.
struct DaylightCTA: ViewModifier {
    enum Style { case primary, secondary, tonal, ghost }
    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            base(content, fg: Theme.paper)
                .background(Theme.sage, in: .capsule)
        case .secondary:
            base(content, fg: Theme.ink)
                .overlay(Capsule().stroke(Theme.paper3, lineWidth: 1))
        case .tonal:
            base(content, fg: Theme.sage)
                .background(Theme.sageTint, in: .capsule)
        case .ghost:
            content
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }

    private func base(_ content: Content, fg: Color) -> some View {
        content
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
    }
}

extension View {
    func daylightCTA(_ style: DaylightCTA.Style = .primary) -> some View {
        modifier(DaylightCTA(style: style))
    }
}

#Preview {
    VStack(spacing: 14) {
        Text("check in now").daylightCTA(.primary)
        Text("quick — 5 seconds").daylightCTA(.secondary)
        Text("see your slouch hours").daylightCTA(.tonal)
        Text("maybe later").daylightCTA(.ghost)
    }
    .padding(24)
    .background(Theme.paper)
}
