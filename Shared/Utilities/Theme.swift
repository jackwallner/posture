import SwiftUI

/// Daylight design system. iOS resolves colors from the asset catalog
/// (light + dark variants live in `Posture/Assets.xcassets`). watchOS has
/// no Daylight colorsets, so it falls back to literal dark-mode values -
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
    // Calm pastel palette - soft mint canvas, white cards, deep slate ink,
    // lavender accent for ritual moments, soft sage/sand/coral for posture
    // quality. Literal colors rather than the legacy asset-catalog
    // Daylight* colorsets; those are no longer referenced.
    static let paper     = Color(red: 0.910, green: 0.957, blue: 0.937) // #E8F4EF mint canvas
    static let paper2    = Color(red: 1.000, green: 1.000, blue: 1.000) // pure white card
    static let paper3    = Color(red: 0.957, green: 0.976, blue: 0.969) // #F4F9F7 track/divider
    static let ink       = Color(red: 0.184, green: 0.243, blue: 0.227) // #2F3E3A deep slate
    // Secondary/tertiary ink darkened (2026-07): the originals (#6B7B76 /
    // #9AA8A4) fell below readable contrast on the mint canvas - ink3 sat
    // near 2.2:1. These hold ~5:1 and ~3.5:1 respectively.
    static let ink2      = Color(red: 0.353, green: 0.420, blue: 0.396) // #5A6B65 secondary
    static let ink3      = Color(red: 0.459, green: 0.514, blue: 0.494) // #75837E tertiary
    static let sage      = Color(red: 0.561, green: 0.773, blue: 0.659) // #8FC5A8 calm green
    static let sageTint  = Color(red: 0.871, green: 0.945, blue: 0.910) // pale sage wash
    static let sand      = Color(red: 0.910, green: 0.784, blue: 0.588) // #E8C896 warm pastel
    static let sandTint  = Color(red: 0.980, green: 0.945, blue: 0.882) // pale sand wash
    static let clay      = Color(red: 0.910, green: 0.627, blue: 0.604) // #E8A09A coral
    static let clayTint  = Color(red: 0.980, green: 0.910, blue: 0.898) // pale coral wash
    static let lavender     = Color(red: 0.749, green: 0.659, blue: 0.894) // #BFA8E4 ritual accent
    static let lavenderTint = Color(red: 0.945, green: 0.922, blue: 0.969)
    #endif

    #if os(watchOS)
    static let lavender     = Color(red: 0.749, green: 0.659, blue: 0.894)
    static let lavenderTint = Color(red: 0.220, green: 0.188, blue: 0.290)
    #endif

    // MARK: - Posture quality

    static let good       = sage   // alignment ≥ 80 - "aligned"
    static let borderline = sand   // alignment 50–79 - "drifting"
    static let bad        = clay   // alignment < 50 - "resting"

    // Text-grade quality colors. The pastel fills work as ring strokes and
    // chip washes but wash out as words on the light canvas ("Slouching" in
    // pastel coral read near 1.9:1). Any quality-colored TEXT uses these.
    // watchOS keeps the pastels - they sit on a black background there.
    #if os(watchOS)
    static let goodText       = sage
    static let borderlineText = sand
    static let badText        = clay
    #else
    static let goodText       = Color(red: 0.263, green: 0.494, blue: 0.373) // deep sage
    static let borderlineText = Color(red: 0.604, green: 0.427, blue: 0.141) // deep amber
    static let badText        = Color(red: 0.716, green: 0.322, blue: 0.278) // deep coral
    #endif

    static func qualityTextColor(_ quality: PostureQuality) -> Color {
        switch quality {
        case .good: return goodText
        case .borderline: return borderlineText
        case .bad: return badText
        }
    }

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

    // MARK: - Dawn direction (visual register)

    /// Pre-dawn page wash - lavender cresting at the top, fading into the
    /// mint canvas. The recurring surface where ritual lives (Stage A · C).
    static var dawnWash: LinearGradient {
        LinearGradient(
            colors: [lavenderTint, paper, paper],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Score-ring sweep - sand into lavender, so the moment of measurement
    /// and the moment of ritual visually blend (Stage A · C).
    static var ringSweep: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [sand, lavender]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    // MARK: - Geometry

    static let cardRadius: CGFloat = 24
    static let cardPadding: CGFloat = 22
    static let ctaRadius: CGFloat = 28

    // MARK: - Type

    /// One typeface everywhere: Nunito (bundled, OFL). Warm rounded
    /// terminals that fit the Daylight register without being the stock
    /// SF-rounded every template app ships. watchOS keeps system rounded -
    /// the watch targets don't bundle the font files.
    #if os(watchOS)
    static func font(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    #else
    static func font(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(nunitoName(weight), size: size, relativeTo: style)
    }

    private static func nunitoName(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Nunito-Bold"
        case .semibold: return "Nunito-SemiBold"
        case .medium: return "Nunito-Medium"
        default: return "Nunito-Regular"
        }
    }
    #endif

    /// Text-style shorthand: `Theme.font(.footnote, weight: .semibold)`.
    /// Sizes track the iOS default type ramp and scale with Dynamic Type
    /// via `relativeTo`.
    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        font(size: styleSize(style), weight: weight, relativeTo: style)
    }

    private static func styleSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    /// Legacy bold numeric. Kept for unmigrated call-sites.
    static func bigNumber(_ size: CGFloat) -> Font {
        font(size: size, weight: .bold)
    }

    /// Display type for headline moments. One confident voice; hierarchy
    /// comes from size + weight only.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        font(size: size, weight: weight)
    }

    /// Numerics - monospaced digits for meta/eyebrows and timers.
    static func roundedNumeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        font(size: size, weight: weight).monospacedDigit()
    }

    static func qualityColor(_ quality: PostureQuality) -> Color {
        switch quality {
        case .good: return good
        case .borderline: return borderline
        case .bad: return bad
        }
    }
}

// MARK: - Dawn surfaces

extension View {
    /// Dawn page background: the pre-dawn wash beneath the content.
    func dawnBackground() -> some View {
        background(Theme.dawnWash.ignoresSafeArea())
    }

    /// Dawn card surface: a translucent glass panel with a hairline edge,
    /// replacing the opaque white card of the Daylight base register.
    func dawnCard(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(shape.fill(Theme.paper2.opacity(0.55)))
            .background(shape.fill(.ultraThinMaterial))
            .overlay(shape.stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    /// Dawn pill surface - the capsule-shaped sibling of `dawnCard`.
    func dawnCapsule() -> some View {
        self
            .background(Capsule().fill(Theme.paper2.opacity(0.55)))
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }
}
