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
        case .lifetime: return "Lifetime"
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .other: return storeProduct.localizedTitle
        }
    }

    var posturePriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else {
            return storeProduct.localizedPriceString
        }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.value == 1 {
            return "\(storeProduct.localizedPriceString) / \(unit)"
        }
        return "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }

    var postureIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        }
        return "\(period.value)-\(unit.dropLast(period.value == 1 ? 0 : 1)) free trial"
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
            lastError = "Couldn't load subscription options. Check your connection and try again."
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
    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard isConfigured else { return }
        #if DEBUG
        if LaunchArguments.contains("UITEST_FRESH") { return }
        #endif
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
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
        let result = try await Purchases.shared.purchase(package: package)
        applyProStatus(from: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        }
        if isProSubscriber {
            AnalyticsService.purchaseCompleted(plan: plan)
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
            lastError = isProSubscriber ? nil : "No active Posture+ purchase found for this Apple ID."
        } catch {
            lastError = "Couldn't restore purchases. Try again."
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

    /// Convenience for debug - flips entitlement locally without RevenueCat. Useful when the
    /// SDK key isn't set yet or you're iterating on the paywall UX.
    func setLocalOverride(isPro: Bool) {
        isProSubscriber = isPro
        sharedDefaults?.set(isPro, forKey: "isProSubscriber")
    }
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
