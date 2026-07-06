import XCTest

final class ProgressTabUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["UITEST_FRESH"]
        app.launch()
    }

    private func reachMainTabs(timeout: TimeInterval = 30) {
        let progressTab = app.tabBars.buttons["Progress"]
        if progressTab.waitForExistence(timeout: 3) { return }

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 20))
        for _ in 0..<4 where app.buttons["Continue"].exists {
            app.buttons["Continue"].tap()
        }
        if app.buttons["Set up my baseline"].waitForExistence(timeout: 6) {
            app.buttons["Set up my baseline"].tap()
        }
        XCTAssertTrue(app.buttons["I don't have AirPods"].waitForExistence(timeout: 25))
        app.buttons["I don't have AirPods"].tap()
        if app.buttons["Maybe later"].waitForExistence(timeout: 8) {
            app.buttons["Maybe later"].tap()
        }
        XCTAssertTrue(progressTab.waitForExistence(timeout: timeout))
    }

    func testProgressTabShowsProgramMap() {
        reachMainTabs()
        app.tabBars.buttons["Progress"].tap()

        XCTAssertTrue(app.staticTexts["Your program"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Level 1"].exists)
        XCTAssertTrue(app.staticTexts["NOW"].exists)
        XCTAssertTrue(app.staticTexts["NEXT"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'target-met session'")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["How the program works"].exists)
        XCTAssertTrue(app.staticTexts["Full program"].exists)
    }
}
