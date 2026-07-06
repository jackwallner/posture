import SwiftUI

/// The "7 days on us" trial pitch, shown once at the end of onboarding right
/// after the user has invested in calibration - the highest-intent moment to
/// convert. It's dismissible (the daily practice loop stays free forever), but
/// this is where trial-led plans convert best. The real purchase happens in
/// `PaywallView`, opened as a sheet, so all the RevenueCat plumbing is reused.
struct OnboardingTrialView: View {
    @Environment(GoalSettings.self) private var settings
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)

            Text("POSTURE+")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.sage)
            Text("Your first 7 days\nare on us.")
                .font(Theme.display(40))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text("Try everything Posture can do, free for a week. The daily practice stays free forever either way.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 12)

            VStack(spacing: 12) {
                benefit(icon: "chevron.up.2", title: "The full level ladder",
                        body: "Longer holds, higher bars, the dose that rebuilds your posture.")
                benefit(icon: "figure.walk", title: "Walk mode",
                        body: "Distance, steps, and how tall you carry your head.")
                benefit(icon: "clock.arrow.circlepath", title: "Trends & all-day monitoring",
                        body: "Your day scored hour by hour, plus Apple Watch nudges.")
            }
            .padding(.top, 22)

            Spacer(minLength: 16)

            trialTimeline

            Spacer(minLength: 16)

            Button { showingPaywall = true } label: {
                Text("Start my 7 free days").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))

            Button { proceed() } label: {
                Text("Maybe later").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.ghost))
            .padding(.top, 4)

            Text("No charge for 7 days. Cancel anytime.")
                .font(Theme.font(.caption2))
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dawnBackground()
        .sheet(isPresented: $showingPaywall) {
            PaywallView(paywallImpressionId: "posture_onboarding_trial")
        }
        // The sheet dismisses itself on purchase; catch the state flip here so
        // we advance into the app rather than back to this pitch.
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            if isPro { proceed() }
        }
    }

    private func proceed() {
        settings.hasSeenOnboardingTrial = true
    }

    private func benefit(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Theme.sageTint).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// The three-beat "how the trial works" reassurance that lifts conversion
    /// and cuts surprise-charge complaints.
    private var trialTimeline: some View {
        HStack(alignment: .top, spacing: 0) {
            timelineStep(icon: "lock.open.fill", title: "Today", body: "Full access, free")
            timelineConnector
            timelineStep(icon: "bell.fill", title: "Day 5", body: "We'll remind you")
            timelineConnector
            timelineStep(icon: "checkmark.seal.fill", title: "Day 7", body: "Trial ends")
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.sageTint.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }

    private func timelineStep(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.sage)
            Text(title)
                .font(Theme.font(.caption, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(Theme.font(.caption2))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var timelineConnector: some View {
        Rectangle()
            .fill(Theme.sage.opacity(0.35))
            .frame(height: 1.5)
            .frame(width: 16)
            .padding(.top, 8)
    }
}
