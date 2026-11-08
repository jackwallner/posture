import XCTest
@testable import Posture

/// The focused Posture+ sheet promises a free trial only when "Start" buys an
/// intro-eligible package. A user who already used the trial must not read
/// "Free for 7 days" or "Start My Free Trial" before a paywall that charges.
final class TrialOfferSheetTests: XCTestCase {

    func testNoTrialOfferWhenNoEligiblePackage() {
        // Any product's intro offer used to fill the headline even when the
        // user could not start the trial (directPurchase false).
        XCTAssertFalse(TrialOfferSheet.offersTrial(directPurchase: false, offerHeadline: "7-Day Free Trial, on us."))
        XCTAssertFalse(TrialOfferSheet.offersTrial(directPurchase: true, offerHeadline: nil))
        XCTAssertTrue(TrialOfferSheet.offersTrial(directPurchase: true, offerHeadline: "7-Day Free Trial, on us."))
    }

    func testIneligibleCopyNeverMentionsAFreeTrial() {
        let cta = TrialOfferSheet.ctaTitle(offersTrial: false)
        XCTAssertEqual(cta, "Start Posture+")
        XCTAssertFalse(cta.localizedCaseInsensitiveContains("trial"))

        let focused = TrialOfferSheet.subheadline(focus: .walkMode, offersTrial: false)
        XCTAssertEqual(focused, PosturePlusFeature.walkMode.intentSubheadline)
        XCTAssertFalse(focused.localizedCaseInsensitiveContains("free for"))

        let plain = TrialOfferSheet.subheadline(focus: nil, offersTrial: false)
        XCTAssertFalse(plain.localizedCaseInsensitiveContains("trial"))
    }

    func testEligibleCopyKeepsTheTrial() {
        XCTAssertEqual(TrialOfferSheet.ctaTitle(offersTrial: true), "Start My Free Trial")
        XCTAssertTrue(
            TrialOfferSheet.subheadline(focus: .walkMode, offersTrial: true).hasSuffix("Free for 7 days. Cancel anytime.")
        )
    }
}
