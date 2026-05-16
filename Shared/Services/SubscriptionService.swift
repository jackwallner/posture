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

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: postureAppGroupID)
    }

    func configure() {
        #if canImport(RevenueCat)
        guard !isConfigured else { return }
        Purchases.configure(withAPIKey: Self.apiKey)
        isConfigured = true
        Task { await refresh() }
        #endif
        // Always sync from shared defaults on launch
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
    }

    func refresh() async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isProSubscriber = info.entitlements[Self.proEntitlement]?.isActive == true
            sharedDefaults?.set(isProSubscriber, forKey: "isProSubscriber")
        } catch {
            // Network errors leave previous state intact.
        }
        #else
        // On watch, read from shared defaults written by iOS
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
        #endif
    }

    /// Convenience for debug — flips entitlement locally without RevenueCat. Useful when the
    /// SDK key isn't set yet or you're iterating on the paywall UX.
    func setLocalOverride(isPro: Bool) {
        isProSubscriber = isPro
        sharedDefaults?.set(isPro, forKey: "isProSubscriber")
    }
}
