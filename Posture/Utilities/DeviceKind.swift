import SwiftUI

/// What the running device can do for Posture. An iPad has no pedometer
/// worth walking with, no haptic motor to buzz, and no paired Apple Watch,
/// so those surfaces step aside there.
@MainActor
enum DeviceKind {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// The device's product name, for sentences that name it ("this iPad").
    static var name: String { UIDevice.current.model }

    static var supportsWalks: Bool { !isPad }
    static var pairsWithWatch: Bool { !isPad }
}
