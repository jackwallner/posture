#if DEBUG
import SwiftUI
#if HAS_REVENUECAT
import RevenueCat
#endif

struct PaywallScreenshotHarness: View {
    let mode: PaywallScreenshotMode
    @State private var subscriptions = SubscriptionService.shared

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if mode == .trial {
                trialBackdrop {
                    PaywallView(displayCloseButton: true, paywallImpressionId: "snapshot_trial")
                }
            } else {
                PaywallView(displayCloseButton: false, paywallImpressionId: "snapshot")
            }
        }
        .preferredColorScheme(.light)
        .task {
            #if HAS_REVENUECAT
            if subscriptions.products.isEmpty { await subscriptions.fetchProducts() }
            #endif
        }
    }

    private func trialBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            VStack {
                Spacer()
                content()
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.78)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
        }
    }
}
#endif
