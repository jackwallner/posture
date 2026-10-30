import Foundation
import Observation
#if HAS_REVENUECAT
import RevenueCat
#endif

enum PurchaseState {
    case purchased
    case cancelled
    case pending
}

#if HAS_REVENUECAT
enum PosturePackageKind: Int {
    // Yearly first so the trial-led annual plan is the default selection and
    // sits at the top of the card stack (matches the hard-paywall ordering).
    case yearly = 0
    case monthly = 1
    case lifetime = 2
    case other = 3
}

extension PosturePackageKind {
    init(package: Package) {
        switch package.packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .yearly
        case .monthly:
            self = .monthly
        default:
            let ids = [package.identifier, package.storeProduct.productIdentifier].map { $0.lowercased() }
            if ids.contains(where: { $0.contains("lifetime") }) {
                self = .lifetime
            } else if ids.contains(where: { $0.contains("yearly") || $0.contains("annual") }) {
                self = .yearly
            } else if ids.contains(where: { $0.contains("monthly") }) {
                self = .monthly
            } else {
                self = .other
            }
        }
    }
}

extension Package {
    var posturePackageKind: PosturePackageKind {
        PosturePackageKind(package: self)
    }

    var postureDisplayName: String {
        switch posturePackageKind {
        case .lifetime: return String(localized: "Lifetime")
        case .yearly: return String(localized: "Yearly")
        case .monthly: return String(localized: "Monthly")
        case .other: return storeProduct.localizedTitle
        }
    }

    var posturePriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else {
            return storeProduct.localizedPriceString
        }
        let price = storeProduct.localizedPriceString
        let n = period.value
        switch (period.unit, n == 1) {
        case (.day, true): return String(localized: "\(price) / day")
        case (.day, false): return String(localized: "\(price) / \(n) days")
        case (.week, true): return String(localized: "\(price) / week")
        case (.week, false): return String(localized: "\(price) / \(n) weeks")
        case (.month, true): return String(localized: "\(price) / month")
        case (.month, false): return String(localized: "\(price) / \(n) months")
        case (.year, true): return String(localized: "\(price) / year")
        case (.year, false): return String(localized: "\(price) / \(n) years")
        default: return price
        }
    }

    /// Free-trial length in days for day/week trials, nil for none or for
    /// month/year trials. CTA copy names the days through plural keys.
    var postureIntroOfferDays: Int? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        default: return nil
        }
    }

    /// The trial label in title case for headlines and plan cards
    /// ("7-Day Free Trial").
    var postureIntroOfferTitle: String? {
        if let days = postureIntroOfferDays { return String(localized: "\(days)-Day Free Trial") }
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let n = intro.subscriptionPeriod.value
        switch intro.subscriptionPeriod.unit {
        case .month: return String(localized: "\(n)-Month Free Trial")
        case .year: return String(localized: "\(n)-Year Free Trial")
        default: return nil
        }
    }

    var postureIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let n = period.value
        switch period.unit {
        case .day: return String(localized: "\(n)-day free trial")
        case .week: return String(localized: "\(n * 7)-day free trial")
        case .month: return String(localized: "\(n)-month free trial")
        case .year: return String(localized: "\(n)-year free trial")
        @unknown default: return String(localized: "\(n)-day free trial")
        }
    }
}

extension Offering {
    var postureSortedPackages: [Package] {
        availablePackages.sorted {
            let lhs = $0.posturePackageKind
            let rhs = $1.posturePackageKind
            if lhs.rawValue != rhs.rawValue { return lhs.rawValue < rhs.rawValue }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
    }
}

extension Offerings {
    var posturePaywallOffering: Offering? {
        offering(identifier: "default") ?? current
    }
}
#endif

/// RevenueCat wrapper. Replace `apiKey` with the actual public SDK key from the
/// RevenueCat dashboard before shipping. The "pro" entitlement gates premium features.
@MainActor
@Observable
final class SubscriptionService: NSObject {
    static let shared = SubscriptionService()

    /// RevenueCat public SDK key. Configure offerings in the RevenueCat dashboard.
    static let apiKey = "appl_FLeVCThtDONPnIdpaDisBsWbpji"

    static let proEntitlement = "pro"

    private(set) var isProSubscriber: Bool = false
    private(set) var isConfigured: Bool = false

    #if HAS_REVENUECAT
    private(set) var products: [Package] = []
    private(set) var isLoadingProducts: Bool = false
    private(set) var lastError: String?
    private(set) var introEligibility: [String: Bool] = [:]
    private var paywallImpressionsThisSession: Set<String> = []
    #endif

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: postureAppGroupID)
    }

    func configure() {
        #if DEBUG
        // Simulator/screenshot/UI-test hook: keep the local override authoritative
        // and skip RevenueCat entirely so a customerInfo refresh can't undo it.
        // Lets automated runs walk past the hard paywall gate.
        if LaunchArguments.contains("PostureProOverride") {
            isProSubscriber = true
            return
        }
        #endif
        #if HAS_REVENUECAT
        #if targetEnvironment(simulator)
        // Simulator and agent runs must never create customers in the production
        // RevenueCat project. StoreKit-testing screenshots use local products.
        #if DEBUG
        // The one exception, behind a launch argument: the Test Store key is a
        // separate RevenueCat app inside the same project, so a probe run cannot
        // touch App Store customers, revenue or charts. See RevenueCatProbe.
        if RevenueCatProbe.isEnabled, !isConfigured {
            Purchases.logLevel = .debug
            Purchases.configure(
                with: Configuration.Builder(withAPIKey: RevenueCatProbe.testStoreKey)
                    .with(appUserID: RevenueCatProbe.appUserID)
                    .build()
            )
            Purchases.shared.delegate = self
            isConfigured = true
            return
        }
        #endif
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
        return
        #endif
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        Task { await refresh() }
        Task { await fetchProducts() }
        #endif
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
    }

    func refresh() async {
        #if HAS_REVENUECAT
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            applyProStatus(from: info)
        } catch {
            // Network errors leave previous state intact.
        }
        #else
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
        #endif
    }

    #if HAS_REVENUECAT
    func fetchProducts() async {
        guard isConfigured else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            products = offerings.posturePaywallOffering?.postureSortedPackages ?? []
            lastError = nil
            await refreshIntroEligibility()
        } catch {
            lastError = String(localized: "Couldn't load subscription options. Check your connection and try again.")
        }
    }

    private func refreshIntroEligibility() async {
        let identifiers = products
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
    }

    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.postureIntroOfferLabel != nil else { return false }
        // Default to NOT eligible until RevenueCat confirms eligibility, so we
        // never promise "Start Free Trial" (and the trial-then-price disclosure)
        // to a user who already used the trial and would be charged immediately.
        return introEligibility[package.storeProduct.productIdentifier] ?? false
    }

    /// Custom paywall impressions for RevenueCat analytics (hosted UI did this automatically).
    /// Mirrors the on-device paywall record onto the RevenueCat customer.
    ///
    /// Attributes rather than extra impressions: RevenueCat treats every
    /// impression id as a paywall encounter, so funnel steps sent that way would
    /// drive the encounter rate to 100% and destroy the one server-side number
    /// that currently works.
    ///
    /// `isConfigured` is the load-bearing guard: `Purchases.shared` traps when
    /// RevenueCat was never configured, which is every simulator run.
    ///
    /// `setAttributes` only queues. RevenueCat uploads when the app backgrounds
    /// or folds the queue into the POST that creates a customer, so a probe run
    /// has to background the app before reading anything back.
    func syncConversionAttributes() {
        guard isConfigured else { return }
        let attributes = ConversionDiagnostics.subscriberAttributes
        guard !attributes.isEmpty else { return }
        Purchases.shared.attribution.setAttributes(attributes)
    }

    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard isConfigured else { return }
        #if DEBUG
        if LaunchArguments.contains("UITEST_FRESH") { return }
        #endif
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        ConversionDiagnostics.recordPitchView(impressionID: id)
        syncConversionAttributes()
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
        AnalyticsService.paywallShown()
    }

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseState {
        guard isConfigured else { throw PurchaseError.notConfigured }
        let plan = package.posturePackageKind == .monthly ? "monthly" : (package.posturePackageKind == .yearly ? "yearly" : "lifetime")
        AnalyticsService.purchaseAttempted(plan: plan)
        let startedTrial = isEligibleForIntroOffer(package)
        let result = try await Purchases.shared.purchase(package: package)
        applyProStatus(from: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        }
        if isProSubscriber {
            AnalyticsService.purchaseCompleted(plan: plan)
            ConversionDiagnostics.recordConversion(
                plan: package.storeProduct.productIdentifier,
                startedTrial: startedTrial,
                offeringID: package.presentedOfferingContext.offeringIdentifier
            )
            syncConversionAttributes()
            return .purchased
        }
        return .pending
    }

    func restorePurchases() async {
        guard isConfigured else { return }
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyProStatus(from: info)
            lastError = isProSubscriber ? nil : String(localized: "No active Posture+ purchase found for this Apple ID.")
        } catch {
            lastError = String(localized: "Couldn't restore purchases. Try again.")
        }
    }

    private func applyProStatus(from info: CustomerInfo) {
        // Posture ships a single premium entitlement. Prefer the canonical "pro"
        // identifier, but fall back to ANY active entitlement: the live RevenueCat
        // entitlement is currently configured as "Posture Check - Active Daily Pro"
        // (its display name) rather than "pro", so a hardcoded lookup by id would
        // otherwise leave paid users locked out after a successful purchase.
        let active = info.entitlements.active
        isProSubscriber = active[Self.proEntitlement]?.isActive == true || !active.isEmpty
        sharedDefaults?.set(isProSubscriber, forKey: "isProSubscriber")
    }

    enum PurchaseError: Error {
        case notConfigured
    }
    #endif

    /// The watch has no RevenueCat session of its own: the phone pushes Pro
    /// status over WatchConnectivity, and this replays the last value on launch.
    func loadCachedStatus() {
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
    }

    /// Convenience for debug - flips entitlement locally without RevenueCat. Useful when the
    /// SDK key isn't set yet or you're iterating on the paywall UX.
    func setLocalOverride(isPro: Bool) {
        isProSubscriber = isPro
        sharedDefaults?.set(isPro, forKey: "isProSubscriber")
    }

    #if DEBUG
    /// Drop the cached Pro flag so a UI test starts free. A Test Store purchase
    /// from an earlier test persists it in the app group, which outlives the
    /// app's own defaults reset. Test-only.
    func resetForUITest() {
        isProSubscriber = false
        sharedDefaults?.removeObject(forKey: "isProSubscriber")
    }
    #endif
}

#if HAS_REVENUECAT
extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionService.shared.applyProStatus(from: customerInfo)
        }
    }
}
#endif

#if DEBUG && HAS_REVENUECAT
/// Simulator-only proof path for the fleet-wide funnel attributes.
///
/// Under the normal rules the attributes cannot be verified on a simulator: the
/// production key must never be configured there, so RevenueCat is never
/// configured, so nothing is ever sent, so a physical device is the only
/// witness. The Test Store key is a different RevenueCat app inside the same
/// project, so a probe run cannot touch App Store customers, revenue or charts.
///
/// DEBUG only, and only with the launch argument, so it cannot reach a Release
/// build or an ordinary simulator run.
enum RevenueCatProbe {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobe")
    }

    static let testStoreKey = "test_cWnCArxBrMmWWXXCApNxGAfVFlm"

    static var appUserID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_USER"] ?? "funnel-probe-posture"
    }

    static var impressionID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_SURFACE"] ?? "posture_pro_tab"
    }

    /// Drives a Test Store purchase after the impression, so the `converted_*`
    /// half of the funnel record is exercised and not just the impression half.
    static var wantsPurchase: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobepurchase")
    }
}
#endif
