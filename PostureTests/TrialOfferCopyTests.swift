import XCTest
@testable import Posture

/// The Posture+ trial sheet behind Settings' locked toggles and Today's walk
/// card. A user who already used the free trial gets `directPurchase == false`
/// (no eligible package), and the sheet must then read as a plain upgrade
/// pitch: no "free for 7 days", no "Start My Free Trial".
@MainActor
final class TrialOfferCopyTests: XCTestCase {

    private func sheet(focus: PosturePlusFeature?, offerHeadline: String?, directPurchase: Bool) -> TrialOfferSheet {
        TrialOfferSheet(
            focus: focus,
            offerHeadline: offerHeadline,
            priceLabel: directPurchase ? "$39.99 / year" : nil,
            directPurchase: directPurchase,
            isPurchasing: false,
            errorMessage: nil,
            onStartTrial: {},
            onSeeAllPlans: {},
            onDismiss: {}
        )
    }

    func testIneligibleUserIsNotPromisedAFreeTrial() {
        // Another product's intro offer can still produce a headline; without an
        // eligible package the sheet must ignore it.
        for focus in [PosturePlusFeature.walkMode, .airpodsBackground, .alwaysOnWatch] {
            let s = sheet(focus: focus, offerHeadline: "7-Day Free Trial, on us.", directPurchase: false)
            XCTAssertFalse(s.offersTrial)
            XCTAssertEqual(s.subheadline, focus.intentSubheadline)
            XCTAssertFalse(s.subheadline.contains("Free for 7 days"))
            XCTAssertEqual(s.ctaTitle, "Start Posture+")
        }
        let unfocused = sheet(focus: nil, offerHeadline: "7-Day Free Trial, on us.", directPurchase: false)
        XCTAssertEqual(unfocused.headline, "Posture that grows with you.")
        XCTAssertEqual(unfocused.subheadline, "The full ladder, walks, trends, and all-day monitoring.")
        XCTAssertEqual(unfocused.ctaTitle, "Start Posture+")
    }

    func testEligibleUserKeepsTheTrialCopy() {
        let focused = sheet(focus: .walkMode, offerHeadline: "7-Day Free Trial, on us.", directPurchase: true)
        XCTAssertTrue(focused.offersTrial)
        XCTAssertTrue(focused.subheadline.hasSuffix("Free for 7 days. Cancel anytime."))
        XCTAssertEqual(focused.ctaTitle, "Start My Free Trial")

        let unfocused = sheet(focus: nil, offerHeadline: "7-Day Free Trial, on us.", directPurchase: true)
        XCTAssertEqual(unfocused.headline, "7-Day Free Trial, on us.")
        XCTAssertEqual(unfocused.ctaTitle, "Start My Free Trial")
    }
}
