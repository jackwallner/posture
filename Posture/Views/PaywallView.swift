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
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                trustStrip
                featureList
                YourJulyPostcard()
                #if HAS_REVENUECAT
                if showTrialTimeline {
                    TrialTimelineStrip(trialLabel: selectedPackage?.postureIntroOfferLabel ?? "3-day free trial")
                }
                #endif
                planCards
            }
            .padding(.horizontal, 24)
            .padding(.top, displayCloseButton ? 52 : 24)
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
        if let pkg = selectedPackage, subscriptions.isEligibleForIntroOffer(pkg) {
            return "Try Posture+\nfree for 3 days."
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
                subtitle: "The 24-hour rhythm shows exactly when you drift — after lunch, late afternoon, that 3pm meeting."
            )
            benefitRow(
                icon: "airpods.gen3",
                title: "Quiet AirPods background coaching",
                subtitle: "Wear your Pros and Posture nudges you without a glance at the phone."
            )
            benefitRow(
                icon: "calendar",
                title: "Keep every month, not just a week",
                subtitle: "Free shows your last 7 days. Posture+ keeps the whole story — so streaks actually mean something.",
                isLast: true
            )
        }
        .padding(.top, 2)
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

    private var stickyCTAReservedSpace: CGFloat { 200 }

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

            HStack(spacing: 14) {
                Button(action: startRestore) {
                    Text(isRestoring ? "restoring…" : "Restore")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.ink2)
                }
                .buttonStyle(.plain)
                .disabled(isRestoring || isPurchasing)

                Link("Terms", destination: PaywallLinks.standardEULA)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
                Link("Privacy", destination: PaywallLinks.privacyPolicy)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
            }
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
            VStack(alignment: .leading, spacing: 18) {
                header
                trustStrip
                featureList
                YourJulyPostcard()
                Text("Connect to load plans")
                    .font(.caption)
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity)
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
        if subscriptions.isEligibleForIntroOffer(package) { return "Start my 3 days free" }
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
            return "\(price). One-time purchase. No subscription."
        }
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.postureIntroOfferLabel {
            return "\(trial.capitalized), then \(price). Auto-renews. Cancel anytime in Settings — no charge if you cancel before day 3."
        }
        return "\(price). Auto-renews. Cancel anytime in Settings."
        #else
        return nil
        #endif
    }

    #if HAS_REVENUECAT
    private var showTrialTimeline: Bool {
        guard let package = selectedPackage else { return false }
        return subscriptions.isEligibleForIntroOffer(package) && package.posturePackageKind != .lifetime
    }
    #endif

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
            return "Pay once · keep forever"
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

/// Three-step trial timeline — proven to reduce purchase anxiety:
/// users see the "reminder before charge" date, so the trial reads as zero-risk.
private struct TrialTimelineStrip: View {
    let trialLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW THE FREE TRIAL WORKS")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)

            HStack(alignment: .top, spacing: 0) {
                step(
                    color: Theme.sage,
                    title: "Today",
                    body: "Unlock everything. No charge."
                )
                connector
                step(
                    color: Theme.sand,
                    title: "Day 2",
                    body: "We send a heads-up before the trial ends."
                )
                connector
                step(
                    color: Theme.ink2,
                    title: "Day 3",
                    body: "Trial ends. Cancel anytime in Settings."
                )
            }
        }
        .padding(16)
        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.paper3, lineWidth: 1))
    }

    private var connector: some View {
        Rectangle()
            .fill(Theme.paper3)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func step(color: Color, title: String, body: String) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Theme.paper2, lineWidth: 3))
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(.caption2)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif

/// A synthetic 30-day "preview" of a Pro month — deliberately not real
/// data (avoids any before/after medical-claim reading). A 14-day
/// contiguous stretch is outlined.
private struct YourJulyPostcard: View {
    private let bars: [PostureQuality] = {
        var out: [PostureQuality] = []
        for i in 0..<30 {
            switch i {
            case 3, 9, 21: out.append(.bad)
            case 1, 7, 14, 24, 27: out.append(.borderline)
            default: out.append(.good)
            }
        }
        return out
    }()

    private let stretchRange = 10...23

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR JULY · A PREVIEW")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Text("84% aligned")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sage)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<30, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.qualityColor(bars[i]))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(bars[i]))
                }
            }
            .frame(height: 56)
            .overlay(alignment: .leading) { stretchOutline }

            HStack {
                Text("JUL 1").font(.caption2).foregroundStyle(Theme.ink3)
                Spacer()
                Text("14 DAY STRETCH").font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink2)
                Spacer()
                Text("JUL 30").font(.caption2).foregroundStyle(Theme.ink3)
            }
        }
        .padding(16)
        .dawnCard(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.paper3, lineWidth: 1))
    }

    private var stretchOutline: some View {
        GeometryReader { geo in
            let barW = geo.size.width / 30
            let x = barW * CGFloat(stretchRange.lowerBound)
            let w = barW * CGFloat(stretchRange.count)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.ink, lineWidth: 1.5)
                .frame(width: w, height: geo.size.height + 6)
                .offset(x: x - 3, y: -3)
        }
    }

    private func barHeight(_ q: PostureQuality) -> CGFloat {
        switch q {
        case .good: return 56
        case .borderline: return 38
        case .bad: return 22
        }
    }
}
