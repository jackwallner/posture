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
        XCTAssertTrue(button("Continue", "Weiter", in: app).waitForExistence(timeout: 20), "welcome never rendered")
        QA.checkpoint(app, "welcome")

        // Every teaching page carries its own Continue, so tap the one on screen.
        for page in 1...4 {
            guard let next = onScreenButton(["Continue", "Weiter"], in: app) else { break }
            next.tap()
            QA.checkpoint(app, "teach-\(page)")
        }
        let baseline = button("Set up my baseline", "Ausgangswert einrichten", in: app)
        XCTAssertTrue(baseline.waitForExistence(timeout: 6), "never reached the last teaching page")
        baseline.tap()

        let noAirPods = button("I don't have AirPods", "Ich habe keine AirPods", in: app)
        XCTAssertTrue(noAirPods.waitForExistence(timeout: 25), "calibration never rendered")
        QA.checkpoint(app, "airpods-calibration")

        noAirPods.tap()
        let start = app.buttons["Get Started"]
        if start.waitForExistence(timeout: 10) {
            QA.checkpoint(app, "onboarding-trial", paywall: true)
            start.tap()
        }
        XCTAssertTrue(tab("Today", "Heute", in: app).waitForExistence(timeout: 30), "Today never rendered")
        QA.checkpoint(app, "first-today", paywall: false)
    }

    private func onScreenButton(_ labels: [String], in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label IN %@", labels))
        let deadline = Date().addingTimeInterval(5)
        repeat {
            for index in 0..<matches.count where matches.element(boundBy: index).isHittable {
                return matches.element(boundBy: index)
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return nil
    }

    // English or German label, per the persona's language.
    private func button(_ en: String, _ de: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label IN %@", [en, de])).firstMatch
    }

    private func tab(_ en: String, _ de: String, in app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons.matching(NSPredicate(format: "label IN %@", [en, de])).firstMatch
    }

    private func text(_ en: String, _ de: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label IN %@", [en, de])).firstMatch
    }

    func test02EveryTabOnSeededData() {
        continueAfterFailure = false
        let app = launch(["-SCREENSHOT_SEED", "-PostureProOverride"])
        QA.checkpoint(app, "today")
        for (name, german) in [("History", "Verlauf"), ("Progress", "Fortschritt"), ("Settings", "Einstellungen")] {
            let button = tab(name, german, in: app)
            // Unfolded on the iPhone Duo, History is the pane beside Today, not a tab.
            if name == "History", !button.exists { continue }
            button.tap()
            QA.checkpoint(app, name.lowercased())
        }
    }

    func test03PosturePlusPaywallTab() {
        continueAfterFailure = false
        let app = launch(["-SCREENSHOT_SEED", "-rcfunnelprobe"], environment: Self.probe)
        let plus = tab("Posture+", "Posture+", in: app)
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "Posture+ tab missing for a free user")
        plus.tap()
        QA.checkpoint(app, "posture-plus-paywall", paywall: true)

        tab("Today", "Heute", in: app).tap()
        QA.checkpoint(app, "today-after-paywall", paywall: false)
    }

    func test04ReturnVisitWithInterruption() {
        continueAfterFailure = false
        let app = launch(["-SCREENSHOT_SEED", "-PostureProOverride"])
        tab("Progress", "Fortschritt", in: app).tap()
        QA.checkpoint(app, "progress-before-interruption")

        QA.interrupt(app)
        QA.checkpoint(app, "progress-after-interruption")

        QA.relaunch(app)
        XCTAssertTrue(tab("Today", "Heute", in: app).waitForExistence(timeout: 25))
        QA.checkpoint(app, "today-after-relaunch")
    }

    /// The no-AirPods core loop: self-report a check-in, see the receipt, and
    /// find it counted after a relaunch. The store may already hold check-ins
    /// from earlier journeys, so counts are asserted relative to each other.
    func testCoreLoopCheckInCountsAndSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: Self.probe, arguments: ["UITEST_FRESH", "-rcfunnelprobe"])
        XCTAssertTrue(button("Continue", "Weiter", in: app).waitForExistence(timeout: 20), "welcome never rendered")
        for _ in 1...4 {
            guard let next = onScreenButton(["Continue", "Weiter"], in: app) else { break }
            next.tap()
        }
        let baseline = button("Set up my baseline", "Ausgangswert einrichten", in: app)
        XCTAssertTrue(baseline.waitForExistence(timeout: 6), "never reached the last teaching page")
        baseline.tap()
        let noAirPods = button("I don't have AirPods", "Ich habe keine AirPods", in: app)
        XCTAssertTrue(noAirPods.waitForExistence(timeout: 25), "calibration never rendered")
        noAirPods.tap()
        let start = app.buttons["Get Started"]
        if start.waitForExistence(timeout: 10) { start.tap() }
        XCTAssertTrue(tab("Today", "Heute", in: app).waitForExistence(timeout: 30), "Today never rendered")
        QA.checkpoint(app, "today-before-check-in")

        let first = try checkIn("aligned", "aufrecht", in: app)
        XCTAssertTrue(text("Aligned", "Aufrecht", in: app).waitForExistence(timeout: 5), "result did not name the quality that was logged")
        QA.checkpoint(app, "check-in-result-aligned")
        button("Done", "Fertig", in: app).tap()
        XCTAssertTrue(tab("Today", "Heute", in: app).waitForExistence(timeout: 10))
        QA.checkpoint(app, "today-after-check-in")

        // Keep the stored settings (no-AirPods mode), drop only the reset flag.
        app.launchArguments.removeAll { $0 == "UITEST_FRESH" }
        QA.relaunch(app)
        XCTAssertTrue(tab("Today", "Heute", in: app).waitForExistence(timeout: 30), "Today missing after relaunch")
        QA.checkpoint(app, "today-after-relaunch")

        let second = try checkIn("drifting", "leicht gebeugt", in: app)
        XCTAssertEqual(second, first + 1, "the check-in before the relaunch was lost")
        XCTAssertTrue(text("Drifting", "Leicht gebeugt", in: app).waitForExistence(timeout: 5), "second result did not name the quality that was logged")
        QA.checkpoint(app, "second-check-in-result")
        button("Done", "Fertig", in: app).tap()
    }

    /// Opens the check-in from Today, taps the self-report chip and returns
    /// the "N check-ins today" count from the receipt (1 for "first").
    private func checkIn(_ quality: String, _ german: String, in app: XCUIApplication, journey: String = #function) throws -> Int {
        let open = button("Check in now", "Check-in erfassen", in: app)
        for _ in 0..<6 where !open.isHittable {
            QA.swipe(app, .up)
        }
        XCTAssertTrue(open.waitForExistence(timeout: 10), "no Check in now button on Today")
        open.tap()
        let chip = button("I'm sitting \(quality)", "Ich sitze \(german)", in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "self-report chips never rendered")
        QA.checkpoint(app, "check-in-choice-\(quality)", journey: journey)
        chip.tap()
        let receipt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'check-in' OR label CONTAINS 'Check-in'")).firstMatch
        XCTAssertTrue(receipt.waitForExistence(timeout: 10), "no receipt after logging a check-in")
        let label = receipt.label
        if label.hasPrefix("your first check-in") || label.hasPrefix("Dein erster Check-in") { return 1 }
        let count = Int(label.prefix { $0.isNumber })
        return try XCTUnwrap(count, "unreadable receipt: \(label)")
    }

    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        QA.launch(app, environment: environment, arguments: arguments)
        XCTAssertTrue(tab("Today", "Heute", in: app).waitForExistence(timeout: 25), "seeded Today never rendered")
        return app
    }
}
