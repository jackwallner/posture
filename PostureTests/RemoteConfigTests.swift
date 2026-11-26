import XCTest
@testable import Posture

/// The offering-metadata reader, the trial button's three arms and the rating
/// switch. Pure logic: the metadata is a hand-built dictionary.
final class RemoteConfigTests: XCTestCase {
    private let key = TrialCTA.metadataKey

    // MARK: Reader

    func testMissingMetadataIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: nil), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [:]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["other": "my"]), .control)
    }

    func testNonStringValueIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: [key: 7]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [key: true]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [key: ["my"]]), .control)
    }

    func testUnknownValueIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: [key: "free_week"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [key: "MY"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [key: ""]), .control)
    }

    func testEachKnownValueReadsItsArm() {
        XCTAssertEqual(TrialCTA.from(metadata: [key: "seven_day"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [key: "my"]), .my)
        XCTAssertEqual(TrialCTA.from(metadata: [key: "your"]), .your)
    }

    // MARK: Titles

    func testControlReturnsTodaysCopyUntouchedOnEverySurface() {
        let onboarding = "Start 7-day free trial"
        let paywall = "Start My 7-Day Free Trial"
        let sheet = "Start My Free Trial"
        XCTAssertEqual(TrialCTA.control.title(.onboarding, control: onboarding), onboarding)
        XCTAssertEqual(TrialCTA.control.title(.paywall, control: paywall), paywall)
        XCTAssertEqual(TrialCTA.control.title(.sheet, control: sheet), sheet)
    }

    func testMyArmTitlePerSurface() {
        XCTAssertEqual(TrialCTA.my.title(.onboarding, control: "x"), "Start my free trial")
        XCTAssertEqual(TrialCTA.my.title(.paywall, control: "x"), "Start My Free Trial")
        XCTAssertEqual(TrialCTA.my.title(.sheet, control: "x"), "Start My Free Trial")
    }

    func testYourArmTitlePerSurface() {
        XCTAssertEqual(TrialCTA.your.title(.onboarding, control: "x"), "Start your free trial")
        XCTAssertEqual(TrialCTA.your.title(.paywall, control: "x"), "Start Your Free Trial")
        XCTAssertEqual(TrialCTA.your.title(.sheet, control: "x"), "Start Your Free Trial")
    }

    /// The sheet's control copy before this test existed, and the control's
    /// raw value, are what the metadata and the catalog already say.
    func testControlRawValueAndSheetCopyAreUnchanged() {
        XCTAssertEqual(TrialCTA.control.rawValue, "seven_day")
        XCTAssertEqual(String(localized: "Start My Free Trial"), "Start My Free Trial")
    }

    // MARK: Switch

    func testRatingPromptIsOnByDefault() {
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: nil))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
    }

    func testRatingPromptIsOffOnlyForOff() {
        XCTAssertFalse(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": 0]))
    }

    func testSwitchKeyIsRatingPrompt() {
        XCTAssertEqual(RemoteSwitch.ratingPrompt.rawValue, "rating_prompt")
    }
}
