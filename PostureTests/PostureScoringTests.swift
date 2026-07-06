import XCTest
@testable import Posture

final class PostureScoringTests: XCTestCase {
    func testMedian() {
        XCTAssertNil(PostureScoring.median([]))
        XCTAssertEqual(PostureScoring.median([0.4]), 0.4)
        // Odd count → middle value; robust to an outlier.
        XCTAssertEqual(PostureScoring.median([0.1, 0.2, 0.9]), 0.2)
        XCTAssertEqual(PostureScoring.median([0.9, 0.1, 0.2]), 0.2)  // unsorted input
        // Even count → mean of the two middles.
        XCTAssertEqual(PostureScoring.median([0.1, 0.2, 0.3, 0.4])!, 0.25, accuracy: 1e-9)
    }

    func testQualityClassification() {
        // Normal sensitivity thresholds: good < 0.50, borderline < 0.90 of the
        // effective slouch reference. The reference is capped at π/16 (~11°)
        // at scoring time so small-amplitude standing slouches register, so a
        // 0.30 rad calibration scores against ~0.196.
        let slouch = 0.30  // ~17°, capped to π/16 when scoring
        XCTAssertEqual(PostureScoring.quality(deviation: 0.0, slouchDelta: slouch), .good)
        XCTAssertEqual(PostureScoring.quality(deviation: 0.05, slouchDelta: slouch), .good)
        XCTAssertEqual(PostureScoring.quality(deviation: 0.12, slouchDelta: slouch), .borderline)
        XCTAssertEqual(PostureScoring.quality(deviation: 0.20, slouchDelta: slouch), .bad)
        XCTAssertEqual(PostureScoring.quality(deviation: -0.20, slouchDelta: slouch), .bad)
    }

    func testSensitivityOrdering() {
        // The same middling deviation gets stricter as sensitivity rises.
        let slouch = 0.30  // capped to ~0.196 at scoring time
        let dev = 0.12     // ratio ~0.61 of the capped reference
        XCTAssertEqual(PostureScoring.quality(deviation: dev, slouchDelta: slouch, sensitivity: 0), .good)
        XCTAssertEqual(PostureScoring.quality(deviation: dev, slouchDelta: slouch, sensitivity: 1), .borderline)
        XCTAssertEqual(PostureScoring.quality(deviation: dev, slouchDelta: slouch, sensitivity: 2), .borderline)
    }

    func testAggregateDeviationUsesMedian() {
        // One outlier glance-down should not move the verdict off the median.
        let baseline = 0.10
        let samples = [0.11, 0.10, 0.12, 0.11, 0.55]  // last is a spike
        let dev = PostureScoring.aggregateDeviation(samples: samples, baseline: baseline)
        XCTAssertEqual(dev ?? 0, 0.01, accuracy: 0.0001)  // median 0.11 - 0.10
    }

    func testAggregateDeviationEmpty() {
        XCTAssertNil(PostureScoring.aggregateDeviation(samples: [], baseline: 0.1))
    }

    func testSlouchDeltaFloor() {
        // A near-zero slouch delta should be floored so we don't classify everything as "bad"
        XCTAssertEqual(PostureScoring.quality(deviation: 0.01, slouchDelta: 0.001), .good)
    }

    func testCalibratedSlouchDeltaTypical() {
        // 17° slouch below a 5° upright baseline → personal range of 17°
        let delta = PostureScoring.calibratedSlouchDelta(uprightPitch: 0.087, slouchedPitch: 0.087 - 0.30)
        XCTAssertEqual(delta, 0.30, accuracy: 0.001)
    }

    func testCalibratedSlouchDeltaDirectionAgnostic() {
        let down = PostureScoring.calibratedSlouchDelta(uprightPitch: 0.1, slouchedPitch: -0.2)
        let up = PostureScoring.calibratedSlouchDelta(uprightPitch: -0.2, slouchedPitch: 0.1)
        XCTAssertEqual(down, up)
    }

    func testCalibratedSlouchDeltaFloor() {
        // Barely moving during the slouch pose can't produce hair-trigger thresholds
        let delta = PostureScoring.calibratedSlouchDelta(uprightPitch: 0.0, slouchedPitch: 0.01)
        XCTAssertEqual(delta, .pi / 24, accuracy: 0.0001)
    }

    func testCalibratedSlouchDeltaCap() {
        // A theatrical calibration slouch can't make real slouching read as good
        let delta = PostureScoring.calibratedSlouchDelta(uprightPitch: 0.0, slouchedPitch: 1.2)
        XCTAssertEqual(delta, .pi / 8, accuracy: 0.0001)
    }

    func testSessionScorePerfect() {
        XCTAssertEqual(PostureScoring.sessionScore(goodSeconds: 60, borderlineSeconds: 0, badSeconds: 0), 100)
    }

    func testSessionScoreZero() {
        XCTAssertEqual(PostureScoring.sessionScore(goodSeconds: 0, borderlineSeconds: 0, badSeconds: 60), 0)
    }

    func testSessionScoreMixed() {
        XCTAssertEqual(PostureScoring.sessionScore(goodSeconds: 30, borderlineSeconds: 30, badSeconds: 0), 75)
        XCTAssertEqual(PostureScoring.sessionScore(goodSeconds: 0, borderlineSeconds: 60, badSeconds: 0), 50)
    }

    func testSessionScoreEmpty() {
        XCTAssertEqual(PostureScoring.sessionScore(goodSeconds: 0, borderlineSeconds: 0, badSeconds: 0), 0)
    }

    // MARK: - Nearest-baseline scoring (standing vs sitting)

    func testNearestBaselinePicksSitting() {
        let b = PostureScoring.nearestBaseline(pitch: 0.07, standing: -0.02, sitting: 0.06, combined: 0.02)
        XCTAssertEqual(b, 0.06)
    }

    func testNearestBaselinePicksStanding() {
        let b = PostureScoring.nearestBaseline(pitch: -0.01, standing: -0.02, sitting: 0.06, combined: 0.02)
        XCTAssertEqual(b, -0.02)
    }

    func testNearestBaselineFallsBackToCombined() {
        XCTAssertEqual(
            PostureScoring.nearestBaseline(pitch: 0.1, standing: nil, sitting: nil, combined: 0.02),
            0.02
        )
    }

    func testNearestBaselineSinglePosture() {
        XCTAssertEqual(
            PostureScoring.nearestBaseline(pitch: 0.3, standing: nil, sitting: 0.05, combined: 0.02),
            0.05
        )
    }

    func testStandingSlouchCaughtByCappedReference() {
        // The regression that motivated the tighter cap: a standing slouch is
        // mostly shoulders, so the head only drops ~0.10–0.12 rad. Against a
        // theatrical calibrated chair-slouch reference (0.30 rad) that read as
        // "good". With the scoring-time cap it must at least read as drifting.
        let standing = -0.02, sitting = 0.00
        let slouchDelta = 0.30
        let slouchPitch = standing + 0.12

        // Old behavior (uncapped reference): dev 0.11 / 0.30 → good.
        // (Reconstructed with the raw ratio math to document the regression.)
        XCTAssertLessThan(abs(slouchPitch - (standing + sitting) / 2) / slouchDelta, 0.5)

        let baseline = PostureScoring.nearestBaseline(
            pitch: slouchPitch, standing: standing, sitting: sitting, combined: -0.01
        )
        let quality = PostureScoring.quality(
            deviation: slouchPitch - baseline,
            slouchDelta: slouchDelta
        )
        XCTAssertNotEqual(quality, .good)
    }

    func testSlouchReferenceCapAppliedAtScoringTime() {
        // Legacy calibrations stored deltas up to π/8; scoring must cap them.
        // deviation 0.15 vs stored 0.39: uncapped ratio 0.38 → good;
        // capped at π/16 the ratio is 0.76 → borderline.
        XCTAssertEqual(
            PostureScoring.quality(deviation: 0.15, slouchDelta: .pi / 8),
            .borderline
        )
    }

    func testSmoothedFirstSample() {
        XCTAssertEqual(PostureScoring.smoothed(previous: nil, sample: 0.5), 0.5)
    }

    func testSmoothedConverges() {
        var v: Double? = 0
        for _ in 0..<20 {
            v = PostureScoring.smoothed(previous: v, sample: 1.0)
        }
        XCTAssertEqual(v ?? 0, 1.0, accuracy: 0.05)
    }
}
