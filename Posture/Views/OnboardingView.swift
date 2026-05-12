import SwiftUI

struct OnboardingView: View {
    @Environment(GoalSettings.self) private var settings

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.stand")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Theme.brandGradient)

            Text("Stand tall, every day.")
                .font(Theme.bigNumber(34))
                .multilineTextAlignment(.center)

            Text("Posture builds a daily habit of better posture using your iPhone, AirPods, and Apple Watch — Duolingo-style streaks included.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            FeatureRow(icon: "camera.viewfinder", title: "Calibrate once", detail: "We learn what your good posture looks like.")
            FeatureRow(icon: "timer", title: "1-minute daily session", detail: "Short, focused, and grows with your streak.")
            FeatureRow(icon: "flame.fill", title: "Build a streak", detail: "Don't break the chain. Earn freezes for off days.")

            Spacer()

            Button {
                settings.hasCompletedOnboarding = true
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
