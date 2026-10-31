import XCTest
@testable import Posture

/// History's rhythm card lists the week's strongest and slouchiest hours. A
/// thin week must never list the same hour under both headings.
final class HourRhythmTests: XCTestCase {
    /// `count` consecutive hours from 6, best first.
    private func week(hours count: Int) -> [Int: Double] {
        Dictionary(uniqueKeysWithValues: (0..<count).map { (6 + $0, 1.0 - Double($0) * 0.05) })
    }

    func testNoHourIsBothStrongAndSlouchy() {
        for count in 3...12 {
            let rhythm = PostureDayStats.hourRhythm(week(hours: count))
            XCTAssertTrue(
                Set(rhythm.strong).isDisjoint(with: rhythm.slouchy),
                "\(count) hours: strong \(rhythm.strong) vs slouchy \(rhythm.slouchy)"
            )
        }
    }

    func testEachSideTakesAtMostThreeAndAtMostHalfTheHours() {
        for count in 3...12 {
            let rhythm = PostureDayStats.hourRhythm(week(hours: count))
            XCTAssertEqual(rhythm.strong.count, min(3, count / 2), "\(count) hours")
            XCTAssertEqual(rhythm.slouchy.count, min(3, count / 2), "\(count) hours")
        }
    }

    func testStrongIsTheBestHoursAndSlouchyTheWorst() {
        let rhythm = PostureDayStats.hourRhythm(week(hours: 8))
        XCTAssertEqual(rhythm.strong, [6, 7, 8])
        XCTAssertEqual(rhythm.slouchy, [11, 12, 13])
    }

    func testEqualHoursSplitTheSameWayEveryTime() {
        let flat = Dictionary(uniqueKeysWithValues: (9...14).map { ($0, 1.0) })
        let rhythm = PostureDayStats.hourRhythm(flat)
        XCTAssertEqual(rhythm.strong, [9, 10, 11])
        XCTAssertEqual(rhythm.slouchy, [12, 13, 14])
    }

    func testTooFewHoursListNothing() {
        XCTAssertTrue(PostureDayStats.hourRhythm([:]).strong.isEmpty)
        XCTAssertTrue(PostureDayStats.hourRhythm([9: 0.8]).slouchy.isEmpty)
    }
}
