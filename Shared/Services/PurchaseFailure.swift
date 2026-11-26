import Foundation

/// How a purchase error reads to the customer. Pure Foundation so the unit
/// tests can build the errors by hand.
enum PurchaseFailure {
    /// RevenueCat's `ErrorCode` NSError domain and the code it throws for an
    /// Ask to Buy request that a parent has not answered yet
    /// (`ErrorCode.paymentPendingError`).
    static let revenueCatDomain = "RevenueCat.ErrorCode"
    static let paymentPendingCode = 20

    /// Ask to Buy: a parent has the request. This is not a failure; Apple
    /// finishes the purchase later and the customer-info update unlocks it.
    static func isAskToBuy(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == revenueCatDomain && nsError.code == paymentPendingCode
    }

    /// What the paywall, trial page and trial sheet say while a purchase waits.
    static var waitingMessage: String {
        String(localized: "Waiting for approval. Your purchase unlocks once it is approved.")
    }
}
