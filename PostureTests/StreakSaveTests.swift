import Foundation
import SwiftData
import XCTest
@testable import Posture

/// Streak save rules (state machine audit 2026-11-06, B4 and B6). Every
/// state is reached through the real record path from an empty store.
@MainActor
final class StreakSaveTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            PostureSession.self, PosturePassiveSample.self, PostureMinuteSample.self,
            Calibration.self, StreakState.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func day(_ d: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - B4 "Safety net" on day one

    func testFirstEverPracticeDoesNotAnnounceAnEarnedStreakSave() throws {
        let context = try makeContext()
        context.insert(Calibration(
            basePitch: 0, baseYaw: 0, baseRoll: 0, slouchPitchDelta: .pi / 6,
            airpodsPitch: 0, airpodsStandingPitch: 0, airpodsSittingPitch: 0
        ))
        try context.save()
        let controller = PracticeSessionController(context: context)
        controller.start(config: .init(
            kind: .practice, targetSeconds: 60, targetPercent: 50, level: 1,
            repsTarget: 0, countsForLevel: true, goalIsDistance: false,
            targetDistanceMeters: 0, useGPS: false, postureMode: .standing, isPro: false
        ))
        let t0 = Date()
        for i in 0...70 where controller.phase != .finished {
            controller.ingest(pitch: 0, at: t0.addingTimeInterval(Double(i)))
        }
        let result = try XCTUnwrap(controller.result)
        let streak = try XCTUnwrap(try context.fetch(FetchDescriptor<StreakState>()).first)
        XCTAssertEqual(streak.longestStreak, 1, "PRECONDITION: day one, no milestone")
        XCTAssertEqual(streak.freezesAvailable, 2, "PRECONDITION: just the starting allotment")
        XCTAssertTrue(result.newAchievementTitles.contains("First practice"),
                      "PRECONDITION: summary lists new badges: \(result.newAchievementTitles)")
        XCTAssertFalse(result.newAchievementTitles.contains("Safety net"),
                       "summary newly-earned lines: \(result.newAchievementTitles)")
    }

    func testSafetyNetArrivesWithTheSevenDayMilestoneSave() throws {
        let service = StreakService(context: try makeContext())
        for d in 1...6 { service.recordSessionCompleted(at: day(d)) }
        XCTAssertFalse(AchievementCatalog.earnedIDs(
            streak: service.currentState(), sessions: [], at: day(6)
        ).contains("freeze_saved"))
        let state = service.recordSessionCompleted(at: day(7))
        XCTAssertEqual(state.freezesAvailable, 3, "PRECONDITION: the milestone bonus landed")
        XCTAssertTrue(AchievementCatalog.earnedIDs(streak: state, sessions: [], at: day(7)).contains("freeze_saved"))
    }

    // MARK: - B6 streak reads 0 for a run the next practice keeps

    func testStreakDoesNotReadZeroForARunThatTheNextPracticeWillSave() throws {
        let context = try makeContext()
        let service = StreakService(context: context)
        // Four single misses in eleven days (2, 5, 7, 10) use up every save.
        for d in [1, 3, 4, 6, 8, 9] { service.recordSessionCompleted(at: day(d)) }
        let state = service.currentState()
        XCTAssertEqual(state.freezesAvailable, 0, "PRECONDITION: no saves left")
        XCTAssertEqual(state.currentStreak, 6, "PRECONDITION: the run is intact")

        let shown = StreakService.displayStreak(for: state, at: day(11))
        let recorded = service.recordSessionCompleted(at: day(11)).currentStreak
        XCTAssertEqual(recorded, 7, "PRECONDITION: practising on day 11 keeps the run")
        XCTAssertEqual(shown, 6, "Today showed \(shown) on day 11, then \(recorded) after practising")
    }

    func testSavesShownMatchWhatTheNextPracticeHas() throws {
        let service = StreakService(context: try makeContext())
        for d in [1, 3, 4, 6, 8, 9] { service.recordSessionCompleted(at: day(d)) }
        let state = service.currentState()
        XCTAssertEqual(StreakService.displayFreezes(for: state, at: day(10)), 0, "refill not due yet")
        XCTAssertEqual(StreakService.displayFreezes(for: state, at: day(11)), 2, "weekly refill due")
        XCTAssertEqual(service.recordSessionCompleted(at: day(11)).freezesAvailable, 1,
                       "the refill landed, then one save covered day 10")
    }

    func testStreakStillReadsZeroWhenNoSaveCanCoverTheGap() {
        let noRefillDue = StreakState(currentStreak: 20, longestStreak: 20, freezesAvailable: 0,
                                      lastActiveDay: day(10), lastFreezeRefill: day(8))
        XCTAssertEqual(StreakService.displayStreak(for: noRefillDue, at: day(12)), 0)
        let twoMissed = StreakState(currentStreak: 20, longestStreak: 20, freezesAvailable: 2,
                                    lastActiveDay: day(10), lastFreezeRefill: day(1))
        XCTAssertEqual(StreakService.displayStreak(for: twoMissed, at: day(13)), 0)
    }
}
