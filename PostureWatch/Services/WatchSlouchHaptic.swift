#if os(watchOS)
import Foundation
import WatchKit

/// One wrist tap per slouch, whichever side spotted it: the iPhone relays its
/// nudge when the phone is unlocked or Posture is open there (a locked phone
/// mirrors its notification instead), and always-on monitoring nudges from
/// wrist motion. `WristNudgeGate` keeps the two from stacking.
@MainActor
enum WatchSlouchHaptic {
    private static var gate = WristNudgeGate()
    /// A relay older than this arrived too late to mean "right now".
    private static let maxRelayAge: TimeInterval = 30

    static func playRelayed(sentAt: Date, now: Date = .now) {
        guard now.timeIntervalSince(sentAt) < maxRelayAge, gate.allowRelay(at: now) else { return }
        WKInterfaceDevice.current().play(.notification)
    }

    static func play(at date: Date = .now) {
        guard gate.allowWrist(at: date) else { return }
        WKInterfaceDevice.current().play(.notification)
    }
}
#endif
