import XCTest
@testable import Posture

/// Synthetic pitch streams through the chin-tuck cycle detector.
final class ChinTuckRepDetectorTests: XCTestCase {
    private let baseline = 0.10

    /// Feed a stream of (t, pitch) samples; return total reps counted.
    private func run(_ samples: [(Double, Double)]) -> Int {
        var detector = ChinTuckRepDetector()
        var reps = 0
        for (t, pitch) in samples {
            reps += detector.ingest(t: t, pitch: pitch, baseline: baseline)
        }
        return reps
    }

    /// A clean rep: hold at baseline, excurse well past the threshold for ~2s,
    /// return to baseline. The EMA needs a few samples to catch up, so the
    /// stream holds each plateau long enough to converge.
    private func cleanRep(startingAt t0: Double, amplitude: Double) -> [(Double, Double)] {
        var samples: [(Double, Double)] = []
        var t = t0
        // settle at baseline
        for _ in 0..<20 { samples.append((t, baseline)); t += 0.04 }
        // excursion plateau (~2s at 25 Hz)
        for _ in 0..<50 { samples.append((t, baseline + amplitude)); t += 0.04 }
        // return plateau
        for _ in 0..<30 { samples.append((t, baseline)); t += 0.04 }
        return samples
    }

    func testCleanRepCountsOnce() {
        XCTAssertEqual(run(cleanRep(startingAt: 0, amplitude: 0.15)), 1)
    }

    func testTwoRepsCountTwice() {
        let stream = cleanRep(startingAt: 0, amplitude: 0.15)
            + cleanRep(startingAt: 10, amplitude: 0.15)
        XCTAssertEqual(run(stream), 2)
    }

    func testNegativeDirectionRepCounts() {
        XCTAssertEqual(run(cleanRep(startingAt: 0, amplitude: -0.15)), 1)
    }

    func testPartialRepDoesNotCount() {
        // Never crosses the excursion threshold.
        XCTAssertEqual(run(cleanRep(startingAt: 0, amplitude: 0.05)), 0)
    }

    func testExcursionWithoutReturnDoesNotCount() {
        var samples: [(Double, Double)] = []
        var t = 0.0
        for _ in 0..<20 { samples.append((t, baseline)); t += 0.04 }
        for _ in 0..<100 { samples.append((t, baseline + 0.15)); t += 0.04 }
        XCTAssertEqual(run(samples), 0)
    }

    func testTooFastCycleIgnored() {
        // Threshold crossed and returned within < minRepDurationSeconds.
        // Raw spikes so the EMA barely has time; use raw large values.
        var samples: [(Double, Double)] = []
        var t = 0.0
        for _ in 0..<20 { samples.append((t, baseline)); t += 0.04 }
        // A blink of a spike: two samples of a huge excursion, instantly back.
        // The EMA latches the excursion but decays home well under 0.8s.
        for _ in 0..<2 { samples.append((t, baseline + 1.2)); t += 0.04 }
        for _ in 0..<60 { samples.append((t, baseline)); t += 0.04 }
        XCTAssertEqual(run(samples), 0)
    }

    func testStuckHoldThenReturnDoesNotCount() {
        // Excursion held past maxRepDurationSeconds, then a return: no rep.
        var samples: [(Double, Double)] = []
        var t = 0.0
        for _ in 0..<20 { samples.append((t, baseline)); t += 0.04 }
        for _ in 0..<200 { samples.append((t, baseline + 0.15)); t += 0.04 }  // 8s hold
        for _ in 0..<40 { samples.append((t, baseline)); t += 0.04 }
        XCTAssertEqual(run(samples), 0)
    }

    func testNoiseAroundBaselineDoesNotCount() {
        var samples: [(Double, Double)] = []
        var t = 0.0
        // Deterministic +-0.02 jitter — well inside the excursion threshold.
        for i in 0..<300 {
            let jitter = (i % 2 == 0 ? 1.0 : -1.0) * 0.02
            samples.append((t, baseline + jitter))
            t += 0.04
        }
        XCTAssertEqual(run(samples), 0)
    }

    func testRepAfterStuckHoldStillCounts() {
        var stream: [(Double, Double)] = []
        var t = 0.0
        for _ in 0..<20 { stream.append((t, baseline)); t += 0.04 }
        for _ in 0..<200 { stream.append((t, baseline + 0.15)); t += 0.04 }  // stuck
        for _ in 0..<40 { stream.append((t, baseline)); t += 0.04 }           // recover
        stream += cleanRep(startingAt: t, amplitude: 0.15)
        XCTAssertEqual(run(stream), 1)
    }
}
