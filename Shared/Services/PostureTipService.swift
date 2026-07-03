import Foundation

/// A single posture education tip.
struct PostureTip: Sendable {
    let text: String
    let category: TipCategory
}

enum TipCategory: String, Sendable {
    case ergonomics
    case habit
    case stretch
    case awareness
}

/// Static library of posture education tips. Rotates based on context.
enum PostureTipService {
    private static let tips: [PostureTip] = [
        // Ergonomics
        PostureTip(text: "Set your screen at eye level to prevent forward head tilt.", category: .ergonomics),
        PostureTip(text: "Keep your feet flat on the floor and knees at 90 degrees.", category: .ergonomics),
        PostureTip(text: "Your elbows should rest at 90 degrees when typing, so adjust chair height if not.", category: .ergonomics),
        PostureTip(text: "The top of your monitor should be at or just below eye level.", category: .ergonomics),

        // Habits
        PostureTip(text: "Most slouching happens after 30 minutes of sitting. Try a standing break.", category: .habit),
        PostureTip(text: "Check your shoulders, they tend to creep up toward your ears when stressed.", category: .habit),
        PostureTip(text: "Tuck your chin slightly to align your head over your spine.", category: .habit),
        PostureTip(text: "Set a timer to check your posture, since awareness is the first step to improvement.", category: .habit),

        // Stretches
        PostureTip(text: "Roll your shoulders back and down 5 times to reset your posture.", category: .stretch),
        PostureTip(text: "Chin tucks: pull your head back like you're making a double chin, hold 5 seconds.", category: .stretch),
        PostureTip(text: "Stand up and reach for the ceiling. A 10-second stretch resets your alignment.", category: .stretch),

        // Awareness
        PostureTip(text: "Your posture often mirrors your mood, so stand tall to feel more confident.", category: .awareness),
        PostureTip(text: "Deep breathing expands your ribcage, so inhale tall, exhale relaxed.", category: .awareness),
        PostureTip(text: "Phone posture: bring the phone to eye level instead of looking down at it.", category: .awareness),
    ]

    /// Returns a random tip.
    static func randomTip() -> PostureTip {
        tips.randomElement() ?? tips[0]
    }

    /// Returns tips filtered by category.
    static func tips(category: TipCategory) -> [PostureTip] {
        tips.filter { $0.category == category }
    }

    /// Returns all tips.
    static var allTips: [PostureTip] { tips }
}
