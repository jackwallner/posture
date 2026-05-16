import SwiftUI

struct PostureLiveIndicator: View {
    let quality: PostureQuality

    private var label: String {
        switch quality {
        case .good: return "Good posture"
        case .borderline: return "Watch your posture"
        case .bad: return "Sit up!"
        }
    }

    private var icon: String {
        switch quality {
        case .good: return "checkmark.circle.fill"
        case .borderline: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
            Text(label)
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.qualityColor(quality), in: .capsule)
        .animation(.easeOut(duration: 0.25), value: quality)
        .accessibilityLabel("Posture: \(label)")
    }
}
