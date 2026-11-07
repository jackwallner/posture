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
