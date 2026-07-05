import Foundation

enum PostureQuality: String, Sendable {
    case good
    case borderline
    case bad
}

/// Pure scoring functions - no I/O, no state. Easy to unit test.
enum PostureScoring {
    /// Convert a single pose deviation (radians from baseline pitch) into a quality bucket.
    /// `slouchDelta` is the calibrated full-slouch reference deviation.
    /// `sensitivity`: 0 = relaxed, 1 = normal, 2 = strict.
    /// The reference is floored (7.5°) so a half-hearted calibration can't be
    /// hair-trigger, and capped (11.25°) so a theatrical chair slouch during
    /// calibration can't stretch the scale until a *standing* slouch - which
    /// only drops the head ~6–10° because it's mostly shoulders - reads as
    /// good. The cap is applied here, at scoring time, so legacy calibrations
    /// stored with the old wider cap tighten automatically.
    static func quality(deviation: Double, slouchDelta: Double, sensitivity: Int = 1) -> PostureQuality {
        let absDev = abs(deviation)
        let safeSlouch = min(max(slouchDelta, .pi / 24), .pi / 16)
        let ratio = absDev / safeSlouch
        let (goodThreshold, borderlineThreshold): (Double, Double) = switch sensitivity {
        case 0: (0.65, 1.15)  // Relaxed, only flag major slouches
        case 2: (0.35, 0.65)  // Strict, catch even slight deviations
        default: (0.50, 0.90) // Normal
        }
        if ratio < goodThreshold { return .good }
        if ratio < borderlineThreshold { return .borderline }
        return .bad
    }

    /// Pick the aligned reference for a live sample when per-posture baselines
    /// exist. The old approach averaged standing + sitting into one number,
    /// which blurred both: honest standing uprightness read as deviation
    /// (eating margin), and part of a real slouch was absorbed by the blur.
    /// Scoring against the *nearer* baseline keeps each posture honest. Head
    /// pitch alone can't tell standing from sitting, so no per-posture
    /// strictness is attempted here - the tightened slouch cap in `quality`
    /// is what keeps small-amplitude standing slouches visible.
    static func nearestBaseline(
        pitch: Double,
        standing: Double?,
        sitting: Double?,
        combined: Double
    ) -> Double {
        switch (standing, sitting) {
        case let (s?, t?):
            return abs(pitch - s) < abs(pitch - t) ? s : t
        case let (s?, nil):
            return s
        case let (nil, t?):
            return t
        default:
            return combined
        }
    }

    /// The aligned baseline plus the slouch range that belongs to it. With
    /// per-posture calibration (standing + sitting each measured tall AND
    /// slouched) the sample is judged against the nearer posture's own range -
    /// a standing slouch is a small pitch drop, a sitting collapse a big one,
    /// and sharing one delta blurred both.
    static func postureReference(
        pitch: Double,
        standing: Double?,
        sitting: Double?,
        combined: Double,
        standingSlouchDelta: Double?,
        sittingSlouchDelta: Double?,
        fallbackSlouchDelta: Double
    ) -> (baseline: Double, slouchDelta: Double) {
        switch (standing, sitting) {
        case let (s?, t?):
            if abs(pitch - s) < abs(pitch - t) {
                return (s, standingSlouchDelta ?? fallbackSlouchDelta)
            }
            return (t, sittingSlouchDelta ?? fallbackSlouchDelta)
        case let (s?, nil):
            return (s, standingSlouchDelta ?? fallbackSlouchDelta)
        case let (nil, t?):
            return (t, sittingSlouchDelta ?? fallbackSlouchDelta)
        default:
            return (combined, fallbackSlouchDelta)
        }
    }

    /// Robust deviation for a *window* of pose samples. Uses the median so a
    /// single glance down (or up) inside the window can't swing the verdict the
    /// way a mean would. Returns nil for an empty window.
    static func aggregateDeviation(samples: [Double], baseline: Double) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let mid = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return median - baseline
    }

    /// Personal slouch reference from a two-pose calibration (upright, then
    /// slouched). Floored so a half-hearted calibration slouch can't make the
    /// thresholds hair-trigger, and capped so a theatrical one can't make
    /// real slouching read as "good".
    static func calibratedSlouchDelta(uprightPitch: Double, slouchedPitch: Double) -> Double {
        let delta = abs(slouchedPitch - uprightPitch)
        return min(max(delta, .pi / 24), .pi / 8)  // 7.5°…22.5°
    }

    /// Aggregate session score 0-100 from time-in-each-quality.
    /// Good = 1.0, borderline = 0.5, bad = 0.0
    static func sessionScore(goodSeconds: Int, borderlineSeconds: Int, badSeconds: Int) -> Int {
        let total = goodSeconds + borderlineSeconds + badSeconds
        guard total > 0 else { return 0 }
        let weighted = Double(goodSeconds) + Double(borderlineSeconds) * 0.5
        return Int((weighted / Double(total) * 100).rounded())
    }

    /// Smooth a noisy stream of pose samples with a simple exponential moving average.
    static func smoothed(previous: Double?, sample: Double, alpha: Double = 0.3) -> Double {
        guard let previous else { return sample }
        return previous * (1 - alpha) + sample * alpha
    }

    // MARK: - Walk mode

    /// Walking injects rhythmic head bob that the live EMA (α 0.15) only
    /// partly absorbs, so walk scoring judges the *median over a rolling
    /// window* instead of the smoothed instant - gait oscillation cancels
    /// out of a median, a real sustained slump doesn't.
    enum Walk {
        /// Rolling window the walk verdict is computed over.
        static let windowSeconds: Double = 7
        /// The first stretch of a walk (pocketing the phone, finding stride)
        /// is excluded from the session's aligned score and timeline.
        static let warmupSeconds: Double = 30
        /// Walks score with relaxed thresholds - heads move more out there.
        static let sensitivity = 0
        /// Windowed quality must stay bad this long before a nudge.
        static let nudgeSustainSeconds: Double = 10
        /// Walk nudges are rarer than desk nudges.
        static let nudgeDebounceSeconds: Double = 45
        /// A verdict needs at least this much of the window observed.
        static var minSpanSeconds: Double { windowSeconds / 2 }
    }

    /// Median deviation of the time-stamped samples inside the walk window.
    /// Returns nil until at least `Walk.minSpanSeconds` of the window is
    /// covered - never judge a stride off a fraction of a second.
    static func walkWindowDeviation(
        samples: [(t: TimeInterval, pitch: Double)],
        baseline: Double,
        now: TimeInterval
    ) -> Double? {
        let cutoff = now - Walk.windowSeconds
        let recent = samples.filter { $0.t >= cutoff }
        guard let first = recent.first, let last = recent.last,
              last.t - first.t >= Walk.minSpanSeconds else { return nil }
        return aggregateDeviation(samples: recent.map(\.pitch), baseline: baseline)
    }

    // MARK: - Chin-tuck reps

    /// Guided chin-tuck warm-up at the start of a practice session. Constants
    /// are the tuning knobs for `ChinTuckRepDetector`.
    enum ChinTuck {
        /// Pitch excursion from baseline that counts as a real retraction (~4.5°).
        static let minExcursionRadians: Double = 0.08
        /// Back within this of baseline counts as "returned" (~2.3°).
        static let returnToleranceRadians: Double = 0.04
        /// Cycles faster than this are fidgeting, not a rep.
        static let minRepDurationSeconds: Double = 0.8
        /// Cycles longer than this are a stuck hold, not a rep.
        static let maxRepDurationSeconds: Double = 6.0
        /// Reps per practice warm-up.
        static let defaultRepsTarget: Int = 5
        /// Smoothing for the rep stream (matches the practice EMA).
        static let smoothingAlpha: Double = 0.15
    }
}

/// Stateful chin-tuck cycle detector. Feed it every (t, pitch) sample with the
/// calibrated baseline; it returns 1 when a full retract-and-return cycle
/// completes, 0 otherwise. Direction-agnostic: the first excursion past the
/// threshold latches the rep's direction, so AirPods pitch-sign differences
/// across models can't break counting, and oscillation through the baseline
/// can't double-count.
struct ChinTuckRepDetector: Sendable {
    private enum State { case neutral, excursion }

    private var state: State = .neutral
    private var excursionStartedAt: TimeInterval?
    private var excursionSign: Double = 0
    private var smoothed: Double?

    init() {}

    /// Ingest one sample. Returns the number of newly completed reps (0 or 1).
    mutating func ingest(t: TimeInterval, pitch: Double, baseline: Double) -> Int {
        smoothed = PostureScoring.smoothed(
            previous: smoothed, sample: pitch, alpha: PostureScoring.ChinTuck.smoothingAlpha
        )
        let deviation = (smoothed ?? pitch) - baseline

        switch state {
        case .neutral:
            if abs(deviation) >= PostureScoring.ChinTuck.minExcursionRadians {
                state = .excursion
                excursionStartedAt = t
                excursionSign = deviation > 0 ? 1 : -1
            }
            return 0
        case .excursion:
            guard let started = excursionStartedAt else {
                state = .neutral
                return 0
            }
            let elapsed = t - started
            if elapsed > PostureScoring.ChinTuck.maxRepDurationSeconds {
                // Stuck out there - treat as a new neutral once they return.
                if abs(deviation) <= PostureScoring.ChinTuck.returnToleranceRadians {
                    state = .neutral
                    excursionStartedAt = nil
                }
                return 0
            }
            if abs(deviation) <= PostureScoring.ChinTuck.returnToleranceRadians {
                state = .neutral
                excursionStartedAt = nil
                // Too quick to be a deliberate rep - ignore the cycle.
                return elapsed >= PostureScoring.ChinTuck.minRepDurationSeconds ? 1 : 0
            }
            return 0
        }
    }
}

extension PostureScoring {
    // MARK: - Baseline confidence

    /// Sample spread (population standard deviation, radians). Our proxy for how
    /// steady a calibration hold was: a still head has tight spread, a fidgeting
    /// one is wide. Returns 0 for fewer than two samples.
    static func standardDeviation(_ samples: [Double]) -> Double {
        guard samples.count > 1 else { return 0 }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
        return variance.squareRoot()
    }

    /// A hold this steady (radians of spread) or tighter is trusted as a clean
    /// aligned capture; anything wider means "hold still, let's try again".
    static let stableCaptureThreshold = 0.06  // ~3.4°

    /// Map a capture's spread to a 0…1 confidence. A rock-still hold is ~1; at or
    /// beyond `confidenceCeiling` of spread it's 0.
    static func captureConfidence(standardDeviation sd: Double) -> Double {
        let confidenceCeiling = 0.12  // ~6.9°
        return max(0, min(1, 1 - sd / confidenceCeiling))
    }

    /// Fold several aligned pose captures (standing, sitting) into the single
    /// baseline scoring reads. Both are "head level", so their mean is a more
    /// robust baseline than either alone. Returns nil for an empty set.
    static func combinedBaseline(_ poseMeans: [Double]) -> Double? {
        guard !poseMeans.isEmpty else { return nil }
        return poseMeans.reduce(0, +) / Double(poseMeans.count)
    }
}
