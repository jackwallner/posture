import XCTest

/// The release gate's journeys (`qa-gate run`): onboarding through the trial
/// page to Today, every tab on seeded data, the Posture+ paywall tab, and a
/// return visit with an interruption. Each step ends in `QA.checkpoint`, which
/// runs the fleet oracles on the screen. Assert reachability only.
///
/// Simulator runs never configure the production RevenueCat key, so journeys
/// that show prices launch with `-rcfunnelprobe`: the Test Store, a separate
/// RevenueCat app, supplies them. Its customer never buys.
@MainActor
final class ReleaseJourneysUITests: XCTestCase {

    private static let bundle = "com.jackwallner.posture"
    private static let probe = ["RC_PROBE_USER": "qa-posture-journeys"]

    func test01OnboardingToTrialAndToday() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe, arguments: ["UITEST_FRESH", "-rcfunnelprobe"])
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 20), "welcome never rendered")
        QA.checkpoint(app, "welcome")

        // Every teaching page carries its own Continue, so tap the one on screen.
        for page in 1...4 {
            guard let next = onScreenButton("Continue", in: app) else { break }
            next.tap()
            QA.checkpoint(app, "teach-\(page)")
        }
        let baseline = app.buttons["Set up my baseline"]
        XCTAssertTrue(baseline.waitForExistence(timeout: 6), "never reached the last teaching page")
        baseline.tap()

        let noAirPods = app.buttons["I don't have AirPods"]
        XCTAssertTrue(noAirPods.waitForExistence(timeout: 25), "calibration never rendered")
        QA.checkpoint(app, "airpods-calibration")

        noAirPods.tap()
        let start = app.buttons["Get Started"]
        if start.waitForExistence(timeout: 10) {
            QA.checkpoint(app, "onboarding-trial", paywall: true)
            start.tap()
        }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 30), "Today never rendered")
        QA.checkpoint(app, "first-today", paywall: false)
    }

    private func onScreenButton(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(5)
        repeat {
            for index in 0..<matches.count where matches.element(boundBy: index).isHittable {
                return matches.element(boundBy: index)
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return nil
    }

    func test02EveryTabOnSeededData() {
        continueAfterFailure = false
        let app = launch(["-SCREENSHOT_SEED", "-PostureProOverride"])
        QA.checkpoint(app, "today")
        for tab in ["History", "Progress", "Settings"] {
            app.tabBars.buttons[tab].tap()
            QA.checkpoint(app, tab.lowercased())
        }
    }

    func test03PosturePlusPaywallTab() {
        continueAfterFailure = false
        let app = launch(["-SCREENSHOT_SEED", "-rcfunnelprobe"], environment: Self.probe)
        let plus = app.tabBars.buttons["Posture+"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "Posture+ tab missing for a free user")
        plus.tap()
        QA.checkpoint(app, "posture-plus-paywall", paywall: true)

        app.tabBars.buttons["Today"].tap()
        QA.checkpoint(app, "today-after-paywall", paywall: false)
    }

    func test04ReturnVisitWithInterruption() {
        continueAfterFailure = false
        let app = launch(["-SCREENSHOT_SEED", "-PostureProOverride"])
        app.tabBars.buttons["Progress"].tap()
        QA.checkpoint(app, "progress-before-interruption")

        QA.interrupt(app)
        QA.checkpoint(app, "progress-after-interruption")

        QA.relaunch(app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 25))
        QA.checkpoint(app, "today-after-relaunch")
    }

    /// The no-AirPods core loop: self-report a check-in, see the receipt, and
    /// find it counted after a relaunch. The store may already hold check-ins
    /// from earlier journeys, so counts are asserted relative to each other.
    func testCoreLoopCheckInCountsAndSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe, arguments: ["UITEST_FRESH", "-rcfunnelprobe"])
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 20), "welcome never rendered")
        for _ in 1...4 {
            guard let next = onScreenButton("Continue", in: app) else { break }
            next.tap()
        }
        let baseline = app.buttons["Set up my baseline"]
        XCTAssertTrue(baseline.waitForExistence(timeout: 6), "never reached the last teaching page")
        baseline.tap()
        let noAirPods = app.buttons["I don't have AirPods"]
        XCTAssertTrue(noAirPods.waitForExistence(timeout: 25), "calibration never rendered")
        noAirPods.tap()
        let start = app.buttons["Get Started"]
        if start.waitForExistence(timeout: 10) { start.tap() }
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 30), "Today never rendered")
        QA.checkpoint(app, "today-before-check-in")

        let first = try checkIn("aligned", in: app)
        XCTAssertTrue(app.staticTexts["Aligned"].exists, "result did not name the quality that was logged")
        QA.checkpoint(app, "check-in-result-aligned")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        QA.checkpoint(app, "today-after-check-in")

        // Keep the stored settings (no-AirPods mode), drop only the reset flag.
        app.launchArguments.removeAll { $0 == "UITEST_FRESH" }
        QA.relaunch(app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 30), "Today missing after relaunch")
        QA.checkpoint(app, "today-after-relaunch")

        let second = try checkIn("drifting", in: app)
        XCTAssertEqual(second, first + 1, "the check-in before the relaunch was lost")
        XCTAssertTrue(app.staticTexts["Drifting"].exists, "second result did not name the quality that was logged")
        QA.checkpoint(app, "second-check-in-result")
        app.buttons["Done"].tap()
    }

    /// Opens the check-in from Today, taps the self-report chip and returns
    /// the "N check-ins today" count from the receipt (1 for "first").
    private func checkIn(_ quality: String, in app: XCUIApplication, journey: String = #function) throws -> Int {
        let open = app.buttons["Check in now"]
        for _ in 0..<6 where !open.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(open.waitForExistence(timeout: 10), "no Check in now button on Today")
        open.tap()
        let chip = app.buttons["I'm sitting \(quality)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "self-report chips never rendered")
        QA.checkpoint(app, "check-in-choice-\(quality)", journey: journey)
        chip.tap()
        let receipt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'check-in'")).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 10), "no receipt after logging a check-in")
        let label = receipt.label
        if label.hasPrefix("your first check-in") { return 1 }
        let count = Int(label.prefix { $0.isNumber })
        return try XCTUnwrap(count, "unreadable receipt: \(label)")
    }

    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: environment, arguments: arguments)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 25), "seeded Today never rendered")
        return app
    }
}
