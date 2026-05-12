import Foundation
import Observation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// RevenueCat wrapper. Replace `apiKey` with the actual public SDK key from the
/// RevenueCat dashboard before shipping. The "pro" entitlement gates premium features.
@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    /// RevenueCat public SDK key. Configure pricing/paywall in the RevenueCat dashboard.
    static let apiKey = "appl_FLeVCThtDONPnIdpaDisBsWbpji"

    static let proEntitlement = "pro"

    private(set) var isProSubscriber: Bool = false
    private(set) var isConfigured: Bool = false

    func configure() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true
        Task { await refresh() }
        #endif
    }

    func refresh() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isProSubscriber = info.entitlements[Self.proEntitlement]?.isActive == true
        } catch {
            // Network errors leave previous state intact.
        }
        #endif
    }

    /// Convenience for debug — flips entitlement locally without RevenueCat. Useful when the
    /// SDK key isn't set yet or you're iterating on the paywall UX.
    func setLocalOverride(isPro: Bool) {
        isProSubscriber = isPro
    }
}
