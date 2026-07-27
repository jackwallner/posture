import SwiftUI
#if HAS_REVENUECAT
import RevenueCat
#endif

/// Trial pitch shown after the first completed practice, when the user has felt
/// the core loop and has a concrete result. Dismissible, with the daily practice
/// remaining free. The primary starts the yearly trial directly and falls back
/// to the full plan picker only when products fail to load.
struct OnboardingTrialView: View {
    @Environment(GoalSettings.self) private var settings
    @State private var subscriptions = SubscriptionService.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var showFallbackPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            content
            bottomBar
        }
        .dawnBackground()
        .task {
            #if HAS_REVENUECAT
            subscriptions.trackPaywallImpression(id: "posture_onboarding_trial")
            if subscriptions.products.isEmpty {
                await subscriptions.fetchProducts()
            }
            #endif
        }
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            if isPro { proceed() }
        }
        .sheet(isPresented: $showFallbackPaywall, onDismiss: {
            // If the fallback purchase went through, the onChange handler already
            // called proceed(); nothing else to do here.
        }) {
            #if HAS_REVENUECAT
            PaywallView(paywallImpressionId: "posture_onboarding_trial")
            #endif
        }
    }

    // MARK: - Content (same card chrome as OnboardingView)

    /// Mirrors `OnboardingView.pageScaffold`: a leading-aligned, vertically
    /// centered column that fills the viewport so it reads as one more card in
    /// the flow. Same headline scale, body font, and dawn cards.
    private var content: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(headline)
                        .font(Theme.font(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.ink)

                    Text(subheadline)
                        .font(Theme.font(.body))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)

                    VStack(spacing: 10) {
                        benefitCard(icon: "chevron.up.2", title: "Keep the program growing",
                                    body: "Unlock every level as practices gradually grow from 3 to 15 minutes.")
                        benefitCard(icon: "figure.walk", title: "Add walk mode and trends",
                                    body: "See distance, steps, weekly patterns, and your day hour by hour.")
                        benefitCard(icon: "applewatch", title: "Get optional background nudges",
                                    body: "Use AirPods or Apple Watch for gentle reminders beyond the daily practice.")
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
        }
    }

    // MARK: - CTA stack (primary in the exact Continue slot)

    /// The primary trial CTA sits in the identical bottom-pinned slot as the
    /// onboarding "Continue" button (`OnboardingBottomBar`): the real
    /// Terms/Privacy/Restore footer fills the reserved slot below it, and all
    /// variable content (soft exit, disclosure, error) rides ABOVE the button
    /// where it cannot shift the button's frame.
    private var bottomBar: some View {
        OnboardingBottomBar(
            primaryTitle: ctaTitle,
            isBusy: isPurchasing,
            isDisabled: isPurchasing || isRestoring,
            primaryAction: startTrialPurchase,
            footer: OnboardingLegalFooter(isRestoring: isRestoring, onRestore: startRestore)
        ) {
            VStack(spacing: 10) {
                Button { proceed() } label: {
                    Text("Keep the free practice").frame(maxWidth: .infinity)
                }
                .buttonStyle(.daylight(.ghost))
                .disabled(isPurchasing)

                // Apple 3.1.2 disclosure adjacent to the purchase point: trial
                // length, then the real yearly price, then auto-renew / cancel
                // terms. Price is pulled live from the loaded package.
                if let disclosure = trialDisclosure {
                    Text(disclosure)
                        .font(Theme.font(.caption2))
                        .foregroundStyle(Theme.ink3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.font(.caption2))
                        .foregroundStyle(Theme.badText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func proceed() {
        settings.hasSeenOnboardingTrial = true
        settings.hasSeenIntroPaywall = true
    }

    // MARK: - Copy

    private var headline: String {
        "Keep building on today."
    }

    private var subheadline: String {
        "Your daily practice is free forever. Try the full program for 7 days to unlock every level, deeper trends, walk mode, and optional background nudges."
    }

    /// Leads with the yearly free-trial offer when eligible so the primary reads
    /// as "start trial", matching the direct-purchase CTAs elsewhere.
    private var ctaTitle: String {
        if let label = trialIntroLabel {
            return "Start \(label)"
        }
        return "Start 7-day free trial"
    }

    /// Full Apple-3.1.2 auto-renew disclosure for the trial-led yearly plan,
    /// mirroring StatScout's `yearlyCTADisclosureText` structure: trial length,
    /// then live price, then renew/cancel terms.
    private var trialDisclosure: String? {
        #if HAS_REVENUECAT
        guard let package = directTrialPackage else { return nil }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions."
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.postureIntroOfferLabel {
            return "\(trial.capitalized), then \(package.posturePriceLabel). \(renew)"
        }
        return "\(package.posturePriceLabel). \(renew)"
        #else
        return nil
        #endif
    }

    #if HAS_REVENUECAT
    /// The yearly trial package is the one-tap conversion target. `PaywallView`
    /// is only the fallback when this is nil (products didn't load).
    private var directTrialPackage: Package? {
        let trialPackages = subscriptions.products.filter { subscriptions.isEligibleForIntroOffer($0) }
        return trialPackages.first { $0.posturePackageKind == .yearly } ?? trialPackages.first
    }

    private var trialIntroLabel: String? {
        directTrialPackage?.postureIntroOfferLabel
    }
    #else
    private var trialIntroLabel: String? { nil }
    #endif

    // MARK: - Actions

    private func startTrialPurchase() {
        #if HAS_REVENUECAT
        guard let package = directTrialPackage else {
            // Products failed to load — hand off to the full paywall rather than
            // dead-ending the onboarding step (Apple confirm needs a product).
            showFallbackPaywall = true
            return
        }
        errorMessage = nil
        isPurchasing = true
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased, .pending:
                    break
                case .cancelled:
                    errorMessage = nil
                }
            } catch {
                errorMessage = "Couldn't start your trial. Please try again."
            }
        }
        #else
        showFallbackPaywall = true
        #endif
    }

    private func startRestore() {
        #if HAS_REVENUECAT
        errorMessage = nil
        isRestoring = true
        Task { @MainActor in
            defer { isRestoring = false }
            await subscriptions.restorePurchases()
            if subscriptions.isProSubscriber {
                proceed()
            } else {
                errorMessage = subscriptions.lastError ?? "No purchases found to restore."
            }
        }
        #endif
    }

    // MARK: - Building blocks

    /// Benefit row styled to match `OnboardingView`'s `cueCard` exactly (same
    /// 36pt sage-tint icon chip, title/body fonts, and dawn card).
    private func benefitCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.goodText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(.body, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .dawnCard()
    }
}
