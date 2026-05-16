import SwiftUI

/// A single-line serif-italic tip. Tap to expand inline. Replaces the
/// heavy `PostureTipCard` on Today and the Done state (the full card
/// stays on `PostureHabitsView`).
struct TipLine: View {
    let tip: PostureTip

    @State private var expanded = false

    var body: some View {
        Text("· \(tip.text)")
            .font(.system(.callout, design: .serif).italic())
            .foregroundStyle(Theme.ink2)
            .lineLimit(expanded ? nil : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }
            .accessibilityLabel("Tip: \(tip.text)")
    }
}

#Preview {
    TipLine(tip: PostureTipService.randomTip())
        .padding(24)
        .background(Theme.paper)
}
