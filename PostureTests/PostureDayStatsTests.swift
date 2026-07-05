import XCTest
@testable import Posture

final class PostureDayStatsTests: XCTestCase {
    private func minute(_ offset: Int, good: Double = 0, borderline: Double = 0, bad: Double = 0) -> PostureDayStats.Ingest {
        let base = Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: .now
        )!
        return .init(
            minuteStart: base.addingTimeInterval(TimeInterval(offset * 60)),
            goodSeconds: good,
            borderlineSeconds: borderline,
            badSeconds: bad
        )
    }

    func testEmptyDay() {
        let stats = PostureDayStats.compute(minutes: [])
        XCTAssertEqual(stats.wearSeconds, 0)
        XCTAssertNil(stats.alignedPercent)
        XCTAssertEqual(stats.longestAlignedMinutes, 0)
        XCTAssertTrue(stats.hourAlignment.isEmpty)
    }

    func testAlignedPercentWeighting() {
        // 60s good + 60s borderline → (60 + 30) / 120 = 75%.
        let stats = PostureDayStats.compute(minutes: [
            minute(0, good: 60),
            minute(1, borderline: 60),
        ])
        XCTAssertEqual(stats.alignedPercent, 75)
        XCTAssertEqual(stats.wearSeconds, 120)
    }

    func testLongestAlignedStretchCountsConsecutiveGoodMinutes() {
        let stats = PostureDayStats.compute(minutes: [
            minute(0, good: 60),
            minute(1, good: 50, bad: 10),   // still dominated by good
            minute(2, bad: 60),             // breaks the run
            minute(3, good: 60),
        ])
        XCTAssertEqual(stats.longestAlignedMinutes, 2)
    }

    func testMonitoringGapBreaksAlignedStretch() {
        // Two good minutes separated by a 10-minute gap: unobserved time is
        // never credited, so the run is 1, not 2.
        let stats = PostureDayStats.compute(minutes: [
            minute(0, good: 60),
            minute(10, good: 60),
        ])
        XCTAssertEqual(stats.longestAlignedMinutes, 1)
    }

    func testHourAlignmentBuckets() {
        let stats = PostureDayStats.compute(minutes: [
            minute(0, good: 60),   // 9:00
            minute(1, bad: 60),    // 9:01
        ])
        XCTAssertEqual(stats.hourAlignment[9] ?? -1, 0.5, accuracy: 0.001)
    }

    func testWearLabel() {
        XCTAssertEqual(PostureDayStats.wearLabel(seconds: 0), "0m")
        XCTAssertEqual(PostureDayStats.wearLabel(seconds: 40 * 60), "40m")
        XCTAssertEqual(PostureDayStats.wearLabel(seconds: 4 * 3600 + 20 * 60), "4h 20m")
    }
}
