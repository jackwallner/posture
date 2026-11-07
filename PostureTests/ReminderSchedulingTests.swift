import Foundation
import SwiftData
import XCTest
@testable import Posture

/// Reminder scheduling rules (state machine audit 2026-11-06). The real
/// notification center rejects requests in the test host, so these test the
/// pure planning the scheduler hands to it.
final class ReminderSchedulingTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ d: Int, hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = d; c.hour = hour; c.minute = minute
        return calendar.date(from: c)!
    }

    private func fireDates(_ triggers: [NotificationService.PracticeTrigger], after now: Date) -> [Date] {
        triggers.compactMap {
            calendar.nextDate(after: now, matching: $0.dateComponents, matchingPolicy: .nextTime)
        }.sorted()
    }

    // MARK: - B1 practice reminder skips a day whose practice is done

    func testPracticeReminderDoesNotFireTodayAfterTodaysPractice() {
        let now = date(3, hour: 8)
        let triggers = NotificationService.practiceTriggers(
            hour: 10, minute: 0, practiceDoneToday: true, now: now
        )
        let fires = fireDates(triggers, after: now)
        XCTAssertFalse(fires.contains { calendar.isDate($0, inSameDayAs: now) },
                       "practice done at 8:00, yet the 10:00 reminder still fires today")
        XCTAssertEqual(fires.first, date(4, hour: 10), "tomorrow's reminder still comes")
        XCTAssertTrue(fires.contains(date(10, hour: 10)), "same weekday next week is covered")
    }

    func testPracticeReminderFiresTodayWhenPracticeIsNotDone() {
        let now = date(3, hour: 8)
        let triggers = NotificationService.practiceTriggers(
            hour: 10, minute: 0, practiceDoneToday: false, now: now
        )
        XCTAssertEqual(fireDates(triggers, after: now).first, date(3, hour: 10))
    }

    func testPracticeReminderKeepsFiringDailyWithoutReopeningTheApp() {
        let now = date(3, hour: 8)
        for done in [true, false] {
            let triggers = NotificationService.practiceTriggers(
                hour: 10, minute: 0, practiceDoneToday: done, now: now
            )
            XCTAssertEqual(Set(triggers.map(\.identifier)).count, 7)
            XCTAssertEqual(triggers.filter(\.repeats).count, done ? 6 : 7)
            // Every day of the coming week has exactly one reminder.
            let fires = fireDates(triggers, after: date(3, hour: 23))
            XCTAssertEqual(fires, (4...10).map { date($0, hour: 10) })
        }
    }

    @MainActor
    func testPracticeDoneTodayCountsOnlyCompletedPracticesFromToday() throws {
        let schema = Schema([
            PostureSession.self, PosturePassiveSample.self, PostureMinuteSample.self,
            Calibration.self, StreakState.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self,
        ])
        let context = ModelContext(try ModelContainer(
            for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        ))
        func row(_ start: Date, kind: PostureSessionKind, completed: Bool) -> PostureSession {
            PostureSession(startedAt: start, durationSeconds: 180, score: 80, goodSeconds: 180,
                           borderlineSeconds: 0, badSeconds: 0, source: .airpods, kind: kind,
                           completed: completed)
        }
        context.insert(row(date(2, hour: 9), kind: .practice, completed: true))
        context.insert(row(date(3, hour: 7), kind: .practice, completed: false))
        context.insert(row(date(3, hour: 7), kind: .walk, completed: true))
        try context.save()
        XCTAssertFalse(TodaySnapshot.practiceCompleted(in: context, at: date(3, hour: 8)))
        context.insert(row(date(3, hour: 8), kind: .practice, completed: true))
        try context.save()
        XCTAssertTrue(TodaySnapshot.practiceCompleted(in: context, at: date(3, hour: 9)))
    }
}
