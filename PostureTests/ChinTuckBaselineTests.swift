import XCTest
@testable import Posture

/// The warm-up counts chin tucks against the calibrated rest pose of the
/// posture being trained. A seated user rests at their sitting baseline, which
/// sits a few degrees off their standing one; measuring the tucks from the
/// standing baseline leaves the detector stuck in an excursion.
final class ChinTuckBaselineTests: XCTestCase {
    private let standing = 0.00
    /// 0.06 rad is about 3.4 degrees above standing rest.
    private let sitting = 0.06
    private var combined: Double { (standing + sitting) / 2 }

    func testSittingSessionUsesTheSittingBaseline() {
        let baseline = PostureScoring.ChinTuck.repBaseline(
            standing: standing, sitting: sitting, combined: combined, mode: .sitting
        )
        XCTAssertEqual(baseline, sitting, accuracy: 1e-9)
    }

    func testStandingSessionUsesTheStandingBaseline() {
        let baseline = PostureScoring.ChinTuck.repBaseline(
            standing: standing, sitting: sitting, combined: combined, mode: .standing
        )
        XCTAssertEqual(baseline, standing, accuracy: 1e-9)
    }

    func testSessionWithoutAModeKeepsTheStandingBaseline() {
        let baseline = PostureScoring.ChinTuck.repBaseline(
            standing: standing, sitting: sitting, combined: combined, mode: nil
        )
        XCTAssertEqual(baseline, standing, accuracy: 1e-9)
    }

    func testMissingPostureBaselineFallsBackToTheCombinedOne() {
        XCTAssertEqual(
            PostureScoring.ChinTuck.repBaseline(standing: standing, sitting: nil, combined: combined, mode: .sitting),
            combined, accuracy: 1e-9
        )
        XCTAssertEqual(
            PostureScoring.ChinTuck.repBaseline(standing: nil, sitting: sitting, combined: combined, mode: .standing),
            combined, accuracy: 1e-9
        )
    }

    /// Five clean tucks by a seated user, scored the way the controller scores
    /// them: from the baseline the session's mode selects.
    func testSeatedTucksAllCountInASittingSession() {
        let baseline = PostureScoring.ChinTuck.repBaseline(
            standing: standing, sitting: sitting, combined: combined, mode: .sitting
        )
        XCTAssertEqual(countedReps(restPitch: sitting, baseline: baseline), 5)
    }

    func testSeatedTucksAllCountInAStandingSessionForAStandingUser() {
        let baseline = PostureScoring.ChinTuck.repBaseline(
            standing: standing, sitting: sitting, combined: combined, mode: .standing
        )
        XCTAssertEqual(countedReps(restPitch: standing, baseline: baseline), 5)
    }

    /// Rests at `restPitch`, then five tucks: the head pulls back 0.12 rad over
    /// ~0.6 s, holds ~1.2 s, returns over ~0.6 s, then rests ~3 s. 25 Hz.
    private func countedReps(restPitch: Double, baseline: Double) -> Int {
        let tuck = 0.12
        var detector = ChinTuckRepDetector()
        var t = 0.0
        var counted = 0
        func feed(_ pitch: Double) {
            counted += detector.ingest(t: t, pitch: pitch, baseline: baseline)
            t += 0.04
        }
        for _ in 0..<75 { feed(restPitch) }
        for _ in 0..<5 {
            for i in 0..<15 { feed(restPitch - tuck * Double(i + 1) / 15) }
            for _ in 0..<30 { feed(restPitch - tuck) }
            for i in 0..<15 { feed(restPitch - tuck * Double(14 - i) / 15) }
            for _ in 0..<75 { feed(restPitch) }
        }
        return counted
    }
}
