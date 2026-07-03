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
    static func quality(deviation: Double, slouchDelta: Double, sensitivity: Int = 1) -> PostureQuality {
        let absDev = abs(deviation)
        let safeSlouch = max(slouchDelta, .pi / 24)  // floor at 7.5°
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
}
