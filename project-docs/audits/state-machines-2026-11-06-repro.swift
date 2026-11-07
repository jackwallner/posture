// State machine audit repro suite, 2026-11-06. Not compiled: copy to
// PostureTests/StateMachineAuditRepro.swift to run it with
//   gh-sim test --scheme Posture --only PostureTests/StateMachineAuditRepro
// Recorded run (gh-sim, Xcode 27.1, iPhone 17, iOS 27.2): 4 passed, 10 failed.
//   Passed (controls): testControlCheckInIsVisibleToTheWidgetQuery,
//     testControlDisplayKeepsRunWhenOneSaveRemains,
//     testControlFirstSaveSpentRefillsOnlyOnTheNextRecord,
//     testControlNoStreakRowEarnsNoSafetyNet.
//   Failed on the claim: testFirstEverPracticeDoesNotAnnounceAnEarnedStreakSave,
//     testStreakChipDoesNotReadZeroForARunThatTheNextPracticeWillSave,
//     testSpentSaveRefillsWeeklyNotTheNextDay,
//     testCompletedPracticeGivesTheWidgetATodayScore (writer side only).
//   Failed on a PRECONDITION (blocked, proves nothing): every test that reads
//     the real UNUserNotificationCenter. The simulator test host is not
//     authorised for notifications, so the center accepts no request
//     (testControlDefaultWindowSchedulesEverySlot saw 0 pending, expected 44).
//     NotificationService has no injection seam, so those claims stay Code path.
import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import Posture

/// State machine audit repro suite (2026-11-06). Failing tests are expected:
/// each `test...` asserts the PROMISED behaviour and fails on the shipped code.
/// Each test first asserts its own preconditions, so a failure message that
/// starts with "PRECONDITION" means a broken setup, not the claim.
/// `testControl...` tests pass on the shipped code.
@MainActor
final class StateMachineAuditRepro: XCTestCase {
    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            PostureSession.self, PosturePassiveSample.self, PostureMinuteSample.self,
            Calibration.self, StreakState.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func day(_ year: Int, _ month: Int, _ d: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = d; c.hour = hour
        return Calendar.current.date(from: c)!
    }

    /// Drives the real controller through one full, aligned practice session
    /// with synthetic samples (the `ingest` seam), exactly as the app finishes one.
    private func completePractice(
        in context: ModelContext
    ) throws -> PracticeSessionController {
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
        XCTAssertEqual(controller.phase, .waiting, "PRECONDITION: session armed")
        let t0 = Date()
        for i in 0...70 where controller.phase != .finished {
            controller.ingest(pitch: 0, at: t0.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(controller.phase, .finished, "PRECONDITION: session finished")
        XCTAssertEqual(controller.result?.completed, true, "PRECONDITION: session completed")
        return controller
    }

    private func clearReminders() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        // Let the removal land before the test reads the queue.
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private func pending() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    private func checkInSlots() async -> [UNNotificationRequest] {
        await pending().filter { $0.identifier.hasPrefix("posture.reminder.") }
    }

    override func tearDown() async throws {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - R1 practice reminder keeps its slot after the practice is done

    func testControlPracticeReminderIsPendingForTodayBeforePractice() async throws {
        await clearReminders()
        await NotificationService.schedulePracticeReminder(hour: 23, minute: 59)
        let request = await pending().first { $0.identifier == NotificationService.practiceReminderIdentifier }
        XCTAssertNotNil(request, "PRECONDITION: the practice reminder was accepted by the center")
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.repeats, true)
        let next = try XCTUnwrap(trigger?.nextTriggerDate())
        XCTAssertTrue(Calendar.current.isDateInToday(next), "PRECONDITION: reminder is due later today")
    }

    func testPracticeReminderDoesNotTellYouPracticeIsWaitingAfterYouFinishedToday() async throws {
        await clearReminders()
        await NotificationService.schedulePracticeReminder(hour: 23, minute: 59)
        let before = await pending().first { $0.identifier == NotificationService.practiceReminderIdentifier }
        let beforeNext = (before?.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        XCTAssertNotNil(beforeNext, "PRECONDITION: reminder pending")
        XCTAssertTrue(beforeNext.map { Calendar.current.isDateInToday($0) } ?? false,
                      "PRECONDITION: reminder due later today")

        let context = try makeContext()
        _ = try completePractice(in: context)
        let streak = try XCTUnwrap(try context.fetch(FetchDescriptor<StreakState>()).first)
        XCTAssertEqual(streak.currentStreak, 1, "PRECONDITION: today's streak day was credited")

        let after = await pending().first { $0.identifier == NotificationService.practiceReminderIdentifier }
        let afterNext = (after?.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        let firesToday = afterNext.map { Calendar.current.isDateInToday($0) } ?? false
        XCTAssertFalse(
            firesToday,
            "Practice is done and the streak credited, yet '\(after?.content.title ?? "nil")' is still due today at \(String(describing: afterNext))"
        )
    }

    // MARK: - R2 widget reads a table a practice never writes

    func testControlCheckInIsVisibleToTheWidgetQuery() throws {
        let context = try makeContext()
        context.insert(AcknowledgmentRecord(timestamp: .now, method: .manual, quality: .good, scheduledAt: .now))
        try context.save()
        XCTAssertEqual(try widgetScoredAcks(context), 1)
    }

    func testCompletedPracticeGivesTheWidgetATodayScore() throws {
        let context = try makeContext()
        _ = try completePractice(in: context)
        let sessions = try context.fetch(FetchDescriptor<PostureSession>())
        XCTAssertEqual(sessions.filter { $0.kind == .practice && $0.completed }.count, 1,
                       "PRECONDITION: the practice row exists")
        // Same predicate as PostureLockScreenWidget.load() and PostureWatchWidget.load().
        XCTAssertGreaterThanOrEqual(try widgetScoredAcks(context), 1,
                                    "widget shows 'No check-in yet today' after a completed practice")
    }

    private func widgetScoredAcks(_ context: ModelContext) throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<AcknowledgmentRecord> { ack in
            ack.timestamp >= startOfDay && ack.qualityRaw != nil
        }
        return try context.fetch(FetchDescriptor<AcknowledgmentRecord>(predicate: predicate)).count
    }

    // MARK: - R3 overlapping reschedules leave stale check-in slots

    func testControlSequentialRescheduleLeavesOnlyTheNewSlots() async throws {
        await clearReminders()
        await NotificationService.scheduleReminders(intervalMinutes: 15, activeHoursStart: 6, activeHoursEnd: 23)
        await NotificationService.scheduleReminders(intervalMinutes: 60, activeHoursStart: 9, activeHoursEnd: 17)
        let slots = await checkInSlots()
        XCTAssertEqual(slots.count, 8)
    }

    func testOverlappingRemindersChangesLeaveOnlyTheLatestSettingsPending() async throws {
        var outcomes: [Int] = []
        for _ in 0..<3 {
            await clearReminders()
            let first = Task {
                await NotificationService.scheduleReminders(intervalMinutes: 15, activeHoursStart: 6, activeHoursEnd: 23)
            }
            // Wait until the first run is mid-flight (a stepper tap lands while
            // the previous reschedule is still adding slots).
            var seen = 0
            for _ in 0..<200 where seen < 5 {
                seen = await checkInSlots().count
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            XCTAssertGreaterThanOrEqual(seen, 5, "PRECONDITION: first reschedule is under way")
            XCTAssertLessThan(seen, 60, "PRECONDITION: first reschedule has not already finished")
            let second = Task {
                await NotificationService.scheduleReminders(intervalMinutes: 60, activeHoursStart: 9, activeHoursEnd: 17)
            }
            await first.value
            await second.value
            outcomes.append(await checkInSlots().count)
        }
        // Latest settings: hourly 9:00-16:00 = 8 slots.
        XCTAssertEqual(outcomes, [8, 8, 8], "pending check-in slot counts per run, latest settings promise 8")
    }

    // MARK: - R4 slot cap silently drops the end of the window

    func testControlDefaultWindowSchedulesEverySlot() async throws {
        await clearReminders()
        await NotificationService.scheduleReminders(intervalMinutes: 15, activeHoursStart: 9, activeHoursEnd: 20)
        let slots = await checkInSlots()
        XCTAssertEqual(slots.count, 44)
    }

    func testWideWindowAtFifteenMinutesRemindsUntilTheEndHourTheUserPicked() async throws {
        await clearReminders()
        // Settings allows Start at 6 and End at 23 with Every 15 minutes.
        await NotificationService.scheduleReminders(intervalMinutes: 15, activeHoursStart: 6, activeHoursEnd: 23)
        let slots = await checkInSlots()
        XCTAssertGreaterThan(slots.count, 0, "PRECONDITION: center accepted slots")
        let lastMinute = slots.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }
            .compactMap { c in c.hour.flatMap { h in c.minute.map { h * 60 + $0 } } }
            .max() ?? 0
        XCTAssertEqual(slots.count, 68, "17 hours at 15 minutes is 68 slots; got \(slots.count), last at \(lastMinute / 60):\(lastMinute % 60)")
    }

    // MARK: - R5/R6 streak saves

    func testControlDisplayKeepsRunWhenOneSaveRemains() {
        let state = StreakState(currentStreak: 20, longestStreak: 20, freezesAvailable: 1,
                                lastActiveDay: day(2026, 6, 1), lastFreezeRefill: day(2026, 5, 20))
        XCTAssertEqual(StreakService.displayStreak(for: state, at: day(2026, 6, 3)), 20)
    }

    func testStreakChipDoesNotReadZeroForARunThatTheNextPracticeWillSave() {
        let state = StreakState(currentStreak: 20, longestStreak: 20, freezesAvailable: 0,
                                lastActiveDay: day(2026, 6, 1), lastFreezeRefill: day(2026, 5, 20))
        let today = day(2026, 6, 3)
        XCTAssertEqual(DateHelpers.daysBetween(state.lastActiveDay!, today), 2, "PRECONDITION: one missed day")
        XCTAssertGreaterThanOrEqual(
            DateHelpers.daysBetween(state.lastFreezeRefill!, today), 7, "PRECONDITION: weekly refill is due")
        let shown = StreakService.displayStreak(for: state, at: today)

        // What recording today's practice does (StreakService.record order).
        StreakService.refillFreezesIfNeeded(state, at: today)
        StreakService.applySession(to: state, at: today)
        XCTAssertEqual(state.currentStreak, 21, "PRECONDITION: the run was never lost")

        XCTAssertEqual(shown, 20, "Today and Streak detail showed \(shown) before the practice, 21 after")
    }

    func testControlFirstSaveSpentRefillsOnlyOnTheNextRecord() throws {
        let context = try makeContext()
        let service = StreakService(context: context)
        service.recordSessionCompleted(at: day(2026, 6, 1))
        let state = service.recordSessionCompleted(at: day(2026, 6, 3)) // missed 6/2
        XCTAssertEqual(state.freezesAvailable, 1, "a save was spent")
    }

    func testSpentSaveRefillsWeeklyNotTheNextDay() throws {
        let context = try makeContext()
        let service = StreakService(context: context)
        service.recordSessionCompleted(at: day(2026, 6, 1))
        let spent = service.recordSessionCompleted(at: day(2026, 6, 3)) // missed 6/2, save spent
        XCTAssertEqual(spent.freezesAvailable, 1, "PRECONDITION: a save was spent")
        XCTAssertNil(spent.lastFreezeRefill, "PRECONDITION: no refill has happened yet")
        let next = service.recordSessionCompleted(at: day(2026, 6, 4))
        XCTAssertEqual(next.freezesAvailable, 1, "saves refill weekly; one day later it is \(next.freezesAvailable)")
    }

    // MARK: - R7 'Safety net' badge on day one

    func testControlNoStreakRowEarnsNoSafetyNet() {
        XCTAssertFalse(AchievementCatalog.earnedIDs(streak: nil, sessions: []).contains("freeze_saved"))
    }

    func testFirstEverPracticeDoesNotAnnounceAnEarnedStreakSave() throws {
        let context = try makeContext()
        let controller = try completePractice(in: context)
        let result = try XCTUnwrap(controller.result)
        let streak = try XCTUnwrap(try context.fetch(FetchDescriptor<StreakState>()).first)
        XCTAssertEqual(streak.longestStreak, 1, "PRECONDITION: day one, no milestone")
        XCTAssertEqual(streak.freezesAvailable, 2, "PRECONDITION: just the starting allotment")
        XCTAssertTrue(result.newAchievementTitles.contains("First practice"),
                      "PRECONDITION: summary lists new badges: \(result.newAchievementTitles)")
        XCTAssertFalse(result.newAchievementTitles.contains("Safety net"),
                       "summary newly-earned lines: \(result.newAchievementTitles)")
    }
}
