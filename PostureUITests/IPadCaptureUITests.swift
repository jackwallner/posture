import XCTest

/// iPad layout proof: walks every main surface in portrait and landscape and
/// attaches a screenshot per step (`gh-sim test --only PostureUITests/IPadCaptureUITests`).
/// Reachability only; the frames are reviewed by eye. Names carry the
/// orientation so the attachments sort into pairs.
@MainActor
final class IPadCaptureUITests: XCTestCase {
    private static let bundle = "com.jackwallner.posture"
    private static let probe = ["RC_PROBE_USER": "qa-posture-ipad"]

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Helpers

    private func snap(_ app: XCUIApplication, _ name: String, _ shape: String) {
        Thread.sleep(forTimeInterval: 1.2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(shape)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func rotate(_ orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        Thread.sleep(forTimeInterval: 2)
    }

    private func button(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    private func tab(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons[label].exists ? app.tabBars.buttons[label] : button(label, in: app)
    }

    private func open(_ element: XCUIElement, _ name: String, _ shape: String, in app: XCUIApplication, close: String? = nil) {
        guard element.waitForExistence(timeout: 8) else {
            snap(app, "MISSING-\(name)", shape)
            return
        }
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        element.tap()
        snap(app, name, shape)
        if let close {
            let closer = button(close, in: app)
            if closer.exists { closer.tap() } else { app.swipeDown() }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    private func launch(_ arguments: [String], environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: Self.bundle)
        app.launchArguments += arguments
        for (key, value) in environment { app.launchEnvironment[key] = value }
        app.launch()
        return app
    }

    // MARK: - Seeded tabs

    func testSeededTour() {
        let app = launch(["-SCREENSHOT_SEED", "-PostureProOverride"])
        _ = app.wait(for: .runningForeground, timeout: 20)
        Thread.sleep(forTimeInterval: 3)
        for (shape, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", .landscapeLeft)] {
            rotate(orientation)
            tab("Today", in: app).tap()
            snap(app, "today", shape)
            app.swipeUp()
            snap(app, "today-scrolled", shape)
            app.swipeDown()
            let history = tab("History", in: app)
            if history.exists, history.isHittable { history.tap(); snap(app, "history", shape) }
            tab("Progress", in: app).tap()
            snap(app, "progress", shape)
            tab("Settings", in: app).tap()
            snap(app, "settings", shape)
            app.swipeUp()
            snap(app, "settings-scrolled", shape)
            tab("Today", in: app).tap()
            app.swipeDown()
            // Sheets and covers from Today.
            open(button("day streak", in: app), "streak-sheet", shape, in: app, close: "Close")
            open(button("Latest badge", in: app), "achievements-sheet", shape, in: app, close: "Close")
            open(button("Level", in: app), "level-ladder-sheet", shape, in: app, close: "Close")
            open(button("Log a manual check-in", in: app), "checkin-cover", shape, in: app, close: "Close")
            open(button("Begin today", in: app), "practice-cover", shape, in: app)
            app.terminate()
            app.launch()
            Thread.sleep(forTimeInterval: 4)
        }
    }

    // MARK: - App Store frames

    /// Portrait product frames for the iPad App Store set (`asc-*` names).
    func testStoreFrames() {
        let app = launch(["-SCREENSHOT_SEED", "-PostureProOverride"])
        _ = app.wait(for: .runningForeground, timeout: 20)
        Thread.sleep(forTimeInterval: 4)
        rotate(.portrait)
        tab("Today", in: app).tap()
        let begin = button("Begin today", in: app)
        if begin.waitForExistence(timeout: 8) {
            begin.tap()
            snap(app, "asc-1-practice", "portrait")
            let close = button("Close", in: app)
            if close.exists { close.tap() } else { app.swipeDown() }
            Thread.sleep(forTimeInterval: 1.5)
        }
        tab("Today", in: app).tap()
        snap(app, "asc-2-today", "portrait")
        tab("Progress", in: app).tap()
        snap(app, "asc-3-progress", "portrait")
        tab("History", in: app).tap()
        snap(app, "asc-4-history", "portrait")
        app.swipeUp()
        snap(app, "asc-5-history-trends", "portrait")
        tab("Settings", in: app).tap()
        snap(app, "asc-6-settings", "portrait")
    }

    // MARK: - Onboarding and calibration

    func testOnboarding() {
        for (shape, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", .landscapeLeft)] {
            let app = launch(["UITEST_FRESH", "-rcfunnelprobe"], environment: Self.probe)
            rotate(orientation)
            let first = button("Continue", in: app)
            _ = first.waitForExistence(timeout: 20)
            snap(app, "onboarding-1-welcome", shape)
            for page in 2...5 {
                let next = button("Continue", in: app)
                if next.waitForExistence(timeout: 4) { next.tap() }
                snap(app, "onboarding-\(page)", shape)
            }
            let baseline = button("Set up my baseline", in: app)
            if baseline.waitForExistence(timeout: 6) { baseline.tap() }
            snap(app, "calibration-waiting", shape)
            let none = button("I don't have AirPods", in: app)
            if none.waitForExistence(timeout: 20) { none.tap() }
            snap(app, "after-calibration", shape)
            let start = button("Get Started", in: app)
            if start.waitForExistence(timeout: 10) { start.tap() }
            snap(app, "first-today", shape)
            app.terminate()
        }
    }

    // MARK: - Paywall

    func testPaywallTab() {
        let app = launch(["-SCREENSHOT_SEED", "-rcfunnelprobe"], environment: Self.probe)
        _ = app.wait(for: .runningForeground, timeout: 20)
        Thread.sleep(forTimeInterval: 3)
        for (shape, orientation) in [("portrait", UIDeviceOrientation.portrait), ("landscape", .landscapeLeft)] {
            rotate(orientation)
            let plus = tab("Posture+", in: app)
            if plus.waitForExistence(timeout: 15) { plus.tap() }
            Thread.sleep(forTimeInterval: 3)
            snap(app, "paywall-tab", shape)
            tab("Today", in: app).tap()
            tab("Settings", in: app).tap()
            snap(app, "settings-free", shape)
        }
    }
}
