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

    /// Reproduction: tapping "yes — link them" was reported to crash. Drives the
    /// AirPods path of the same handoff (welcome → AirPods → calibration). On
    /// simulator, head-motion isn't available, so we expect the auto-fallback
    /// to the camera capture step rather than the AirPods capture screen.
    func testOnboardingYesAirpodsReachesCalibration() {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_FRESH"]
        app.launch()

        let begin = app.buttons["begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10), "welcome screen never appeared")
        begin.tap()

        let yesAirpods = app.buttons["yes — link them"]
        XCTAssertTrue(yesAirpods.waitForExistence(timeout: 5), "AirPods question never appeared")
        yesAirpods.tap()

        // Either AirPods capture ("sit upright.") on a real device with
        // head-tracking AirPods, OR camera fallback on simulator / unsupported
        // AirPods. Both prove we didn't crash.
        let airpodsStep = app.staticTexts["sit upright."]
        let cameraStep = app.staticTexts["we'll enable this once we can see your face."]
        let predicate = NSPredicate { _, _ in airpodsStep.exists || cameraStep.exists }
        let reached = expectation(for: predicate, evaluatedWith: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [reached], timeout: 6), .completed,
                       "did not reach calibration after answering yes — link them")
        XCTAssertTrue(app.state == .runningForeground, "app crashed during AirPods onboarding")
    }
}
