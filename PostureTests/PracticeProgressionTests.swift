import XCTest
@testable import Posture

final class PracticeProgressionTests: XCTestCase {
    // MARK: - Level thresholds

    func testLevelOneAtZeroPassedSessions() {
        XCTAssertEqual(PracticeProgression.level(passedSessions: 0), 1)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 1), 1)
    }

    func testLevelTwoAtTwoPassedSessions() {
        XCTAssertEqual(PracticeProgression.level(passedSessions: 2), 2)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 4), 2)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 5), 3)
    }

    func testTableLevels() {
        XCTAssertEqual(PracticeProgression.level(passedSessions: 9), 4)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 14), 5)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 20), 6)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 54), 10)
    }

    func testLateLevelsUseFixedStride() {
        XCTAssertEqual(PracticeProgression.level(passedSessions: 54 + 11), 10)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 54 + 12), 11)
        XCTAssertEqual(PracticeProgression.level(passedSessions: 54 + 24), 12)
    }

    func testNegativeInputClampsToLevelOne() {
        XCTAssertEqual(PracticeProgression.level(passedSessions: -3), 1)
    }

    func testLevelIsMonotonicNondecreasing() {
        var previous = 0
        for sessions in 0...200 {
            let level = PracticeProgression.level(passedSessions: sessions)
            XCTAssertGreaterThanOrEqual(level, previous)
            previous = level
        }
    }

    func testThresholdIsInverseOfLevel() {
        for level in 1...20 {
            let needed = PracticeProgression.threshold(forLevel: level)
            XCTAssertEqual(PracticeProgression.level(passedSessions: needed), level)
            if needed > 0 {
                XCTAssertEqual(PracticeProgression.level(passedSessions: needed - 1), level - 1)
            }
        }
    }

    // MARK: - Session length ramp

    func testSessionSecondsRamp() {
        XCTAssertEqual(PracticeProgression.sessionSeconds(forLevel: 1), 180)
        XCTAssertEqual(PracticeProgression.sessionSeconds(forLevel: 2), 240)
        XCTAssertEqual(PracticeProgression.sessionSeconds(forLevel: 5), 420)
        XCTAssertEqual(PracticeProgression.sessionSeconds(forLevel: 13), 900)
        XCTAssertEqual(PracticeProgression.sessionSeconds(forLevel: 40), 900, "capped at 15 min")
        XCTAssertEqual(PracticeProgression.sessionSeconds(forLevel: 0), 180, "clamped to level 1")
    }

    // MARK: - Target percent ramp

    func testTargetPercentRamp() {
        XCTAssertEqual(PracticeProgression.targetPercent(forLevel: 1), 50)
        XCTAssertEqual(PracticeProgression.targetPercent(forLevel: 2), 53)
        XCTAssertEqual(PracticeProgression.targetPercent(forLevel: 11), 80)
        XCTAssertEqual(PracticeProgression.targetPercent(forLevel: 40), 80, "capped at 80%")
    }

    // MARK: - Free cap

    func testEffectiveLevelCapsFreeUsers() {
        XCTAssertEqual(PracticeProgression.effectiveLevel(level: 1, isPro: false), 1)
        XCTAssertEqual(PracticeProgression.effectiveLevel(level: 2, isPro: false), 2)
        XCTAssertEqual(PracticeProgression.effectiveLevel(level: 3, isPro: false), PracticeProgression.freeLevelCap)
        XCTAssertEqual(PracticeProgression.effectiveLevel(level: 9, isPro: false), PracticeProgression.freeLevelCap)
        XCTAssertEqual(PracticeProgression.effectiveLevel(level: 9, isPro: true), 9)
    }

    // MARK: - Progress within level

    func testProgressInLevel() {
        // Level 1 spans 0..<2 passed sessions.
        var progress = PracticeProgression.progressInLevel(passedSessions: 1)
        XCTAssertEqual(progress.done, 1)
        XCTAssertEqual(progress.needed, 2)

        // Level 3 spans 5..<9.
        progress = PracticeProgression.progressInLevel(passedSessions: 7)
        XCTAssertEqual(progress.done, 2)
        XCTAssertEqual(progress.needed, 4)

        // Fresh level boundary starts at 0.
        progress = PracticeProgression.progressInLevel(passedSessions: 5)
        XCTAssertEqual(progress.done, 0)
    }
}
