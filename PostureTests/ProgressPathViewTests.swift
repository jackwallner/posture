import SwiftUI
import UIKit
import XCTest
@testable import Posture

/// The Progress tab's level path windows the ladder around the user's level.
/// The ladder is unbounded (a level every 12 passes past level 10) but the tab
/// only draws rungs 1...12, so a Pro user deep in the ladder must still get a
/// window instead of an invalid range.
@MainActor
final class ProgressPathViewTests: XCTestCase {
    private let shownMax = 12

    func testWindowCentersOnAMidLevel() {
        XCTAssertEqual(
            ProgressPathView.visibleLevels(currentLevel: 5, maxLevel: shownMax, windowRadius: 2),
            [3, 4, 5, 6, 7]
        )
    }

    func testWindowStopsAtLevelOne() {
        XCTAssertEqual(
            ProgressPathView.visibleLevels(currentLevel: 1, maxLevel: shownMax, windowRadius: 2),
            [1, 2, 3]
        )
    }

    func testWindowStopsAtTheLastShownRung() {
        XCTAssertEqual(
            ProgressPathView.visibleLevels(currentLevel: 12, maxLevel: shownMax, windowRadius: 2),
            [10, 11, 12]
        )
    }

    /// 114 passed sessions is level 15: the first level whose window starts
    /// past rung 12.
    func testWindowPastTheLastShownRungShowsTheTopOfTheLadder() {
        XCTAssertEqual(PracticeProgression.level(passedSessions: 114), 15)
        XCTAssertEqual(
            ProgressPathView.visibleLevels(currentLevel: 15, maxLevel: shownMax, windowRadius: 2),
            [10, 11, 12]
        )
    }

    func testEveryReachableLevelHasAWindowThatEndsOnTheLadder() {
        for passed in 0...400 {
            let level = PracticeProgression.level(passedSessions: passed)
            let window = ProgressPathView.visibleLevels(
                currentLevel: level, maxLevel: shownMax, windowRadius: 2
            )
            XCTAssertFalse(window.isEmpty, "level \(level)")
            XCTAssertEqual(window.last, min(level + 2, shownMax), "level \(level)")
        }
    }

    /// Lays out the real view the way the Progress tab does, for a Pro user
    /// at level 15 (114 passed sessions).
    func testViewLaysOutForAProUserAtLevelFifteen() {
        let host = UIHostingController(
            rootView: ProgressPathView(currentLevel: 15, maxLevel: shownMax, isPro: true)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertGreaterThan(host.view.bounds.width, 0)
    }
}
