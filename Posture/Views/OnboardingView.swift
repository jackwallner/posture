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
        .background(Theme.paper.ignoresSafeArea())
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("POSTURE")
                .font(.caption.weight(.semibold)).tracking(2)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 16)

            Spacer()

            Text("a daylight\nhabit.")
                .font(Theme.displaySerif(48))
                .foregroundStyle(Theme.ink)
                .lineSpacing(2)

            Text("Small check-ins through the day. A quiet record of how you held the shape — nothing more, nothing graded.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 14) {
                row(eyebrow: "01", title: "Calibrate once.",
                    detail: "We learn what your good posture looks like.")
                row(eyebrow: "02", title: "A few nudges a day.",
                    detail: "Pick the cadence — every 15, 30, or 60 minutes.")
                row(eyebrow: "03", title: "Three seconds, no friction.",
                    detail: "Tap a reminder, hold still, done.")
            }
            .padding(.top, 32)

            Spacer()

            Button { step = .airpodsQuestion } label: {
                Text("begin")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    private func row(eyebrow: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink3)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                Text(detail).font(.subheadline).foregroundStyle(Theme.ink2)
            }
        }
    }

    // MARK: - AirPods question

    private var airpodsStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETUP · 1 OF 2")
                .font(.caption.weight(.semibold)).tracking(2)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 16)

            Spacer()

            Text("do you have\nairpods?")
                .font(Theme.displaySerif(40))
                .foregroundStyle(Theme.ink)

            Text("If yes, we'll use their motion sensor — no camera, hands free. Pro extends this into the background while you work.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 4) {
                Text("WORKS WITH")
                    .font(.caption2.weight(.semibold)).tracking(2)
                    .foregroundStyle(Theme.ink3)
                Text("AirPods Pro (1st & 2nd gen) · AirPods (3rd gen) · AirPods 4 with Active Noise Cancellation · AirPods Max")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.top, 20)

            Spacer()

            Button {
                settings.hasAirpods = true
                settings.hasCompletedOnboarding = true
            } label: { Text("yes — link them") }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

            Button {
                settings.hasAirpods = false
                settings.hasCompletedOnboarding = true
            } label: { Text("no — use my camera") }
                .buttonStyle(.plain)
                .daylightCTA(.secondary)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }
}
