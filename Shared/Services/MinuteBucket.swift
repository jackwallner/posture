import Foundation

/// Folds a scored ~25 Hz posture stream into per-minute good/borderline/bad
/// second buckets - the persistence-ready shape behind `PostureMinuteSample`.
/// Pure value type shared by the all-day monitor and bounded sessions so the
/// two never disagree about how observed time is attributed.
struct MinuteBucket {
    /// One completed (or force-flushed) minute ready to persist.
    struct Flush: Equatable {
        let minuteStart: Date
        let goodSeconds: Double
        let borderlineSeconds: Double
        let badSeconds: Double
    }

    /// Gaps longer than this mean the stream was interrupted (pods out, app
    /// suspended mid-read) and that time was not observed - never credit it.
    static let maxSampleGapSeconds: Double = 2

    /// Buckets thinner than this aren't worth a row.
    static let minFlushSeconds: Double = 1

    private var bucketStart: Date?
    private var goodSeconds: Double = 0
    private var borderlineSeconds: Double = 0
    private var badSeconds: Double = 0
    private var lastSampleAt: Date?

    /// Credit the gap since the previous scored sample to `quality`.
    /// Returns the seconds actually credited (0 for the first sample after a
    /// reset) and a flush when the minute rolled over.
    mutating func accumulate(quality: PostureQuality, at now: Date) -> (credited: Double, flush: Flush?) {
        var flushed: Flush?
        let minute = Self.truncateToMinute(now)
        if let bucket = bucketStart, bucket != minute {
            flushed = flush()
        }
        if bucketStart == nil { bucketStart = minute }

        let dt = lastSampleAt.map { min(max(now.timeIntervalSince($0), 0), Self.maxSampleGapSeconds) } ?? 0
        lastSampleAt = now
        switch quality {
        case .good: goodSeconds += dt
        case .borderline: borderlineSeconds += dt
        case .bad: badSeconds += dt
        }
        return (dt, flushed)
    }

    /// Emit the in-progress minute (if it holds at least `minFlushSeconds`)
    /// and reset. Call on minute rollover, pause, stop, or disconnect so
    /// partial minutes aren't lost.
    mutating func flush() -> Flush? {
        defer {
            bucketStart = nil
            goodSeconds = 0
            borderlineSeconds = 0
            badSeconds = 0
            lastSampleAt = nil
        }
        guard let start = bucketStart else { return nil }
        let total = goodSeconds + borderlineSeconds + badSeconds
        guard total >= Self.minFlushSeconds else { return nil }
        return Flush(
            minuteStart: start,
            goodSeconds: goodSeconds,
            borderlineSeconds: borderlineSeconds,
            badSeconds: badSeconds
        )
    }

    static func truncateToMinute(_ date: Date) -> Date {
        let cal = Calendar.current
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return cal.date(from: parts) ?? date
    }
}
