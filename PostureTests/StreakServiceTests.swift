import XCTest
@testable import Posture

final class StreakServiceTests: XCTestCase {
    private func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    func testFirstSessionStartsStreakAtOne() {
        let s = StreakState()
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        XCTAssertEqual(s.currentStreak, 1)
        XCTAssertEqual(s.longestStreak, 1)
    }

    func testSameDayDoesNotAdvance() {
        let s = StreakState()
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        XCTAssertEqual(s.currentStreak, 1)
    }

    func testConsecutiveDayAdvances() {
        let s = StreakState()
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        StreakService.applySession(to: s, at: day(2026, 5, 12))
        StreakService.applySession(to: s, at: day(2026, 5, 13))
        XCTAssertEqual(s.currentStreak, 3)
        XCTAssertEqual(s.longestStreak, 3)
    }

    func testSkippedDayResetsStreakWhenNoFreezes() {
        let s = StreakState(freezesAvailable: 0)
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        StreakService.applySession(to: s, at: day(2026, 5, 13))
        XCTAssertEqual(s.currentStreak, 1)
    }

    func testFreezeCoversOneMissedDay() {
        let s = StreakState(freezesAvailable: 2)
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        StreakService.applySession(to: s, at: day(2026, 5, 13))
        XCTAssertEqual(s.currentStreak, 2)
        XCTAssertEqual(s.freezesAvailable, 1)
    }

    func testTwoMissedDaysResetsEvenWithFreezes() {
        let s = StreakState(freezesAvailable: 2)
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        StreakService.applySession(to: s, at: day(2026, 5, 14))
        XCTAssertEqual(s.currentStreak, 1)
        XCTAssertEqual(s.freezesAvailable, 2)
    }

    func testLongestStreakPersists() {
        let s = StreakState()
        StreakService.applySession(to: s, at: day(2026, 5, 11))
        StreakService.applySession(to: s, at: day(2026, 5, 12))
        StreakService.applySession(to: s, at: day(2026, 5, 13))
        // Skip enough to break streak
        StreakService.applySession(to: s, at: day(2026, 5, 20))
        XCTAssertEqual(s.currentStreak, 1)
        XCTAssertEqual(s.longestStreak, 3)
    }

    func testDailyGoalPacing() {
        XCTAssertEqual(StreakService.dailyGoalSeconds(forStreak: 0), 60)
        XCTAssertEqual(StreakService.dailyGoalSeconds(forStreak: 2), 60)
        XCTAssertEqual(StreakService.dailyGoalSeconds(forStreak: 3), 90)
        XCTAssertEqual(StreakService.dailyGoalSeconds(forStreak: 9), 150)
        XCTAssertEqual(StreakService.dailyGoalSeconds(forStreak: 100), 300)
    }
}
