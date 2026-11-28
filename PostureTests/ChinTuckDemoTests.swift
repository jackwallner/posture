import XCTest
@testable import Posture

/// The warm-up demo's pace has to be one the rep detector counts.
final class ChinTuckDemoTests: XCTestCase {
    func testDemoRepFitsTheDetectorWindow() {
        XCTAssertGreaterThanOrEqual(ChinTuckDemo.repSeconds, PostureScoring.ChinTuck.minRepDurationSeconds)
        XCTAssertLessThanOrEqual(ChinTuckDemo.repSeconds, PostureScoring.ChinTuck.maxRepDurationSeconds)
    }

    func testCycleStartsLevelTucksAndReturns() {
        XCTAssertEqual(ChinTuckDemo.tuck(at: 0), 0)
        XCTAssertEqual(ChinTuckDemo.tuck(at: 2.4), 1)
        XCTAssertEqual(ChinTuckDemo.tuck(at: ChinTuckDemo.cycle - 0.001), 0, accuracy: 0.001)
        XCTAssertEqual(ChinTuckDemo.tuck(at: ChinTuckDemo.cycle + 2.4), 1)
    }

    func testMotionIsSmoothAndBounded() {
        var previous = ChinTuckDemo.tuck(at: 0)
        for step in 1...400 {
            let value = ChinTuckDemo.tuck(at: Double(step) * 0.01)
            XCTAssert((0...1).contains(value))
            XCTAssertLessThan(abs(value - previous), 0.05, "jump at \(Double(step) * 0.01)s")
            previous = value
        }
    }
}
