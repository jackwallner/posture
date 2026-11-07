import Foundation
import SwiftData
import XCTest
@testable import Posture

/// The watch and the widgets show the phone's streak and today's score
/// (state machine audit 2026-11-06, B2 and B3).
@MainActor
final class TodaySnapshotTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            PostureSession.self, PosturePassiveSample.self, PostureMinuteSample.self,
            Calibration.self, StreakState.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func day(_ d: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = d; c.hour = hour
        return Calendar.current.date(from: c)!
    }

    private func practice(at date: Date, aligned: Int, completed: Bool = true) -> PostureSession {
        let row = PostureSession(
            durationSeconds: 180, score: aligned, goodSeconds: 180, borderlineSeconds: 0, badSeconds: 0,
            source: .airpods, kind: .practice, postureMode: .standing, targetSeconds: 180,
            targetPercent: 70, alignedPercent: aligned, completed: completed, passed: aligned >= 70
        )
        row.startedAt = date
        return row
    }

    /// Drives the real controller through one full, aligned practice with
    /// synthetic samples, exactly as the app finishes one.
    private func completePractice(in context: ModelContext) throws -> PracticeSessionController {
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
        XCTAssertEqual(controller.result?.completed, true, "PRECONDITION: session completed")
        return controller
    }

    // MARK: - B2 iPhone widget shows a practice score

    func testCompletedPracticeGivesTheWidgetATodayScore() throws {
        let context = try makeContext()
        let controller = try completePractice(in: context)
        let aligned = try XCTUnwrap(controller.result?.alignedPercent)
        XCTAssertEqual(TodaySnapshot.todayScore(in: context), aligned)
    }

    func testWidgetScoreIsTheBestOfTodayAndIgnoresPartialsAndYesterday() throws {
        let context = try makeContext()
        XCTAssertNil(TodaySnapshot.todayScore(in: context, at: day(5)))
        context.insert(practice(at: day(4, hour: 9), aligned: 99))
        context.insert(practice(at: day(5, hour: 8), aligned: 95, completed: false))
        context.insert(AcknowledgmentRecord(timestamp: day(5, hour: 9), method: .manual, quality: .borderline, scheduledAt: day(5, hour: 9)))
        try context.save()
        XCTAssertEqual(TodaySnapshot.todayScore(in: context, at: day(5)), 55)
        context.insert(practice(at: day(5, hour: 10), aligned: 72))
        try context.save()
        XCTAssertEqual(TodaySnapshot.todayScore(in: context, at: day(5)), 72)
    }

    // MARK: - B3 watch reads the phone's streak and score

    func testWatchGetsThePhoneStreakAndTodayScore() throws {
        let context = try makeContext()
        let service = StreakService(context: context)
        for d in 1...5 { service.recordSessionCompleted(at: day(d)) }
        context.insert(practice(at: day(5, hour: 9), aligned: 82))
        try context.save()

        let sent = WatchSyncService.applicationContext(
            alwaysOnEnabled: false, isPro: false,
            today: TodaySnapshot.make(from: context, at: day(5))
        )
        let received = try XCTUnwrap(TodaySnapshot.decode(sent[TodaySnapshot.storageKey]))

        XCTAssertEqual(received.streak(at: day(5, hour: 20)), 5)
        XCTAssertEqual(received.score(at: day(5, hour: 20)), 82)
    }

    func testWatchStreakAndScoreAgeLikeThePhone() throws {
        let context = try makeContext()
        let service = StreakService(context: context)
        for d in 1...5 { service.recordSessionCompleted(at: day(d)) }
        context.insert(practice(at: day(5, hour: 9), aligned: 82))
        try context.save()
        let snapshot = TodaySnapshot.make(from: context, at: day(5))

        XCTAssertNil(snapshot.score(at: day(6)), "yesterday's score is not today's")
        XCTAssertEqual(snapshot.streak(at: day(6)), 5, "the run is still alive the next day")
        let state = try XCTUnwrap(try context.fetch(FetchDescriptor<StreakState>()).first)
        XCTAssertEqual(snapshot.streak(at: day(9)), StreakService.displayStreak(for: state, at: day(9)))
    }

    func testWatchStoresWhatThePhoneSent() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TodaySnapshotTests"))
        defaults.removePersistentDomain(forName: "TodaySnapshotTests")
        XCTAssertNil(TodaySnapshot.stored(in: defaults))
        let snapshot = TodaySnapshot(
            currentStreak: 3, lastActiveDay: day(5), freezesAvailable: 2,
            lastFreezeRefill: nil, todayScore: 70, scoreDay: Calendar.current.startOfDay(for: day(5))
        )
        snapshot.store(in: defaults)
        XCTAssertEqual(TodaySnapshot.stored(in: defaults), snapshot)
    }
}
