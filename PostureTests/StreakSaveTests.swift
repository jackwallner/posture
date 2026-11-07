import Foundation
import SwiftData
import XCTest
@testable import Posture

/// Streak save rules (state machine audit 2026-11-06, B4). Every
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
}
