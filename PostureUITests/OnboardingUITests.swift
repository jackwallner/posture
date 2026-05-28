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
    /// Post-pivot the flow is a single welcome screen ("Get Started")
    /// straight into AirPods calibration. On the simulator there are no
    /// head-tracking AirPods, so calibration parks on its "Pop in your
    /// AirPods." waiting state — that's the deterministic outcome we assert.
    func testOnboardingAdvancesToAirpodsCalibration() {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_FRESH"]
        app.launch()

        let begin = app.buttons["Get Started"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10), "welcome screen never appeared")
        begin.tap()

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
