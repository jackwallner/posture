#if os(watchOS)
import Foundation
import WatchKit

/// One wrist tap per slouch, whichever side spotted it: the iPhone relays its
/// nudge when the phone is unlocked or Posture is open there (a locked phone
/// mirrors its notification instead), and always-on monitoring nudges from
/// wrist motion. Both share the iPhone nudge's 60 s debounce.
@MainActor
enum WatchSlouchHaptic {
    private static var debounce = NudgeDebounce()
    /// A relay older than this arrived too late to mean "right now".
    private static let maxRelayAge: TimeInterval = 30

    static func playRelayed(sentAt: Date, now: Date = .now) {
        guard now.timeIntervalSince(sentAt) < maxRelayAge else { return }
        play(at: now)
    }

    static func play(at date: Date = .now) {
        guard debounce.allow(at: date) else { return }
        WKInterfaceDevice.current().play(.notification)
    }
}
#endif
