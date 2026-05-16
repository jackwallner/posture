import SwiftUI

/// Daylight design system. iOS resolves colors from the asset catalog
/// (light + dark variants live in `Posture/Assets.xcassets`). watchOS has
/// no Daylight colorsets, so it falls back to literal dark-mode values —
/// the watch UI is out of scope for the Daylight pass but must keep
/// compiling and stay legible on its black background.
enum Theme {
    #if os(watchOS)
    static let paper   = Color(red: 0.090, green: 0.086, blue: 0.078)
    static let paper2  = Color(red: 0.129, green: 0.122, blue: 0.106)
    static let paper3  = Color(red: 0.165, green: 0.153, blue: 0.133)
    static let ink     = Color(red: 0.937, green: 0.914, blue: 0.863)
    static let ink2    = Color(red: 0.718, green: 0.682, blue: 0.616)
    static let ink3    = Color(red: 0.486, green: 0.455, blue: 0.392)
    static let sage     = Color(red: 0.561, green: 0.702, blue: 0.620)
    static let sageTint = Color(red: 0.165, green: 0.231, blue: 0.200)
    static let sand     = Color(red: 0.867, green: 0.690, blue: 0.478)
    static let sandTint = Color(red: 0.227, green: 0.184, blue: 0.118)
    static let clay     = Color(red: 0.878, green: 0.588, blue: 0.478)
    static let clayTint = Color(red: 0.231, green: 0.161, blue: 0.125)
    #else
    static let paper     = Color("DaylightPaper")
    static let paper2    = Color("DaylightPaper2")
    static let paper3    = Color("DaylightPaper3")
    static let ink       = Color("DaylightInk")
    static let ink2      = Color("DaylightInk2")
    static let ink3      = Color("DaylightInk3")
    static let sage      = Color("DaylightSage")
    static let sageTint  = Color("DaylightSageTint")
    static let sand      = Color("DaylightSand")
    static let sandTint  = Color("DaylightSandTint")
    static let clay      = Color("DaylightClay")
    static let clayTint  = Color("DaylightClayTint")
    #endif

    // MARK: - Posture quality

    static let good       = sage   // alignment ≥ 80 — "aligned"
    static let borderline = sand   // alignment 50–79 — "drifting"
    static let bad        = clay   // alignment < 50 — "resting"

    // MARK: - Semantic aliases (kept until call-sites migrate to Daylight tokens)

    static let background       = paper
    static let cardSurface      = paper2
    static let cardSurfaceLight = paper3
    static let ringTrack        = paper3
    static let textPrimary      = ink
    static let textSecondary    = ink2
    static let textTertiary     = ink3

    /// Daylight cuts the brand gradient. These aliases keep legacy
    /// call-sites compiling and adopting sage until each screen is
    /// rebuilt; remove once no view references them.
    static let brandPrimary   = sage
    static let brandSecondary = sage
    static let streakFlame    = ink2

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [sage, sage], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Geometry

    static let cardRadius: CGFloat = 20
    static let cardPadding: CGFloat = 20

    // MARK: - Type

    /// Legacy rounded-bold numeric. Kept for unmigrated call-sites.
    static func bigNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Daylight ritual type — serif italic for the moments you pause for.
    static func displaySerif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }

    /// Daylight numerics — rounded, monospaced digits for meta/eyebrows.
    static func roundedNumeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func qualityColor(_ quality: PostureQuality) -> Color {
        switch quality {
        case .good: return good
        case .borderline: return borderline
        case .bad: return bad
        }
    }
}
