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

    // MARK: - Freeze refill

    func testRefillWhenEmptyAndNoRefillDateSetsTo2() {
        let s = StreakState(freezesAvailable: 0)
        StreakService.refillFreezesIfNeeded(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 2)
        XCTAssertEqual(s.lastFreezeRefill, day(2026, 5, 11))
    }

    func testRefillDoesNotReduceExistingFreezes() {
        let s = StreakState(freezesAvailable: 1)
        s.lastFreezeRefill = day(2026, 5, 4) // 7 days ago
        StreakService.refillFreezesIfNeeded(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 2)
    }

    func testRefillWithinWeekDoesNotChange() {
        let s = StreakState(freezesAvailable: 0)
        s.lastFreezeRefill = day(2026, 5, 10)
        StreakService.refillFreezesIfNeeded(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 0)
    }

    func testRefillAtExactly7Days() {
        let s = StreakState(freezesAvailable: 0)
        s.lastFreezeRefill = day(2026, 5, 4) // 7 days before May 11
        StreakService.refillFreezesIfNeeded(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 2)
    }

    func testRefillCapsAt2() {
        let s = StreakState(freezesAvailable: 5)
        s.lastFreezeRefill = day(2026, 5, 4)
        StreakService.refillFreezesIfNeeded(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 5) // already above max, no change
    }

    // MARK: - Milestone freezes

    func testMilestoneAwardedAt7Days() {
        let s = StreakState(currentStreak: 7, freezesAvailable: 2)
        StreakService.awardMilestoneFreezes(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 3)
    }

    func testMilestoneAwardedAt14Days() {
        let s = StreakState(currentStreak: 14, freezesAvailable: 0)
        StreakService.awardMilestoneFreezes(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 1)
    }

    func testMilestoneAwardedAt30Days() {
        let s = StreakState(currentStreak: 30, freezesAvailable: 0)
        StreakService.awardMilestoneFreezes(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 1)
    }

    func testNonMilestoneDoesNotAward() {
        let s = StreakState(currentStreak: 5, freezesAvailable: 0)
        StreakService.awardMilestoneFreezes(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 0)
    }

    func testNonMilestoneDoesNotAwardAt8() {
        let s = StreakState(currentStreak: 8, freezesAvailable: 0)
        StreakService.awardMilestoneFreezes(s, at: day(2026, 5, 11))
        XCTAssertEqual(s.freezesAvailable, 0)
    }
}
