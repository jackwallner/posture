import SwiftUI
#if HAS_REVENUECAT
import RevenueCat
#endif

/// Apple-required legal links on the paywall (3.1.2).
enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/posture/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

/// Native Posture+ paywall. Purchases flow through `SubscriptionService.purchase`
/// → `Purchases.shared.purchase` so RevenueCat records transactions as before.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptions = SubscriptionService.shared

    var displayCloseButton: Bool = true
    /// RevenueCat custom paywall impression id — pass per entry point (`posture_settings_sheet`, etc.).
    var paywallImpressionId: String = "posture_sheet"

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()

            #if HAS_REVENUECAT
            if subscriptions.isLoadingProducts && subscriptions.products.isEmpty {
                loadingState
            } else if subscriptions.products.isEmpty {
                emptyState
            } else {
                content
                stickyCTA
            }
            #else
            offlinePlaceholder
            #endif

            if displayCloseButton {
                closeButton
            }
        }
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            if isPro { dismiss() }
        }
        .task {
            #if HAS_REVENUECAT
            subscriptions.trackPaywallImpression(id: paywallImpressionId)
            if subscriptions.products.isEmpty {
                await subscriptions.fetchProducts()
            }
            selectDefaultPackageIfNeeded()
            #else
            AnalyticsService.paywallShown()
            #endif
        }
        #if HAS_REVENUECAT
        .onChange(of: subscriptions.products.count) { _, _ in
            selectDefaultPackageIfNeeded()
        }
        #endif
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Theme.sage)
            Text("loading plans…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
            Spacer()
            legalFooter
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.ink3)
            Text("couldn't load plans")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink2)
            Text(subscriptions.lastError ?? "Check your connection and try again.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("try again") {
                Task {
                    await subscriptions.fetchProducts()
                    selectDefaultPackageIfNeeded()
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.sage)
            Spacer()
            legalFooter
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                trustStrip
                featureList
                backgroundAudioNote
                planCards
            }
            .padding(.horizontal, 24)
            .padding(.top, displayCloseButton ? 52 : 20)
            .padding(.bottom, stickyCTAReservedSpace)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("POSTURE+")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text(headlineText)
                .font(Theme.displaySerif(32))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Stop guessing when you slip. See the hours you drift, hold a streak, and keep every month.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headlineText: String {
        #if HAS_REVENUECAT
        if let pkg = selectedPackage,
           subscriptions.isEligibleForIntroOffer(pkg),
           let trial = pkg.postureIntroOfferLabel {
            return "Try Posture+\n\(trial)."
        }
        #endif
        return "Build the posture\nyou keep."
    }

    private var trustStrip: some View {
        HStack(spacing: 14) {
            trustItem(icon: "iphone.gen3.radiowaves.left.and.right", label: "On-device")
            Divider().frame(height: 14).background(Theme.paper3)
            trustItem(icon: "lock.shield", label: "Private by default")
            Divider().frame(height: 14).background(Theme.paper3)
            trustItem(icon: "moon.stars", label: "No ads, ever")
        }
        .frame(maxWidth: .infinity)
    }

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Theme.sage)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.ink2)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 0) {
            benefitRow(
                icon: "clock.arrow.circlepath",
                title: "See your day, hour by hour",
                subtitle: "The 24-hour rhythm shows exactly when you drift, like after lunch or that 3pm meeting."
            )
            benefitRow(
                icon: "airpods.gen3",
                title: "Quiet AirPods background coaching",
                subtitle: "Wear your Pros and Posture nudges you without a glance at the phone."
            )
            benefitRow(
                icon: "calendar",
                title: "Keep every month, not just a week",
                subtitle: "Free shows your last 7 days. Posture+ keeps the whole story, so streaks actually mean something.",
                isLast: true
            )
        }
        .padding(.top, 2)
    }

    /// Honesty on the conversion screen: the background feature above is the
    /// silent-tone mechanism that lights the orange dot. Keeps the "private"
    /// trust strip from reading as deceptive next to it.
    private var backgroundAudioNote: some View {
        Text("Background coaching keeps the AirPods sensor awake with a silent tone, so iOS shows an orange dot. No audio is recorded, and motion stays on your device.")
            .font(.caption2)
            .foregroundStyle(Theme.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }

    #if HAS_REVENUECAT
    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(subscriptions.products, id: \.identifier) { package in
                PosturePlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: subscriptions.isEligibleForIntroOffer(package),
                    isBestValue: package.posturePackageKind == .yearly,
                    savingsPercent: savingsPercent(for: package)
                ) {
                    selectedPackage = package
                }
            }
        }
    }
    #else
    private var planCards: some View { EmptyView() }
    #endif

    // MARK: - Sticky CTA

    private var stickyCTAReservedSpace: CGFloat { 170 }

    @ViewBuilder
    private var stickyCTA: some View {
        VStack(spacing: 10) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(Theme.paper)
                    }
                }
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .disabled(isPurchasing || selectedPackage == nil)

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.clay)
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }

            legalFooter
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.paper.opacity(0), Theme.paper, Theme.paper],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    /// Restore + legal links. Required by 3.1.2 to be present on the paywall in
    /// EVERY state — including while products are still loading or failed to
    /// load — so it lives outside the product-loaded branch.
    private var legalFooter: some View {
        HStack(spacing: 14) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 4) {
                Link("Terms of Use", destination: PaywallLinks.standardEULA)
                Text("·")
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.ink3)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink3)
                        .padding(20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Spacer()
        }
    }

    private var offlinePlaceholder: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                trustStrip
                featureList
                Text("Connect to load plans")
                    .font(.caption)
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity)
                legalFooter
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, displayCloseButton ? 52 : 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Copy

    private var ctaTitle: String {
        #if HAS_REVENUECAT
        guard let package = selectedPackage else { return "Continue" }
        if package.posturePackageKind == .lifetime { return "Unlock Lifetime" }
        if subscriptions.isEligibleForIntroOffer(package) { return "Start Free Trial" }
        return "Start Posture+"
        #else
        return "Continue"
        #endif
    }

    private var disclosureText: String? {
        #if HAS_REVENUECAT
        guard let package = selectedPackage else { return nil }
        let price = package.posturePriceLabel
        if package.posturePackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings."
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.postureIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
        #else
        return nil
        #endif
    }

    // MARK: - Actions

    #if HAS_REVENUECAT
    private func selectDefaultPackageIfNeeded() {
        guard selectedPackage == nil, !subscriptions.products.isEmpty else { return }
        selectedPackage = subscriptions.products.first { $0.posturePackageKind == .yearly }
            ?? subscriptions.products.first
    }

    /// Computed annual savings vs. the equivalent monthly run-rate, when both packages exist.
    private func savingsPercent(for package: Package) -> Int? {
        guard package.posturePackageKind == .yearly else { return nil }
        guard let monthly = subscriptions.products.first(where: { $0.posturePackageKind == .monthly }) else { return nil }
        let yearlyPrice = package.storeProduct.price as Decimal
        let monthlyPrice = monthly.storeProduct.price as Decimal
        guard monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let yearlyAtMonthly = monthlyPrice * 12
        guard yearlyAtMonthly > yearlyPrice else { return nil }
        let saved = (yearlyAtMonthly - yearlyPrice) / yearlyAtMonthly
        return Int((saved as NSDecimalNumber).doubleValue * 100)
    }

    private func startPurchase() {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased, .pending:
                    break
                case .cancelled:
                    errorMessage = nil
                }
            } catch {
                errorMessage = "Purchase didn't complete. Please try again."
            }
        }
    }

    private func startRestore() {
        errorMessage = nil
        restoreMessage = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            await subscriptions.restorePurchases()
            if !subscriptions.isProSubscriber {
                restoreMessage = subscriptions.lastError ?? "No purchases found to restore."
            }
        }
    }
    #else
    private func startPurchase() {}
    private func startRestore() {}
    #endif

    private func benefitRow(icon: String, title: String, subtitle: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.sage)
                    .frame(width: 24, height: 24, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            if !isLast { Divider().background(Theme.paper3) }
        }
    }
}

#if HAS_REVENUECAT
private struct PosturePlanCard: View {
    let package: Package
    let isSelected: Bool
    let showsTrialBadge: Bool
    let isBestValue: Bool
    let savingsPercent: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.sage : Theme.ink3.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.sage)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(package.postureDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let savings = savingsPercent {
                            Text("SAVE \(savings)%")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.paper)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.sage, in: Capsule())
                        } else if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.paper)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.sage, in: Capsule())
                        }
                    }
                    if let secondary = secondaryLine {
                        Text(secondary)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.ink3)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.posturePriceLabel)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                    if let perWeek = perWeekLabel {
                        Text(perWeek)
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.sage : Theme.paper3, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var secondaryLine: String? {
        if showsTrialBadge, let trial = package.postureIntroOfferLabel {
            return trial.capitalized
        }
        if package.posturePackageKind == .lifetime {
            return "Pay once · never renews"
        }
        return nil
    }

    /// "≈ $0.27/week" anchor — annual feels cheap when broken down.
    private var perWeekLabel: String? {
        guard let period = package.storeProduct.subscriptionPeriod else { return nil }
        let weeks: Decimal
        switch period.unit {
        case .year: weeks = Decimal(period.value) * Decimal(52)
        case .month: weeks = Decimal(period.value) * Decimal(string: "4.345")!
        default: return nil
        }
        guard weeks > 1 else { return nil }
        let price = package.storeProduct.price as Decimal
        let perWeek = price / weeks
        let formatter = package.storeProduct.priceFormatter ?? defaultPriceFormatter
        guard let formatted = formatter.string(from: perWeek as NSDecimalNumber) else { return nil }
        return "\(formatted) / week"
    }

    private var defaultPriceFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }
}

#endif
