import XCTest
@testable import Posture

/// The rating-ask rules from the fleet policy: ask from the second launch, wait
/// out a 30-day cooldown, stop only when the user opened the review page, and
/// never let feedback stop or restart the asks.
@MainActor
final class ReviewPromptTrackerTests: XCTestCase {
    private var saved: (Int, Date?, Date?, ReviewPromptOutcome?, Int, Bool)!

    override func setUp() async throws {
        saved = (
            ReviewPromptTracker.appLaunchCount,
            ReviewPromptTracker.firstAppOpenDate,
            ReviewPromptTracker.lastShownDate,
            ReviewPromptTracker.outcome,
            ReviewPromptTracker.positiveMomentCount,
            ReviewPromptTracker.hasPendingPositiveMoment
        )
        ReviewPromptTracker.appLaunchCount = 9
        ReviewPromptTracker.firstAppOpenDate = .now
        ReviewPromptTracker.lastShownDate = nil
        ReviewPromptTracker.outcome = nil
        ReviewPromptTracker.positiveMomentCount = 0
        ReviewPromptTracker.hasPendingPositiveMoment = false
    }

    override func tearDown() async throws {
        ReviewPromptTracker.appLaunchCount = saved.0
        ReviewPromptTracker.firstAppOpenDate = saved.1
        ReviewPromptTracker.lastShownDate = saved.2
        ReviewPromptTracker.outcome = saved.3
        ReviewPromptTracker.positiveMomentCount = saved.4
        ReviewPromptTracker.hasPendingPositiveMoment = saved.5
    }

    private func days(_ n: Double) -> Date { Date.now.addingTimeInterval(n * 86_400) }

    func testAsksFromTheSecondLaunch() {
        ReviewPromptTracker.appLaunchCount = 2
        XCTAssertTrue(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
    }

    func testNeverAsksInTheFirstSession() {
        ReviewPromptTracker.appLaunchCount = 1
        XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
    }

    func testFirstPositiveMomentIsEnoughOnTheSecondLaunch() {
        ReviewPromptTracker.appLaunchCount = 2
        ReviewPromptTracker.recordPositiveMoment()
        XCTAssertTrue(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
    }

    func testRequiresFinishedSetup() {
        XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: false))
    }

    func testWaitsOutTheCooldown() {
        ReviewPromptTracker.markShown()
        XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: days(29)))
        XCTAssertTrue(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: days(31)))
    }

    func testOpeningTheReviewPageEndsTheAsks() {
        ReviewPromptTracker.markOpenedWriteReview()
        XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: days(400)))
    }

    func testFeedbackDoesNotStopTheAsks() {
        ReviewPromptTracker.markFeedbackSubmitted()
        XCTAssertTrue(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
    }

    func testFailedMailOpenIsNotFeedback() {
        ReviewPromptTracker.recordFeedbackMailOpened(false)
        XCTAssertNil(ReviewPromptTracker.outcome)
        ReviewPromptTracker.recordFeedbackMailOpened(true)
        XCTAssertEqual(ReviewPromptTracker.outcome, .submittedFeedback)
    }

    func testFeedbackAfterTheReviewPageKeepsTheAsksEnded() {
        ReviewPromptTracker.markOpenedWriteReview()
        ReviewPromptTracker.markFeedbackSubmitted()
        XCTAssertEqual(ReviewPromptTracker.outcome, .openedWriteReview)
        XCTAssertFalse(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: days(400)))
    }

    func testBlockedAskKeepsTheMomentPending() {
        ReviewPromptTracker.recordPositiveMoment()
        XCTAssertTrue(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        XCTAssertTrue(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        ReviewPromptTracker.markShown()
        XCTAssertFalse(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
    }
    func testStaleMomentNoLongerAsks() {
        let recorded = Date(timeIntervalSince1970: 1_800_000_000)
        ReviewPromptTracker.recordPositiveMoment(now: recorded)
        let fresh = recorded.addingTimeInterval(ReviewPromptTracker.pendingMomentLifetime - 1)
        let stale = recorded.addingTimeInterval(ReviewPromptTracker.pendingMomentLifetime + 1)
        XCTAssertTrue(ReviewPromptTracker.isPositiveMomentPending(now: fresh))
        XCTAssertFalse(ReviewPromptTracker.isPositiveMomentPending(now: stale))
        XCTAssertFalse(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true, now: stale))
    }

    func testMomentFlagWithNoDateFromAnOlderBuildIsStale() {
        ReviewPromptTracker.consumePendingPositiveMoment()
        ReviewPromptTracker.hasPendingPositiveMoment = true
        XCTAssertFalse(ReviewPromptTracker.isPositiveMomentPending())
    }

    func testFirstLaunchNeverAsksEvenAfterAGoodMoment() {
        ReviewPromptTracker.appLaunchCount = 1
        ReviewPromptTracker.recordPositiveMoment()
        XCTAssertFalse(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        ReviewPromptTracker.appLaunchCount = 2
        XCTAssertTrue(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
    }

    func testNoAskDuringOnboarding() {
        ReviewPromptTracker.recordPositiveMoment()
        XCTAssertFalse(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: false))
    }
}

/// Which results may ask for a rating. A good result asks; a slip or a
/// partial never does.
final class ReviewMomentTests: XCTestCase {
    func testPassedPracticeSessionAsks() {
        XCTAssertTrue(ReviewMoment.practiceSession(completed: true, passed: true))
    }

    func testPracticeSessionUnderTargetOrCutShortDoesNotAsk() {
        XCTAssertFalse(ReviewMoment.practiceSession(completed: true, passed: false))
        XCTAssertFalse(ReviewMoment.practiceSession(completed: false, passed: false))
        XCTAssertFalse(ReviewMoment.practiceSession(completed: false, passed: true))
    }

    func testGoodCheckInAsks() {
        XCTAssertTrue(ReviewMoment.checkIn(quality: .good, streakBefore: 3, streakAfter: 3))
    }

    func testBorderlineAndBadCheckInsDoNotAsk() {
        XCTAssertFalse(ReviewMoment.checkIn(quality: .borderline, streakBefore: 3, streakAfter: 4))
        XCTAssertFalse(ReviewMoment.checkIn(quality: .bad, streakBefore: 3, streakAfter: 4))
        XCTAssertFalse(ReviewMoment.checkIn(quality: nil, streakBefore: 0, streakAfter: 1))
    }

    func testStreakMilestoneAsksEvenOnAnOrdinaryCheckIn() {
        XCTAssertTrue(ReviewMoment.checkIn(quality: .borderline, streakBefore: 6, streakAfter: 7))
        XCTAssertTrue(ReviewMoment.checkIn(quality: .bad, streakBefore: 29, streakAfter: 30))
    }

    func testSittingOnAMilestoneDayDoesNotAskAgain() {
        XCTAssertFalse(ReviewMoment.checkIn(quality: .borderline, streakBefore: 7, streakAfter: 7))
    }
}
