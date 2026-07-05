import Foundation

/// Pure aggregation over a day's `PostureMinuteSample` rows. No I/O - views
/// query SwiftData and hand rows in, tests hand in fixtures.
struct PostureDayStats: Sendable {
    /// Total seconds the monitor was actually reading (AirPods in).
    let wearSeconds: Double
    /// 0…100, weighted good=1 / borderline=0.5 across monitored time.
    let alignedPercent: Int?
    /// Longest run of consecutive minutes whose dominant quality was good.
    let longestAlignedMinutes: Int
    /// Fraction (0…1) of monitored time per hour of the day, keyed 0–23,
    /// paired with that hour's alignment fraction. Hours with no monitoring
    /// are absent.
    let hourAlignment: [Int: Double]

    static func compute(minutes: [Ingest], calendar: Calendar = .current) -> PostureDayStats {
        let wear = minutes.reduce(0) { $0 + $1.monitoredSeconds }

        let weighted = minutes.reduce(0) { $0 + $1.goodSeconds + $1.borderlineSeconds * 0.5 }
        let percent: Int? = wear > 0 ? Int((weighted / wear * 100).rounded()) : nil

        // Longest aligned stretch: consecutive minute rows (by minuteStart)
        // dominated by good posture. A gap in monitoring breaks the run -
        // we only credit time we actually observed.
        let sorted = minutes.sorted { $0.minuteStart < $1.minuteStart }
        var longest = 0
        var run = 0
        var previous: Date?
        for m in sorted {
            let contiguous = previous.map {
                m.minuteStart.timeIntervalSince($0) <= 90
            } ?? true
            if m.dominantGood && contiguous {
                run += 1
            } else {
                run = m.dominantGood ? 1 : 0
            }
            longest = max(longest, run)
            previous = m.minuteStart
        }

        // Per-hour alignment fraction, for the day heat strip.
        var hourWeighted: [Int: Double] = [:]
        var hourTotal: [Int: Double] = [:]
        for m in minutes where m.monitoredSeconds > 0 {
            let hour = calendar.component(.hour, from: m.minuteStart)
            hourWeighted[hour, default: 0] += m.goodSeconds + m.borderlineSeconds * 0.5
            hourTotal[hour, default: 0] += m.monitoredSeconds
        }
        var hourAlignment: [Int: Double] = [:]
        for (hour, total) in hourTotal where total > 0 {
            hourAlignment[hour] = (hourWeighted[hour] ?? 0) / total
        }

        return PostureDayStats(
            wearSeconds: wear,
            alignedPercent: percent,
            longestAlignedMinutes: longest,
            hourAlignment: hourAlignment
        )
    }

    /// The slice of `PostureMinuteSample` the math needs, so tests don't have
    /// to construct SwiftData models.
    struct Ingest: Sendable {
        let minuteStart: Date
        let goodSeconds: Double
        let borderlineSeconds: Double
        let badSeconds: Double

        var monitoredSeconds: Double { goodSeconds + borderlineSeconds + badSeconds }
        var dominantGood: Bool { goodSeconds >= borderlineSeconds && goodSeconds >= badSeconds }
    }

    /// Short human wear-time: "4h 20m", "38m", "0m" when nothing yet.
    static func wearLabel(seconds: Double) -> String {
        let mins = Int(seconds / 60)
        guard mins > 0 else { return "0m" }
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }
}

extension PostureMinuteSample {
    var statsIngest: PostureDayStats.Ingest {
        .init(
            minuteStart: minuteStart,
            goodSeconds: goodSeconds,
            borderlineSeconds: borderlineSeconds,
            badSeconds: badSeconds
        )
    }
}
