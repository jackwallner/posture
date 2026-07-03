import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Regression: RootView read GoalSettings through the singleton with
    /// no SwiftUI observation, so flipping hasCompletedOnboarding never
    /// re-rendered — onboarding hung on the welcome screen. This drives
    /// the welcome → AirPods-calibration handoff.
    ///
    /// Post-pivot the flow is a short paged teach-good-posture walkthrough
    /// ("Continue" ×3 → "Set up my baseline") straight into AirPods
    /// calibration. On the simulator there are no head-tracking AirPods, so
    /// calibration parks on its "Pop in your AirPods." waiting state — that's
    /// the deterministic outcome we assert.
    func testOnboardingAdvancesToAirpodsCalibration() {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_FRESH"]
        app.launch()

        let begin = app.buttons["Continue"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10), "welcome screen never appeared")
        // Page through the teaching pages to the final calibration hand-off.
        for _ in 0..<3 {
            if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
        }
        let finish = app.buttons["Set up my baseline"]
        XCTAssertTrue(finish.waitForExistence(timeout: 6), "never reached the final onboarding page")
        finish.tap()

        // The bug was the view freezing on welcome. Calibration must take
        // over — on simulator it lands on the AirPods waiting prompt.
        let waiting = app.staticTexts["Pop in your AirPods."]
        XCTAssertTrue(
            waiting.waitForExistence(timeout: 6),
            "stuck on onboarding — hasCompletedOnboarding flip did not re-render RootView"
        )
        XCTAssertFalse(begin.exists, "welcome screen still on screen after Get Started")
        XCTAssertTrue(app.state == .runningForeground, "app crashed during onboarding handoff")
    }
}
