import XCTest

/// Exercise the real warm-up, including the system's Reduce Motion setting.
@MainActor
final class WarmupDemoUITests: XCTestCase {
    func testWarmupShowsAnimatedChinTuckDemo() {
        setReduceMotion(false)
        let app = openWarmup()
        let demo = app.images["chin-tuck-demo"]
        let frames = demoFrames(demo)
        XCTAssertGreaterThan(Set(frames).count, 1, "the demonstration never moved")
        attach(app, name: "warmup-animated")
        verifySkipAndCounter(app)
    }

    func testReduceMotionShowsStillChinTuckDemo() {
        setReduceMotion(true)
        defer { setReduceMotion(false) }
        let app = openWarmup()
        let demo = app.images["chin-tuck-demo"]
        let frames = demoFrames(demo)
        XCTAssertEqual(Set(frames).count, 1, "the demonstration moved under Reduce Motion")
        attach(app, name: "warmup-reduce-motion")
        verifySkipAndCounter(app)
    }

    func testLargeTextKeepsDemoAndSkipReachable() {
        let app = openWarmup(arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        attach(app, name: "warmup-large-text")
        verifySkipAndCounter(app)
    }

    private func openWarmup(arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.posture")
        QA.launch(app, arguments: ["-SCREENSHOT_SEED", "-PostureProOverride", "-AppleLanguages", "(en)"] + arguments)

        let practice = app.buttons["Begin today's practice"]
        XCTAssertTrue(practice.waitForExistence(timeout: 25), "seeded Today never showed the practice card")
        if !practice.isHittable { app.swipeUp() }
        practice.tap()
        let begin = app.buttons["Begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10), "practice pre-start never rendered")
        if !begin.isHittable { app.swipeUp() }
        begin.tap()

        XCTAssertTrue(app.staticTexts["Warm up your neck."].waitForExistence(timeout: 10), "warm-up never rendered")
        QA.clearSystemAlerts()
        let demo = app.images["chin-tuck-demo"]
        XCTAssertTrue(demo.exists, "chin-tuck demo missing from the warm-up")
        XCTAssertTrue(demo.isHittable, "chin-tuck demo is off screen or covered")
        return app
    }

    /// Four seconds covers a full cycle, so the moving version cannot pass
    /// just because the captures happened to land during its held pose.
    private func demoFrames(_ demo: XCUIElement) -> [Data] {
        (0..<9).map { _ in
            Thread.sleep(forTimeInterval: 0.5)
            return demo.screenshot().pngRepresentation
        }
    }

    private func verifySkipAndCounter(_ app: XCUIApplication) {
        let rep = app.buttons["Done with this rep (debug)"]
        if !rep.isHittable { app.swipeUp() }
        rep.tap()
        let counter = app.descendants(matching: .any)["chin-tuck-reps"]
        let counted = NSPredicate(format: "label BEGINSWITH %@", "1 of")
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: counted, object: counter)],
                                    timeout: 5) == .completed, "the rep counter did not reach 1")
        let skip = app.buttons["Skip the warm-up"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "skip warm-up never appeared")
        for _ in 0..<3 where !skip.isHittable { app.swipeUp() }
        XCTAssertTrue(skip.isHittable, "skip warm-up is unreachable")
        skip.tap()
        XCTAssertTrue(app.images["chin-tuck-demo"].waitForNonExistence(timeout: 5), "skip did not leave the warm-up")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        QA.clearSystemAlerts()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func setReduceMotion(_ enabled: Bool) {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()
        let accessibility = settings.staticTexts["Accessibility"]
        for _ in 0..<6 where !accessibility.isHittable { settings.swipeUp() }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 5))
        accessibility.tap()
        let motion = settings.staticTexts["Motion"]
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        motion.tap()
        let toggle = settings.switches["Reduce Motion"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let wanted = enabled ? "1" : "0"
        if toggle.value as? String != wanted {
            // Settings exposes the whole row as a switch. Tap its trailing
            // thumb, not the row's centre (which can leave the setting alone).
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let changed = NSPredicate(format: "value == %@", wanted)
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: toggle)],
                                    timeout: 5) == .completed, "Reduce Motion setting did not change")
        settings.terminate()
    }
}
