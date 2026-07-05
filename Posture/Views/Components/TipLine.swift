import SwiftUI

/// A compact tip row. Shows the whole tip — a truncated tip teaches nothing —
/// with a small leading icon so it reads as a tip, not lost body copy.
struct TipLine: View {
    let tip: PostureTip

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.sand)
                .padding(.top, 2)
            Text(tip.text)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Tip: \(tip.text)")
    }
}

#Preview {
    TipLine(tip: PostureTipService.randomTip())
        .padding(24)
        .background(Theme.paper)
}
