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

    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: environment, arguments: arguments)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 25), "seeded Today never rendered")
        return app
    }
}
