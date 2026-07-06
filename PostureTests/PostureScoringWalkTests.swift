import XCTest
@testable import Posture

final class PostureScoringWalkTests: XCTestCase {
    /// Build a 25 Hz sample stream from `start` to `end` seconds with a
    /// pitch generator.
    private func stream(
        from start: Double, to end: Double, pitch: (Double) -> Double
    ) -> [(t: TimeInterval, pitch: Double)] {
        stride(from: start, through: end, by: 0.04).map { (t: $0, pitch: pitch($0)) }
    }

    func testNilUntilHalfWindowObserved() {
        // Only 2s of data in a 7s window (min span is 3.5s).
        let samples = stream(from: 100, to: 102) { _ in 0.1 }
        XCTAssertNil(PostureScoring.walkWindowDeviation(samples: samples, baseline: 0, now: 102))
    }

    func testVerdictOnceSpanIsCovered() {
        let samples = stream(from: 100, to: 104) { _ in 0.1 }
        let deviation = PostureScoring.walkWindowDeviation(samples: samples, baseline: 0, now: 104)
        XCTAssertEqual(try XCTUnwrap(deviation), 0.1, accuracy: 0.001)
    }

    func testGaitBobCancelsOutOfMedian() {
        // Head bob: ±0.08 rad oscillation at 2 Hz around an aligned 0.02.
        let samples = stream(from: 100, to: 107) { t in
            0.02 + 0.08 * sin(t * 2 * .pi * 2)
        }
        let deviation = try! XCTUnwrap(
            PostureScoring.walkWindowDeviation(samples: samples, baseline: 0, now: 107)
        )
        XCTAssertEqual(deviation, 0.02, accuracy: 0.02,
                       "oscillation should cancel; the median tracks the center")
    }

    func testSingleGlanceDownDoesNotFlipVerdict() {
        // Aligned walk with a 0.5s glance at the ground.
        let samples = stream(from: 100, to: 107) { t in
            (103.0...103.5).contains(t) ? 0.5 : 0.02
        }
        let deviation = try! XCTUnwrap(
            PostureScoring.walkWindowDeviation(samples: samples, baseline: 0, now: 107)
        )
        XCTAssertLessThan(abs(deviation), 0.05)
    }

    func testSustainedSlumpSurvivesTheMedian() {
        // Head down for the whole window, plus bob.
        let samples = stream(from: 100, to: 107) { t in
            0.3 + 0.06 * sin(t * 2 * .pi * 2)
        }
        let deviation = try! XCTUnwrap(
            PostureScoring.walkWindowDeviation(samples: samples, baseline: 0, now: 107)
        )
        XCTAssertGreaterThan(deviation, 0.25)
    }

    func testOldSamplesOutsideWindowAreIgnored() {
        // 10s of slumped walking followed by 7s of aligned walking: the
        // verdict at the end must only see the aligned window.
        var samples = stream(from: 100, to: 110) { _ in 0.4 }
        samples += stream(from: 110.04, to: 117) { _ in 0.02 }
        let deviation = try! XCTUnwrap(
            PostureScoring.walkWindowDeviation(samples: samples, baseline: 0, now: 117)
        )
        XCTAssertEqual(deviation, 0.02, accuracy: 0.005)
    }

    func testRelaxedSensitivityConstantsAreWalkTuned() {
        XCTAssertEqual(PostureScoring.Walk.sensitivity, 0, "walks judge with relaxed thresholds")
        XCTAssertEqual(PostureScoring.Walk.windowSeconds, 7)
        XCTAssertEqual(PostureScoring.Walk.warmupSeconds, 30)
    }

    // MARK: - Standing-anchored baseline

    func testAnchoredBaselineKeepsHonestWalkingCapture() {
        // A walking capture with a small natural lean stays as captured.
        let standing = 0.10
        let walking = standing + 0.05  // ~2.9° lean, inside the clamp
        XCTAssertEqual(
            PostureScoring.Walk.anchoredBaseline(walking: walking, standing: standing),
            walking, accuracy: 0.0001
        )
    }

    func testAnchoredBaselineClampsSlouchedCapture() {
        // A capture taken mid-slouch (way below standing) is pulled back to
        // the standing pose plus the max allowed lean.
        let standing = 0.10
        let walking = standing + 0.5  // an implausible 28° "lean"
        XCTAssertEqual(
            PostureScoring.Walk.anchoredBaseline(walking: walking, standing: standing),
            standing + PostureScoring.Walk.maxLeanFromStanding, accuracy: 0.0001
        )
    }

    func testAnchoredBaselineClampsBothDirections() {
        let standing = 0.10
        let walking = standing - 0.5
        XCTAssertEqual(
            PostureScoring.Walk.anchoredBaseline(walking: walking, standing: standing),
            standing - PostureScoring.Walk.maxLeanFromStanding, accuracy: 0.0001
        )
    }

    func testAnchoredBaselineFallsBackToStanding() {
        XCTAssertEqual(
            PostureScoring.Walk.anchoredBaseline(walking: nil, standing: 0.12),
            0.12, accuracy: 0.0001
        )
    }
}
