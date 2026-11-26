import XCTest
@testable import Posture

/// Ask to Buy is a wait, not a failure. The RevenueCat error code maps to the
/// pending state; every other code stays an error.
final class PurchaseOutcomeTests: XCTestCase {
    func testPaymentPendingErrorIsPending() {
        XCTAssertEqual(PurchaseFailure.classify(errorCodeName: "paymentPendingError"), .pending)
    }

    func testOtherErrorsAreUnchanged() {
        for name in ["networkError", "offlineConnectionError", "purchaseNotAllowedError",
                     "purchaseCancelledError", "unknownError"] {
            XCTAssertEqual(PurchaseFailure.classify(errorCodeName: name), .other, name)
        }
        XCTAssertEqual(PurchaseFailure.classify(errorCodeName: nil), .other)
    }

    func testWaitingCopyIsCalm() {
        let line = PurchaseCopy.waitingForApproval
        XCTAssertEqual(line, "Waiting for approval. Your purchase unlocks once it is approved.")
        XCTAssertFalse(line.lowercased().contains("error"))
        XCTAssertFalse(line.lowercased().contains("failed"))
    }
}
