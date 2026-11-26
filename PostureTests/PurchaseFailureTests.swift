import XCTest
@testable import Posture

/// Ask to Buy reads as a wait, never as a failure.
final class PurchaseFailureTests: XCTestCase {
    private func revenueCatError(_ code: Int) -> NSError {
        NSError(domain: PurchaseFailure.revenueCatDomain, code: code)
    }

    func testPaymentPendingIsAskToBuy() {
        XCTAssertTrue(PurchaseFailure.isAskToBuy(revenueCatError(20)))
    }

    func testOtherRevenueCatErrorsAreNotPending() {
        // purchaseNotAllowedError 3, networkError 10, offlineConnectionError 35
        for code in [0, 1, 2, 3, 10, 35] {
            XCTAssertFalse(PurchaseFailure.isAskToBuy(revenueCatError(code)), "code \(code)")
        }
    }

    func testSameCodeFromAnotherDomainIsNotPending() {
        XCTAssertFalse(PurchaseFailure.isAskToBuy(NSError(domain: NSURLErrorDomain, code: 20)))
    }

    func testWaitingMessageCopy() {
        XCTAssertEqual(
            PurchaseFailure.waitingMessage,
            "Waiting for approval. Your purchase unlocks once it is approved."
        )
        XCTAssertFalse(PurchaseFailure.waitingMessage.lowercased().contains("error"))
    }
}
