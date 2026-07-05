import Foundation

enum PostureQuality: String, Sendable {
    case good
    case borderline
    case bad
}

/// Pure scoring functions — no I/O, no state. Easy to unit test.
enum PostureScoring {
    /// Convert a single pose deviation (radians from baseline pitch) into a quality bucket.
    /// `slouchDelta` is the calibrated full-slouch reference deviation.
    /// `sensitivity`: 0 = relaxed, 1 = normal, 2 = strict.
    /// The reference is floored (7.5°) so a half-hearted calibration can't be
    /// hair-trigger, and capped (11.25°) so a theatrical chair slouch during
    /// calibration can't stretch the scale until a *standing* slouch — which
    /// only drops the head ~6–10° because it's mostly shoulders — reads as
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
    /// strictness is attempted here — the tightened slouch cap in `quality`
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
