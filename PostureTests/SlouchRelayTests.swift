import XCTest
@testable import Posture

/// Watch slouch relay: the wrist gets one tap per nudge, from the
/// notification mirror when the phone is locked and from WatchConnectivity
/// otherwise.
final class SlouchRelayTests: XCTestCase {
    func testForegroundRelaysToReachableWatchWithoutNotification() {
        let d = SlouchNudge.delivery(inBackground: false, phoneLocked: false, watchReachable: true)
        XCTAssertEqual(d, .init(notification: false, watchMessage: true))
    }

    func testUnlockedBackgroundPostsNotificationAndRelays() {
        let d = SlouchNudge.delivery(inBackground: true, phoneLocked: false, watchReachable: true)
        XCTAssertEqual(d, .init(notification: true, watchMessage: true))
    }

    func testLockedPhoneLeavesTheWatchToTheMirror() {
        let d = SlouchNudge.delivery(inBackground: true, phoneLocked: true, watchReachable: true)
        XCTAssertEqual(d, .init(notification: true, watchMessage: false))
    }

    func testUnreachableWatchGetsNoMessage() {
        let d = SlouchNudge.delivery(inBackground: false, phoneLocked: false, watchReachable: false)
        XCTAssertEqual(d, .init(notification: false, watchMessage: false))
    }

    func testRelaysFollowThePhonesOwnSpacing() {
        var gate = WristNudgeGate()
        let t0 = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(gate.allowRelay(at: t0))
        XCTAssertTrue(gate.allowRelay(at: t0.addingTimeInterval(20)))
    }

    func testWristNudgeHoldsOffARelay() {
        var gate = WristNudgeGate()
        let t0 = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(gate.allowWrist(at: t0))
        XCTAssertFalse(gate.allowRelay(at: t0.addingTimeInterval(30)))
        XCTAssertTrue(gate.allowRelay(at: t0.addingTimeInterval(60)))
    }

    func testRelayHoldsOffAWristNudge() {
        var gate = WristNudgeGate()
        let t0 = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(gate.allowRelay(at: t0))
        XCTAssertFalse(gate.allowWrist(at: t0.addingTimeInterval(59)))
        XCTAssertTrue(gate.allowWrist(at: t0.addingTimeInterval(60)))
        XCTAssertFalse(gate.allowWrist(at: t0.addingTimeInterval(90)))
    }
}

/// Shortcuts automations: the monitoring intent starts monitoring only for a
/// Pro user who has seen the all-day disclosure; everyone else lands in Settings.
@MainActor
final class PostureIntentTests: XCTestCase {
    override func tearDown() async throws {
        IntentRouter.shared.pending = nil
        IntentRouter.shared.settingsPrompt = nil
    }

    func testNonProLandsOnTheProGate() {
        XCTAssertEqual(IntentRouter.monitoringRoute(isPro: false, allDayEnabled: false), .settings(.proGate))
        XCTAssertEqual(IntentRouter.monitoringRoute(isPro: false, allDayEnabled: true), .settings(.proGate))
    }

    func testProWithoutAllDayConfirmsFirst() {
        XCTAssertEqual(IntentRouter.monitoringRoute(isPro: true, allDayEnabled: false), .settings(.confirmAllDay))
    }

    func testProWithAllDayStarts() {
        XCTAssertEqual(IntentRouter.monitoringRoute(isPro: true, allDayEnabled: true), .start)
    }

    func testIntentsQueueTheirRequest() async throws {
        _ = try await StartMonitoringIntent().perform()
        XCTAssertEqual(IntentRouter.shared.pending, .startMonitoring)
        _ = try await StartPracticeIntent().perform()
        XCTAssertEqual(IntentRouter.shared.pending, .startPractice)
    }

    func testIntentsOpenTheApp() {
        XCTAssertTrue(StartMonitoringIntent.openAppWhenRun)
        XCTAssertTrue(StartPracticeIntent.openAppWhenRun)
    }
}
