import Foundation
import SwiftData
import UserNotifications
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

    // MARK: - B9 Today claims a next reminder only when one can fire

    func testTodayDoesNotPromiseRemindersWhenNotificationsAreDenied() {
        XCTAssertFalse(NotificationService.remindersCanFire(.denied))
        XCTAssertFalse(NotificationService.remindersCanFire(.notDetermined))
        XCTAssertTrue(NotificationService.remindersCanFire(.authorized))
        XCTAssertTrue(NotificationService.remindersCanFire(.provisional))
    }

    // MARK: - B7 a wide window is never cut short

    func testWideFifteenMinuteWindowRemindsUntilTheEndHour() {
        // Settings allows Start 6 and End 23 at every 15 minutes (68 slots).
        let slots = NotificationService.checkInSlots(intervalMinutes: 15, activeHoursStart: 6, activeHoursEnd: 23)
        let last = slots.map { $0.hour * 60 + $0.minute }.max() ?? 0
        XCTAssertLessThanOrEqual(slots.count, 57, "with the 7 practice reminders, iOS holds 64")
        XCTAssertGreaterThanOrEqual(last, 22 * 60 + 30, "last reminder at \(last / 60):\(last % 60), End is 23:00")
        XCTAssertLessThan(last, 23 * 60)
        XCTAssertEqual(slots.first, .init(hour: 6, minute: 0))
    }

    func testWindowsThatFitKeepTheChosenInterval() {
        let slots = NotificationService.checkInSlots(intervalMinutes: 15, activeHoursStart: 9, activeHoursEnd: 20)
        XCTAssertEqual(slots.count, 44)
        XCTAssertEqual(slots.last, .init(hour: 19, minute: 45))
        XCTAssertEqual(NotificationService.checkInSlots(intervalMinutes: 30, activeHoursStart: 6, activeHoursEnd: 23).count, 34)
        XCTAssertEqual(NotificationService.checkInSlots(intervalMinutes: 60, activeHoursStart: 9, activeHoursEnd: 17).count, 8)
        XCTAssertTrue(NotificationService.checkInSlots(intervalMinutes: 15, activeHoursStart: 12, activeHoursEnd: 12).isEmpty)
    }

    // MARK: - B5 overlapping reschedules never interleave

    @MainActor
    private final class PassLog {
        var entries: [String] = []
    }

    @MainActor
    func testOverlappingReschedulePassesRunOneAfterAnother() async {
        let queue = SerialTaskQueue()
        let log = PassLog()
        // A pass that suspends between its writes, like one awaiting each add.
        func pass(_ name: String) -> @MainActor () async -> Void {
            {
                log.entries.append("\(name) remove")
                for i in 0..<3 {
                    try? await Task.sleep(nanoseconds: 5_000_000)
                    log.entries.append("\(name) add \(i)")
                }
            }
        }
        let first = Task { @MainActor in await queue.run(pass("A")) }
        // The second request lands while the first pass is mid-way.
        while log.entries.isEmpty { await Task.yield() }
        let second = Task { @MainActor in await queue.run(pass("B")) }
        await first.value
        await second.value
        XCTAssertEqual(log.entries, [
            "A remove", "A add 0", "A add 1", "A add 2",
            "B remove", "B add 0", "B add 1", "B add 2",
        ])
    }
}
