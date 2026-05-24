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
                Text("hello.")
                    .font(.system(size: 56, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 40)

                Text("Posture is a kind, hands-free habit. A few quiet check-ins each day — your phone or AirPods read alignment in seconds.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink2)
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

                Button { step = .airpodsQuestion } label: { Text("get started") }
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
                    .foregroundStyle(Theme.ink2)
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
                Text("01 of 01")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 40)

                Text("do you use AirPods?")
                    .font(.system(size: 38, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text("If you have a compatible pair, Posture reads alignment from their head-motion sensor. No AirPods? We'll use the front camera instead — pick whichever fits your day.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.lavender)
                        Text("works with")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.ink3)
                    }
                    Text("AirPods Pro (1st & 2nd gen) · AirPods 3rd gen · AirPods 4 with ANC · AirPods Max")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Theme.ink2)
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
                    } label: { Text("yes — calibrate with AirPods") }
                        .buttonStyle(.plain)
                        .daylightCTA(.primary)

                    Button {
                        settings.hasAirpods = false
                        settings.hasCompletedOnboarding = true
                    } label: { Text("no — use iPhone camera") }
                        .buttonStyle(.plain)
                        .daylightCTA(.secondary)
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
    }
}
