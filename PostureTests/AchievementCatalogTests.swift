import XCTest
@testable import Posture

final class AchievementCatalogTests: XCTestCase {
    private func practice(passed: Bool, daysAgo: Int = 0) -> PostureSession {
        let row = PostureSession(
            durationSeconds: 180, score: 80, goodSeconds: 150, borderlineSeconds: 20,
            badSeconds: 10, source: .airpods, kind: .practice,
            targetSeconds: 180, targetPercent: 50, alignedPercent: 80,
            completed: true, passed: passed
        )
        row.startedAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return row
    }

    private func walk() -> PostureSession {
        PostureSession(
            durationSeconds: 600, score: 70, goodSeconds: 400, borderlineSeconds: 100,
            badSeconds: 100, source: .airpods, kind: .walk,
            targetSeconds: 600, targetPercent: 0, alignedPercent: 70,
            completed: true, passed: false
        )
    }

    func testEmptyDataEarnsNothing() {
        let earned = AchievementCatalog.earnedIDs(streak: nil, sessions: [])
        XCTAssertTrue(earned.isEmpty)
    }

    func testFirstCompletedPracticeEarnsFirstPractice() {
        let earned = AchievementCatalog.earnedIDs(streak: nil, sessions: [practice(passed: false)])
        XCTAssertTrue(earned.contains("first_practice"))
        XCTAssertFalse(earned.contains("first_pass"))
    }

    func testPassedPracticeEarnsFirstPass() {
        let earned = AchievementCatalog.earnedIDs(streak: nil, sessions: [practice(passed: true)])
        XCTAssertTrue(earned.contains("first_pass"))
    }

    func testLevelFiveBadge() {
        // Level 5 needs threshold(5) = 14 passed sessions.
        let needed = PracticeProgression.threshold(forLevel: 5)
        let sessions = (0..<needed).map { practice(passed: true, daysAgo: needed - $0) }
        let earned = AchievementCatalog.earnedIDs(streak: nil, sessions: sessions)
        XCTAssertTrue(earned.contains("level_5"))
        XCTAssertFalse(earned.contains("level_10"))
    }

    /// A free user is capped at `freeLevelCap`, so grinding passes at the capped
    /// length must not hand them a level badge for a level they never played.
    func testFreeUserCannotEarnLevelBadgesAboveTheCap() {
        let needed = PracticeProgression.threshold(forLevel: 5)
        let sessions = (0..<needed).map { practice(passed: true, daysAgo: needed - $0) }
        let free = AchievementCatalog.earnedIDs(streak: nil, sessions: sessions, isPro: false)
        XCTAssertFalse(free.contains("level_5"))
        XCTAssertTrue(free.contains("first_pass"))

        // The same history unlocks it retroactively once they upgrade.
        let pro = AchievementCatalog.earnedIDs(streak: nil, sessions: sessions, isPro: true)
        XCTAssertTrue(pro.contains("level_5"))
    }

    func testStreakBadgesUseLongestStreak() {
        let streak = StreakState(currentStreak: 3, longestStreak: 31, lastActiveDay: .now)
        let earned = AchievementCatalog.earnedIDs(streak: streak, sessions: [])
        XCTAssertTrue(earned.contains("streak_7"))
        XCTAssertTrue(earned.contains("streak_14"))
        XCTAssertTrue(earned.contains("streak_30"))
        XCTAssertFalse(earned.contains("streak_60"))
        XCTAssertFalse(earned.contains("streak_100"))
    }

    func testWalkBadges() {
        var earned = AchievementCatalog.earnedIDs(streak: nil, sessions: [walk()])
        XCTAssertTrue(earned.contains("first_walk"))
        XCTAssertFalse(earned.contains("walk_10"))

        earned = AchievementCatalog.earnedIDs(streak: nil, sessions: (0..<10).map { _ in walk() })
        XCTAssertTrue(earned.contains("walk_10"))
    }

    func testFreezeSavedFromAvailableFreeze() {
        let streak = StreakState(currentStreak: 2, longestStreak: 2, freezesAvailable: 1, lastActiveDay: .now)
        let earned = AchievementCatalog.earnedIDs(streak: streak, sessions: [])
        XCTAssertTrue(earned.contains("freeze_saved"))
    }

    func testEarnedAtUsesEarliestQualifyingSession() {
        let old = practice(passed: false, daysAgo: 5)
        let new = practice(passed: false, daysAgo: 1)
        let all = AchievementCatalog.all(streak: nil, sessions: [new, old])
        let first = all.first { $0.id == "first_practice" }
        XCTAssertEqual(first?.earnedAt, old.startedAt)
    }

    func testNextUpIsFirstUnearned() {
        let next = AchievementCatalog.nextUp(streak: nil, sessions: [practice(passed: false)])
        XCTAssertEqual(next?.id, "first_pass")
    }
}
