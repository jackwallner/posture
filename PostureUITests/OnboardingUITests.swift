import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Regression: RootView read GoalSettings through the singleton with
    /// no SwiftUI observation, so flipping hasCompletedOnboarding never
    /// re-rendered — onboarding hung on the AirPods question. This drives
    /// the full welcome → AirPods → calibration handoff.
    func testOnboardingAdvancesThroughAirPodsToCalibration() {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_FRESH"]
        app.launch()

        let begin = app.buttons["begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10), "welcome screen never appeared")
        begin.tap()

        let noAirpods = app.buttons["no — use my camera"]
        XCTAssertTrue(noAirpods.waitForExistence(timeout: 5), "AirPods question never appeared")
        noAirpods.tap()

        // The bug was the view freezing here. Calibration (camera path,
        // since we answered "no AirPods") must take over.
        let calibration = app.staticTexts["we'll enable this once we can see your face."]
        XCTAssertTrue(
            calibration.waitForExistence(timeout: 6),
            "stuck on onboarding — hasCompletedOnboarding flip did not re-render RootView"
        )
        XCTAssertFalse(noAirpods.exists, "AirPods question still on screen after answering")
    }
}
