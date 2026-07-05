import XCTest
@testable import Posture

final class MinuteBucketTests: XCTestCase {
    private let base = Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 4, hour: 10, minute: 0, second: 0)
    )!

    func testFirstSampleCreditsNothing() {
        var bucket = MinuteBucket()
        let (credited, flush) = bucket.accumulate(quality: .good, at: base)
        XCTAssertEqual(credited, 0)
        XCTAssertNil(flush)
    }

    func testSteadyStreamCreditsElapsedTime() {
        var bucket = MinuteBucket()
        var credited: Double = 0
        // 25 Hz for 2 seconds.
        for tick in 0...50 {
            let t = base.addingTimeInterval(Double(tick) * 0.04)
            credited += bucket.accumulate(quality: .good, at: t).credited
        }
        XCTAssertEqual(credited, 2.0, accuracy: 0.01)
    }

    func testGapIsClampedToTwoSeconds() {
        var bucket = MinuteBucket()
        _ = bucket.accumulate(quality: .good, at: base)
        // Stream interrupted for 30s — only 2s may be credited.
        let (credited, _) = bucket.accumulate(quality: .good, at: base.addingTimeInterval(30))
        XCTAssertEqual(credited, 2.0)
    }

    func testNegativeGapCreditsNothing() {
        var bucket = MinuteBucket()
        _ = bucket.accumulate(quality: .good, at: base)
        let (credited, _) = bucket.accumulate(quality: .good, at: base.addingTimeInterval(-5))
        XCTAssertEqual(credited, 0)
    }

    func testMinuteRolloverFlushes() {
        var bucket = MinuteBucket()
        // 10s of good in minute 0 (samples every second from :50 to :59).
        for tick in 0...9 {
            _ = bucket.accumulate(quality: .good, at: base.addingTimeInterval(50 + Double(tick)))
        }
        // First sample in minute 1 flushes minute 0.
        let (_, flush) = bucket.accumulate(quality: .bad, at: base.addingTimeInterval(61))
        let flushed = try! XCTUnwrap(flush)
        XCTAssertEqual(flushed.minuteStart, base)
        XCTAssertEqual(flushed.goodSeconds, 9.0, accuracy: 0.01)
        XCTAssertEqual(flushed.badSeconds, 0)
    }

    func testQualityAttribution() {
        var bucket = MinuteBucket()
        _ = bucket.accumulate(quality: .good, at: base)
        _ = bucket.accumulate(quality: .good, at: base.addingTimeInterval(1))
        _ = bucket.accumulate(quality: .borderline, at: base.addingTimeInterval(2))
        _ = bucket.accumulate(quality: .bad, at: base.addingTimeInterval(3))
        let flush = try! XCTUnwrap(bucket.flush())
        XCTAssertEqual(flush.goodSeconds, 1.0, accuracy: 0.01)
        XCTAssertEqual(flush.borderlineSeconds, 1.0, accuracy: 0.01)
        XCTAssertEqual(flush.badSeconds, 1.0, accuracy: 0.01)
    }

    func testThinBucketDoesNotFlush() {
        var bucket = MinuteBucket()
        _ = bucket.accumulate(quality: .good, at: base)
        _ = bucket.accumulate(quality: .good, at: base.addingTimeInterval(0.5))
        XCTAssertNil(bucket.flush(), "under 1s of observed time isn't worth a row")
    }

    func testFlushResetsState() {
        var bucket = MinuteBucket()
        _ = bucket.accumulate(quality: .good, at: base)
        _ = bucket.accumulate(quality: .good, at: base.addingTimeInterval(2))
        XCTAssertNotNil(bucket.flush())
        XCTAssertNil(bucket.flush(), "second flush has nothing to emit")
        // Next sample after a flush credits nothing (no phantom gap).
        let (credited, _) = bucket.accumulate(quality: .good, at: base.addingTimeInterval(10))
        XCTAssertEqual(credited, 0)
    }
}
