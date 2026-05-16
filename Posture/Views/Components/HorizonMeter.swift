import SwiftUI

/// A horizon line with a sun-dot that tilts to imply alignment. Replaces
/// the SF-Symbol checkmark/triangle/octagon on the Acknowledgment Done
/// state. Tilt eases over 600ms after the quality resolves.
struct HorizonMeter: View {
    let quality: PostureQuality?

    @State private var tilt: Double = 0

    private var targetTilt: Double {
        switch quality {
        case .good: return -2
        case .borderline: return 5
        case .bad: return 12
        case nil: return 0
        }
    }

    private var dotColor: Color {
        switch quality {
        case .good: return Theme.sage
        case .borderline: return Theme.sand
        case .bad: return Theme.clay
        case nil: return Theme.ink3
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.ink.opacity(0.35))
                .frame(height: 1.5)
            ZStack {
                Circle()
                    .fill(dotColor.opacity(0.22))
                    .frame(width: 38, height: 38)
                Circle()
                    .fill(dotColor)
                    .frame(width: 22, height: 22)
            }
        }
        .rotationEffect(.degrees(tilt))
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) { tilt = targetTilt }
        }
        .onChange(of: quality) { _, _ in
            withAnimation(.easeInOut(duration: 0.6)) { tilt = targetTilt }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 40) {
        HorizonMeter(quality: .good)
        HorizonMeter(quality: .borderline)
        HorizonMeter(quality: .bad)
        HorizonMeter(quality: nil)
    }
    .padding(40)
    .background(Theme.paper)
}
