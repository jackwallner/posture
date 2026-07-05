import Foundation
import SwiftData

/// One minute of continuous monitoring, aggregated from the ~25 Hz head-pose
/// stream. This is the persistent record of *how the user actually sat*, not
/// just when they slouched badly enough to be nudged - it powers the day
/// timeline, "% of day aligned", wear time, and longest-aligned-stretch stats.
@Model
final class PostureMinuteSample {
    var id: UUID
    /// Start of the minute this row covers (truncated to the minute).
    var minuteStart: Date
    /// Seconds of the minute spent in each quality bucket. They sum to the
    /// monitored portion of the minute (< 60 when AirPods were only in for
    /// part of it).
    var goodSeconds: Double
    var borderlineSeconds: Double
    var badSeconds: Double
    var sourceRaw: String

    var source: PostureSource {
        get { PostureSource(rawValue: sourceRaw) ?? .airpods }
        set { sourceRaw = newValue.rawValue }
    }

    /// Monitored seconds in this minute.
    var monitoredSeconds: Double { goodSeconds + borderlineSeconds + badSeconds }

    /// 0…1 alignment for the minute: good counts fully, borderline half.
    var alignmentFraction: Double {
        let total = monitoredSeconds
        guard total > 0 else { return 0 }
        return (goodSeconds + borderlineSeconds * 0.5) / total
    }

    /// The quality the user spent most of this minute in.
    var dominantQuality: PostureQuality {
        if goodSeconds >= borderlineSeconds && goodSeconds >= badSeconds { return .good }
        if borderlineSeconds >= badSeconds { return .borderline }
        return .bad
    }

    init(
        id: UUID = UUID(),
        minuteStart: Date,
        goodSeconds: Double,
        borderlineSeconds: Double,
        badSeconds: Double,
        source: PostureSource
    ) {
        self.id = id
        self.minuteStart = minuteStart
        self.goodSeconds = goodSeconds
        self.borderlineSeconds = borderlineSeconds
        self.badSeconds = badSeconds
        self.sourceRaw = source.rawValue
    }
}
