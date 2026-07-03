import XCTest

/// Captures the full first-time experience for someone who downloads the app
/// WITHOUT compatible AirPods (the App Review reviewer's path and a common real
/// user): welcome → calibration escape → Today → manual check-in → done →
/// History → Settings → paywall. Screenshots are attached at every step so the
/// download→use journey can be eyeballed for polish. Defensive by design —
/// keeps going and keeps capturing even if a single control shifts.
final class NewUserWalkthroughUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        // Pro override walks past the hard paywall gate so the no-AirPods
        // journey (Today → check-in → History → Settings) is reachable.
        app.launchArguments += ["UITEST_FRESH", "-PostureProOverride"]
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNewUserNoAirpodsJourney() {
        // 1 — Welcome (paged teach-good-posture walkthrough)
        let begin = app.buttons["Continue"]
        XCTAssertTrue(begin.waitForExistence(timeout: 20), "welcome never appeared")
        shot("01-welcome")
        for _ in 0..<3 {
            if app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
        }
        let finish = app.buttons["Set up my baseline"]
        if finish.waitForExistence(timeout: 6) { finish.tap() }

        // 2 — Calibration parks on the AirPods waiting state; the no-AirPods
        // escape fades in after a few seconds. A user/reviewer must never be
        // trapped here.
        let skip = app.buttons["I don't have AirPods"]
        XCTAssertTrue(skip.waitForExistence(timeout: 25), "no-AirPods escape never appeared — user could be trapped")
        shot("02-calibration-waiting")
        skip.tap()

        // 3 — Today (running on a deferred/neutral baseline)
        let checkIn = app.buttons["check in now"]
        XCTAssertTrue(checkIn.waitForExistence(timeout: 15), "did not land on Today after skipping calibration")
        shot("03-today")
        checkIn.tap()

        // 4 — Check-in choice: scan vs. manual self-report
        let aligned = app.buttons["I'm sitting aligned"]
        if aligned.waitForExistence(timeout: 12) {
            shot("04-checkin-choice")
            aligned.tap()
        } else {
            shot("04-checkin-choice-MISSING-CHIP")
        }

        // 5 — Done / acknowledgment result
        sleep(2)
        shot("05-checkin-done")
        let done = app.buttons["done"]
        if done.waitForExistence(timeout: 8) {
            done.tap()
        } else {
            app.buttons["xmark"].firstMatch.tap()
        }

        // Back on Today
        _ = checkIn.waitForExistence(timeout: 10)
        shot("06-today-after-checkin")

        // 7 — History
        let history = app.tabBars.buttons["History"]
        if history.waitForExistence(timeout: 8) {
            history.tap()
            sleep(1)
            shot("07-history")
        }

        // 8 — Settings
        let settings = app.tabBars.buttons["Settings"]
        if settings.waitForExistence(timeout: 8) {
            settings.tap()
            sleep(1)
            shot("08-settings")
        }

        // 9 — Paywall via the POSTURE+ postcard
        let proCard = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "slouch hours")
        ).firstMatch
        if proCard.waitForExistence(timeout: 6) {
            proCard.tap()
            sleep(2)
            shot("09-paywall")
        } else {
            shot("09-settings-no-procard")
        }

        XCTAssertEqual(app.state, .runningForeground, "app left foreground during the journey")
    }
}
