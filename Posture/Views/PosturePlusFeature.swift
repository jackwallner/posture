import SwiftUI

/// A single Posture+ capability. One source of truth for trial-sheet and
/// paywall copy when a locked settings toggle is flipped on.
enum PosturePlusFeature: Hashable {
    case alwaysOnWatch
    case airpodsBackground
    case walkMode

    var icon: String {
        switch self {
        case .alwaysOnWatch: "applewatch"
        case .airpodsBackground: "airpods.gen3"
        case .walkMode: "figure.walk"
        }
    }

    var tint: Color { Theme.sage }

    var title: String {
        switch self {
        case .alwaysOnWatch: "Always-on Watch"
        case .airpodsBackground: "Quiet background"
        case .walkMode: "Walk mode"
        }
    }

    var detail: String {
        switch self {
        case .alwaysOnWatch: "Haptic nudges when you slouch, even with your phone away."
        case .airpodsBackground: "Head motion tracked silently while AirPods are in."
        case .walkMode: "Distance, steps, and how tall you carry your head out there."
        }
    }

    var intentHeadline: String {
        switch self {
        case .alwaysOnWatch: "Nudges on your wrist"
        case .airpodsBackground: "All-day AirPods tracking"
        case .walkMode: "Take it for a walk"
        }
    }

    var intentSubheadline: String {
        switch self {
        case .alwaysOnWatch: "Your Apple Watch quietly tracks posture and taps you when you drift."
        case .airpodsBackground: "Posture reads head motion in the background and scores your day."
        case .walkMode: "Score how tall you carry yourself on a walk, with live steps and distance."
        }
    }

    var companionFeatures: [PosturePlusFeature] {
        switch self {
        case .alwaysOnWatch: [.airpodsBackground]
        case .airpodsBackground: [.alwaysOnWatch]
        case .walkMode: [.airpodsBackground]
        }
    }

    var paywallImpressionId: String {
        switch self {
        case .alwaysOnWatch: "posture_always_on_watch_gate"
        case .airpodsBackground: "posture_airpods_background_gate"
        case .walkMode: "posture_walk_gate"
        }
    }
}
