import Foundation

/// Lets one nudge through per `interval`. The Watch uses it for slouch taps
/// relayed from the iPhone, with the iPhone nudge's own 60 s spacing, so a
/// relay never stacks on a wrist nudge the Watch just gave itself.
struct NudgeDebounce: Sendable {
    let interval: TimeInterval
    private(set) var lastFiredAt: Date?

    init(interval: TimeInterval = 60) {
        self.interval = interval
    }

    /// True (and records the time) when a nudge at `date` is allowed.
    mutating func allow(at date: Date) -> Bool {
        if let lastFiredAt, date.timeIntervalSince(lastFiredAt) < interval { return false }
        lastFiredAt = date
        return true
    }

    /// Records a nudge given some other way, so the next one waits it out.
    mutating func note(at date: Date) {
        lastFiredAt = date
    }
}
