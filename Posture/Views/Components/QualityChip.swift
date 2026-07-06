import SwiftUI

/// Tonal quality pill - lowercase, never shouts. Optional leading dot and
/// trailing score. Daylight's replacement for `PostureLiveIndicator`
/// (kept until the Acknowledgment/QuickScan rebuild migrates its
/// call-site).
struct QualityChip: View {
    let quality: PostureQuality
    var score: Int? = nil
    var labelOverride: String? = nil
    var showsDot: Bool = true

    private var label: String {
        if let labelOverride { return labelOverride }
        switch quality {
        case .good: return "Aligned"
        case .borderline: return "Drifting"
        case .bad: return "Slouching"
        }
    }

    private var tint: Color { Theme.qualityColor(quality) }
    /// The word itself needs the text-grade color - pastel-on-pastel-tint
    /// sat under 2:1. The dot keeps the pastel; it matches the ring/fills.
    private var textTint: Color { Theme.qualityTextColor(quality) }

    private var tintBackground: Color {
        switch quality {
        case .good: return Theme.sageTint
        case .borderline: return Theme.sandTint
        case .bad: return Theme.clayTint
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if showsDot {
                Circle().fill(tint).frame(width: 6, height: 6)
            }
            Text(label)
                .font(Theme.font(.caption, weight: .semibold))
            if let score {
                Text("· \(score)")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
        }
        .foregroundStyle(textTint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tintBackground, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Posture: \(label)")
    }
}

#Preview {
    VStack(spacing: 12) {
        QualityChip(quality: .good, score: 88)
        QualityChip(quality: .borderline, score: 64)
        QualityChip(quality: .bad, score: 41)
    }
    .padding(24)
    .background(Theme.paper)
}
