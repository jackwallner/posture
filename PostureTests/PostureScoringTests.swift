import XCTest
@testable import Posture

final class PostureScoringTests: XCTestCase {
    func testQualityClassification() {
        let slouch = 0.30  // ~17°
        XCTAssertEqual(PostureScoring.quality(deviation: 0.0, slouchDelta: slouch), .good)
        XCTAssertEqual(PostureScoring.quality(deviation: 0.05, slouchDelta: slouch), .good)
        XCTAssertEqual(PostureScoring.quality(deviation: 0.15, slouchDelta: slouch), .borderline)
        XCTAssertEqual(PostureScoring.quality(deviation: 0.25, slouchDelta: slouch), .bad)
        XCTAssertEqual(PostureScoring.quality(deviation: -0.25, slouchDelta: slouch), .bad)
    }

    func testSlouchDeltaFloor() {
        // A near-zero slouch delta should be floored so we don't classify everything as "bad"
        XCTAssertEqual(PostureScoring.quality(deviation: 0.01, slouchDelta: 0.001), .good)
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
