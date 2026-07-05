import SwiftUI

/// The Posture+ pitch tab, shown only to non-subscribers. Sells the depth
/// (full ladder, walks, trends, all-day monitoring) and opens the paywall.
/// The tab disappears the moment a purchase lands.
struct ProTabView: View {
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    featureCard(
                        icon: "chevron.up.2",
                        title: "The full level ladder",
                        body: "Free practice tops out at level \(PracticeProgression.freeLevelCap). Posture+ keeps climbing: longer holds, higher bars, and the training dose that rebuilds your default posture."
                    )
                    featureCard(
                        icon: "figure.walk",
                        title: "Posture walks",
                        body: "Take a session outside. Walk-tuned scoring reads how tall you carry yourself, and every walk protects your streak."
                    )
                    featureCard(
                        icon: "clock.arrow.circlepath",
                        title: "Trends, hour by hour",
                        body: "Week-over-week alignment, your strong and slouchy hours, and every monitored minute scored in History."
                    )
                    featureCard(
                        icon: "airpods.gen3",
                        title: "All-day monitoring",
                        body: "Quiet background reading with gentle nudges when you slouch, plus Apple Watch tracking if you wear one."
                    )

                    Button { showingPaywall = true } label: {
                        Text("See plans")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.daylight(.primary))
                    .padding(.top, 6)

                    Text("One subscription, every feature. Cancel anytime.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink3)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .dawnBackground()
            .navigationTitle("Posture+")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "posture_pro_tab")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POSTURE+")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.sage)
            Text("Posture that grows with you.")
                .font(Theme.display(28))
                .foregroundStyle(Theme.ink)
            Text("The daily practice is free forever. Posture+ is the depth on top of it.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
        }
    }

    private func featureCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.font(.body, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }
}
