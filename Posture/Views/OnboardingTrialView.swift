import SwiftUI
#if HAS_REVENUECAT
import RevenueCat
#endif

/// The trial pitch shown once at the end of onboarding right after calibration.
/// Dismissible (the daily practice loop stays free), but tapping the CTA starts
/// the StoreKit purchase sheet directly — no second paywall in between.
struct OnboardingTrialView: View {
    @Environment(GoalSettings.self) private var settings
    @State private var subscriptions = SubscriptionService.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)

            Text("POSTURE+")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.goodText)
            Text(onboardingHeadline)
                .font(Theme.display(40))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text(onboardingSubheadline)
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

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.badText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
            }

            Button(action: startTrialPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .frame(maxWidth: .infinity)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(Theme.paper)
                    }
                }
            }
            .buttonStyle(.daylight(.primary))
            .disabled(isPurchasing || isRestoring || !canStartTrial)

            Button { proceed() } label: {
                Text("Maybe later").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.ghost))
            .padding(.top, 4)
            .disabled(isPurchasing)

            Text(trialDisclosure)
                .font(Theme.font(.caption2))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            legalFooter
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }

    private func proceed() {
        settings.hasSeenOnboardingTrial = true
    }

    // MARK: - Copy

    private var onboardingHeadline: String {
        if let label = trialIntroLabel {
            return "Your \(label)\nis on us."
        }
        return "Your first 7 days\nare on us."
    }

    private var onboardingSubheadline: String {
        "Try everything Posture can do, free for a week. The daily practice stays free forever either way."
    }

    private var ctaTitle: String {
        if let label = trialIntroLabel {
            return "Start my \(label)"
        }
        return "Start my 7 free days"
    }

    private var trialDisclosure: String {
        #if HAS_REVENUECAT
        if let package = directTrialPackage, subscriptions.isEligibleForIntroOffer(package) {
            let trial = package.postureIntroOfferLabel?.capitalized ?? "Free trial"
            return "\(trial), then \(package.posturePriceLabel). Auto-renews unless cancelled at least 24 hours before the trial ends."
        }
        #endif
        return "No charge for 7 days. Cancel anytime."
    }

    #if HAS_REVENUECAT
    private var canStartTrial: Bool {
        directTrialPackage != nil
    }

    private var directTrialPackage: Package? {
        let trialPackages = subscriptions.products.filter { subscriptions.isEligibleForIntroOffer($0) }
        return trialPackages.first { $0.posturePackageKind == .yearly } ?? trialPackages.first
    }

    private var trialIntroLabel: String? {
        directTrialPackage?.postureIntroOfferLabel
    }
    #else
    private var canStartTrial: Bool { false }
    private var trialIntroLabel: String? { nil }
    #endif

    // MARK: - Actions

    private func startTrialPurchase() {
        #if HAS_REVENUECAT
        guard let package = directTrialPackage else {
            errorMessage = "Couldn't load plans. Try again in a moment."
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

    private var legalFooter: some View {
        HStack(spacing: 14) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(Theme.font(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 4) {
                Link("Terms of Use", destination: PaywallLinks.standardEULA)
                Text("·")
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
            }
            .font(Theme.font(.caption2, weight: .semibold))
            .foregroundStyle(Theme.ink3)
        }
    }

    private func benefit(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Theme.sageTint).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goodText)
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
                .foregroundStyle(Theme.goodText)
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
