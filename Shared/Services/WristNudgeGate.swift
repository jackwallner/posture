import Foundation

/// Spaces the Watch's slouch taps. The iPhone already spaces its relays
/// (60 s all-day, 20 s in a practice session), so a relay only waits out a
/// recent wrist nudge from always-on monitoring. A wrist nudge waits out
/// either kind, so the two never stack.
struct WristNudgeGate: Sendable {
    let interval: TimeInterval
    private(set) var lastWristAt: Date?
    private(set) var lastRelayAt: Date?

    init(interval: TimeInterval = 60) {
        self.interval = interval
    }

    /// True (and records the time) when a relayed nudge at `date` may tap.
    mutating func allowRelay(at date: Date) -> Bool {
        if let lastWristAt, date.timeIntervalSince(lastWristAt) < interval { return false }
        lastRelayAt = date
        return true
    }

    /// True (and records the time) when a wrist nudge at `date` may tap.
    mutating func allowWrist(at date: Date) -> Bool {
        if let last = [lastWristAt, lastRelayAt].compactMap({ $0 }).max(),
           date.timeIntervalSince(last) < interval { return false }
        lastWristAt = date
        return true
    }
}
