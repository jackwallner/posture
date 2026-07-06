import SwiftUI

/// The single empty / error / permission pattern. Inline by default;
/// `.fullscreen()` wraps it under a horizon stroke for first-run
/// roadblocks.
struct PostureBanner: View {
    enum Tone { case muted, warn, error }

    let tone: Tone
    let title: String
    let message: String
    var action: (label: String, perform: () -> Void)? = nil

    private var markColor: Color {
        switch tone {
        case .muted, .warn: return Theme.sand
        case .error: return Theme.clay
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(markColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action: action.perform) {
                        Text("\(action.label) →")
                            .font(Theme.font(.caption, weight: .semibold))
                            .foregroundStyle(Theme.goodText)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .dawnCard(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.paper3, lineWidth: 1))
    }
}

/// A horizon-and-sun stroke used above a fullscreen banner.
struct HorizonStroke: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.ink.opacity(0.35))
                .frame(height: 1.5)
            Circle()
                .stroke(Theme.ink.opacity(0.35), lineWidth: 1.5)
                .frame(width: 22, height: 22)
        }
        .frame(width: 64)
        .accessibilityHidden(true)
    }
}

extension PostureBanner {
    /// First-run roadblock variant - banner under a horizon stroke.
    func fullscreen() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HorizonStroke()
            self
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PostureBanner(tone: .muted,
                      title: "No history yet.",
                      message: "A few days of check-ins and patterns appear here.")
        PostureBanner(tone: .warn,
                      title: "Notifications are off.",
                      message: "Reminders won't fire until you allow notifications.",
                      action: ("Allow", {}))
        PostureBanner(tone: .error,
                      title: "Can't hear your AirPods.",
                      message: "Pop them back in to scan, or log this one by hand.",
                      action: ("Check in by hand", {}))
    }
    .padding(24)
    .background(Theme.paper)
}
