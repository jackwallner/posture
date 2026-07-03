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
        ZStack(alignment: .top) {
            Theme.paper.ignoresSafeArea()

            #if HAS_REVENUECAT
            if subscriptions.isLoadingProducts && subscriptions.products.isEmpty {
                loadingState
            } else if subscriptions.products.isEmpty {
                emptyState
            } else {
                paywallContent
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

    /// Single viewport — no scroll. CTA + plans always visible on one screen.
    private var paywallContent: some View {
        VStack(spacing: 10) {
            header
            trustStrip
            if selectedTrialLabel != nil {
                trialTimeline
            } else {
                compactFeatureList
            }
            planCards
            Spacer(minLength: 0)
            purchaseBlock
            legalFooter
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 48 : 16)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    /// Trial label ("7-day free trial") for the current selection, nil when the
    /// selection has no usable intro offer (lifetime, or trial already spent).
    private var selectedTrialLabel: String? {
        #if HAS_REVENUECAT
        guard let package = selectedPackage,
              package.posturePackageKind != .lifetime,
              subscriptions.isEligibleForIntroOffer(package) else { return nil }
        return package.postureIntroOfferLabel
        #else
        return nil
        #endif
    }

    /// "How your free trial works" — the timeline that spells out the deal:
    /// everything unlocked today, a reminder before it ends, nothing charged
    /// until then. Lifts trial conversion and cuts surprise-charge complaints.
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "lock.open.fill",
                title: "Today",
                text: "Unlock coaching, drift rhythm, and full history, free.",
                showsLine: true
            )
            timelineRow(
                icon: "bell.fill",
                title: reminderTitle,
                text: "We remind you before the trial ends. Standing taller yet?",
                showsLine: true
            )
            timelineRow(
                icon: "star.fill",
                title: trialEndTitle,
                text: "First charge, only if you keep it. Cancel before then and pay nothing.",
                showsLine: false
            )
        }
        .padding(14)
        .background(Theme.sageTint.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reminderTitle: String {
        guard let days = trialDays else { return "Reminder" }
        return "Day \(max(1, days - 2))"
    }

    private var trialEndTitle: String {
        guard let days = trialDays else { return "Trial ends" }
        return "Day \(days)"
    }

    private func timelineRow(icon: String, title: String, text: String, showsLine: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 24, height: 24)
                    .background(Theme.sage, in: Circle())
                if showsLine {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.sage.opacity(0.35))
                        .frame(width: 2, height: 14)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsLine ? 6 : 0)
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POSTURE+")
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text(headlineText)
                .font(Theme.displaySerif(26))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(subtitleText)
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
    }

    /// Under the trial headline, anchor the "then $X" price so the cost after the
    /// free week is clear up front (not buried in the fine print).
    private var subtitleText: String {
        #if HAS_REVENUECAT
        if let package = selectedPackage,
           package.posturePackageKind != .lifetime,
           subscriptions.isEligibleForIntroOffer(package) {
            return "Then \(package.posturePriceLabel), cancel anytime."
        }
        #endif
        return "Unlock every Posture+ feature."
    }

    private var headlineText: String {
        #if HAS_REVENUECAT
        if let pkg = selectedPackage ?? subscriptions.products.first(where: { $0.posturePackageKind == .yearly }),
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

    private var compactFeatureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactBenefit(icon: "clock.arrow.circlepath", title: "Drift rhythm: see exactly when you slip, hour by hour")
            compactBenefit(icon: "airpods.gen3", title: "AirPods coaching: quiet nudges without glancing at your phone")
            compactBenefit(icon: "calendar", title: "Full history: keep every month, not just seven days")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactBenefit(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.sage)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
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

    // MARK: - Purchase

    private var purchaseBlock: some View {
        VStack(spacing: 8) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(Theme.paper)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.daylight(.primary))
            .disabled(isPurchasing || selectedPackage == nil)

            Text(trialReassuranceLine ?? " ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.sage)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 18)
                .opacity(trialReassuranceLine == nil ? 0 : 1)
                .accessibilityHidden(trialReassuranceLine == nil)

            Text(disclosureText ?? " ")
                .font(.caption2)
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.9)
                .frame(minHeight: 56, alignment: .top)
                .opacity(disclosureText == nil ? 0 : 1)
                .accessibilityHidden(disclosureText == nil)

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
        }
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
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 30, height: 30)
                    .background(Theme.paper2, in: Circle())
                    // Pad the hit area out past the visible chip so the whole
                    // top-right corner closes the sheet — the bare glyph was a
                    // ~13pt target that routinely missed.
                    .padding(12)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }

    private var offlinePlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            trustStrip
            compactFeatureList
            Spacer()
            Text("Connect to load plans")
                .font(.caption)
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
            legalFooter
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 48 : 20)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Copy

    private var ctaTitle: String {
        #if HAS_REVENUECAT
        guard let package = selectedPackage else { return "Continue" }
        if package.posturePackageKind == .lifetime { return "Unlock Lifetime" }
        // Name the trial length in the button — answers "what am I agreeing to?"
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.postureIntroOfferLabel {
            return "Start My \(trial.capitalized)"
        }
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

    /// Blinkist-style timeline transparency under the CTA: when the reminder
    /// arrives and when billing starts. Lifts trial conversion, cuts complaints.
    private var trialReassuranceLine: String? {
        #if HAS_REVENUECAT
        guard let package = selectedPackage,
              subscriptions.isEligibleForIntroOffer(package),
              let days = trialDays else { return nil }
        let reminderDay = max(1, days - 2)
        return "No payment today · Reminder day \(reminderDay) · Billing day \(days)"
        #else
        return nil
        #endif
    }

    /// Free-trial length in days, read straight from the intro offer.
    private var trialDays: Int? {
        #if HAS_REVENUECAT
        guard let intro = selectedPackage?.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Actions

    #if HAS_REVENUECAT
    private func selectDefaultPackageIfNeeded() {
        #if DEBUG
        if let mode = PaywallScreenshotMode.current, !subscriptions.products.isEmpty {
            switch mode {
            case .monthly:
                selectedPackage = subscriptions.products.first { $0.posturePackageKind == .monthly }
            case .lifetime:
                selectedPackage = subscriptions.products.first { $0.posturePackageKind == .lifetime }
            case .yearly, .trial:
                selectedPackage = subscriptions.products.first { $0.posturePackageKind == .yearly }
            }
            return
        }
        #endif
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
                case .purchased:
                    break
                case .pending:
                    // Ask to Buy / deferred — without this the sheet just
                    // sits there as if the tap did nothing.
                    restoreMessage = "Purchase is pending approval. Posture+ unlocks as soon as it's approved."
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
            .padding(.vertical, 11)
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
