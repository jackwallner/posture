import Foundation
#if HAS_REVENUECAT
import RevenueCat
#endif

/// How a failed purchase call is treated. Ask to Buy is not a failure: a
/// parent holds the request and Apple finishes it later, so the customer sees
/// a calm waiting line and the customer-info update unlocks Posture+.
enum PurchaseFailure: Equatable, Sendable {
    /// Ask to Buy or another deferred approval.
    case pending
    /// Anything else: shown with the screen's own translated error line.
    case other

    /// The RevenueCat error code name `paymentPendingError` maps to pending;
    /// every other code stays an error. Kept on plain names so tests need no
    /// RevenueCat types.
    static func classify(errorCodeName: String?) -> PurchaseFailure {
        errorCodeName == "paymentPendingError" ? .pending : .other
    }
}

enum PurchaseCopy {
    /// The Ask to Buy line, the same on every purchase surface.
    static var waitingForApproval: String {
        String(localized: "Waiting for approval. Your purchase unlocks once it is approved.")
    }
}

#if HAS_REVENUECAT
extension PurchaseFailure {
    init(_ error: Error) {
        if let code = error as? RevenueCat.ErrorCode, code == .paymentPendingError {
            self = .pending
        } else {
            self = .other
        }
    }
}
#endif
