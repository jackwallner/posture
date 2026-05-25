import SwiftUI

struct OnboardingView: View {
    @Environment(GoalSettings.self) private var settings

    @State private var step: Step = .welcome

    enum Step { case welcome, airpodsQuestion }

    var body: some View {
        Group {
            switch step {
            case .welcome: welcomeStep
            case .airpodsQuestion: airpodsStep
            }
        }
        .dawnBackground()
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Welcome to Posture.")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 40)

                Text("A kind, hands-free habit. A few quiet check-ins each day, and your phone reads your alignment in seconds.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)

                VStack(spacing: 14) {
                    pillarCard(
                        index: "1",
                        title: "Calibrate once",
                        body: "We learn your aligned posture in five seconds.",
                        accent: Theme.sage
                    )
                    pillarCard(
                        index: "2",
                        title: "A few nudges a day",
                        body: "Pick a cadence that suits your day.",
                        accent: Theme.lavender
                    )
                    pillarCard(
                        index: "3",
                        title: "Three-second check-ins",
                        body: "Tap a reminder, scan, and we'll note where you are.",
                        accent: Theme.sand
                    )
                }
                .padding(.top, 4)

                Spacer(minLength: 24)

                Button { step = .airpodsQuestion } label: { Text("Get Started") }
                    .buttonStyle(.plain)
                    .daylightCTA(.primary)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
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

    // MARK: - AirPods question

    private var airpodsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("One quick question")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 40)

                Text("Do you use AirPods?")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text("Either way works. The front camera handles every check-in on its own. If you have a compatible pair, Posture can also read alignment from their head-motion sensor.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.lavender)
                        Text("WORKS WITH")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.ink2)
                    }
                    Text("AirPods Pro (1st & 2nd gen), AirPods 3rd gen, AirPods 4 with ANC, and AirPods Max.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Theme.lavenderTint)
                )

                Spacer(minLength: 16)

                VStack(spacing: 10) {
                    Button {
                        settings.hasAirpods = true
                        settings.hasCompletedOnboarding = true
                    } label: { Text("Yes, I use AirPods") }
                        .buttonStyle(.plain)
                        .daylightCTA(.primary)

                    Button {
                        settings.hasAirpods = false
                        settings.hasCompletedOnboarding = true
                    } label: { Text("No, use the camera") }
                        .buttonStyle(.plain)
                        .daylightCTA(.secondary)
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }
}
