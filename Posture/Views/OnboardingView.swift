import SwiftUI

/// Single-step welcome: this is an AirPods-based posture app. The previous
/// "do you use AirPods?" branch was removed because the camera path no
/// longer ships — tapping Get Started flips the install state and the
/// next gate (AirPods calibration) handles the "do you actually have
/// compatible AirPods" question with its own waiting / unsupported UI.
struct OnboardingView: View {
    @Environment(GoalSettings.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Welcome to Posture.")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 40)

                Text("A kind, hands-free habit for AirPods. Your earbuds read your alignment without a glance at the phone.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)

                VStack(spacing: 14) {
                    pillarCard(
                        index: "1",
                        title: "Pop in your AirPods",
                        body: "AirPods Pro, AirPods 3, AirPods 4 with ANC, or AirPods Max.",
                        accent: Theme.lavender
                    )
                    pillarCard(
                        index: "2",
                        title: "Calibrate once",
                        body: "Sit upright, hold still. We learn your aligned posture in five seconds.",
                        accent: Theme.sage
                    )
                    pillarCard(
                        index: "3",
                        title: "Quiet nudges all day",
                        body: "We notice when you drift, gently — no screens, no scolding.",
                        accent: Theme.sand
                    )
                }
                .padding(.top, 4)

                Spacer(minLength: 24)

                Button {
                    settings.hasAirpods = true
                    settings.hasCompletedOnboarding = true
                } label: { Text("Get Started") }
                    .buttonStyle(.plain)
                    .daylightCTA(.primary)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .dawnBackground()
    }

    private func pillarCard(index: String, title: String, body: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Text(index)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .dawnCard()
    }
}
