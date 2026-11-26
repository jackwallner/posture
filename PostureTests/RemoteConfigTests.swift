import XCTest
@testable import Posture

final class RemoteConfigTests: XCTestCase {
    // MARK: Reader

    func testMissingMetadataIsControl() {
        XCTAssertEqual(TrialCTA.from(metadata: nil), .control)
        XCTAssertEqual(TrialCTA.from(metadata: [:]), .control)
    }

    func testNonStringAndUnknownValuesAreControl() {
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": 3]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": true]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "bogus"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": ""]), .control)
    }

    func testKnownValuesPickTheirArm() {
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "seven_day"]), .control)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "my"]), .my)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "your"]), .your)
        XCTAssertEqual(TrialCTA.metadataKey, "trial_cta")
    }

    // MARK: Titles

    func testControlTitlesAreTodaysCopy() {
        XCTAssertEqual(TrialCTA.control.title(.onboarding, control: "Start 7-day free trial"), "Start 7-day free trial")
        XCTAssertEqual(TrialCTA.control.title(.paywall, control: "Start My 7-Day Free Trial"), "Start My 7-Day Free Trial")
        XCTAssertEqual(TrialCTA.control.title(.sheet, control: TrialCTA.sheetControl), "Start My Free Trial")
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

    func testNoTrialKnownKeepsTheOldWordingOnEveryArm() {
        for arm in TrialCTA.allCases {
            XCTAssertEqual(arm.onboardingTitle(controlLabel: nil), "Start 7-day free trial")
        }
        XCTAssertEqual(TrialCTA.my.onboardingTitle(controlLabel: "Start 7-day free trial"), "Start my free trial")
    }

    // MARK: Switches

    func testSwitchIsOnUnlessOff() {
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: nil))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
        XCTAssertFalse(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
        XCTAssertEqual(RemoteSwitch.ratingPrompt.rawValue, "rating_prompt")
    }
}
