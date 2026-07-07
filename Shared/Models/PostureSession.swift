import Foundation
import SwiftData

@Model
final class PostureSession {
    var id: UUID
    var startedAt: Date
    var durationSeconds: Int
    var score: Int
    var goodSeconds: Int
    var borderlineSeconds: Int
    var badSeconds: Int
    var sourceRaw: String

    // Daily-practice fields (2026-07 practice pivot). All defaulted so the
    // SwiftData migration is lightweight. `kindRaw` defaults to `legacy` so
    // camera-era rows can never count toward the practice level.
    var kindRaw: String = PostureSessionKind.legacy.rawValue
    var targetSeconds: Int = 0
    var targetPercent: Int = 0
    var alignedPercent: Int = 0
    /// The user finished the full target duration (streak credit).
    var completed: Bool = false
    /// The session met its aligned-% target (level credit).
    var passed: Bool = false

    // Which posture this practice session trained (2026-07 standing/sitting
    // split). Empty on walks, legacy rows, and pre-split practice sessions;
    // those pre-split passes are grandfathered into BOTH ladders at read time
    // (see `PracticeSessionController.passedPracticeCount(context:mode:)`), so
    // nobody loses a level. Additive, defaulted -> lightweight migration.
    var postureModeRaw: String = ""

    // Walk metrics (2026-07 walk rework). Defaulted so the migration stays
    // lightweight; zero on practice rows and pre-rework walks.
    /// Best available walked distance in meters (GPS when active, else the
    /// pedometer estimate). 0 when unknown.
    var distanceMeters: Double = 0
    /// Steps counted during the walk (pedometer). 0 when unknown.
    var steps: Int = 0
    /// The walk's goal was a distance, not a duration.
    var goalIsDistance: Bool = false
    /// Target distance in meters when `goalIsDistance` (0 otherwise).
    var targetDistanceMeters: Double = 0

    var source: PostureSource {
        get { PostureSource(rawValue: sourceRaw) ?? .camera }
        set { sourceRaw = newValue.rawValue }
    }

    var kind: PostureSessionKind {
        get { PostureSessionKind(rawValue: kindRaw) ?? .legacy }
        set { kindRaw = newValue.rawValue }
    }

    /// Standing/sitting for practice rows; nil on walks, legacy, and pre-split rows.
    var postureMode: PostureMode? {
        get { PostureMode(rawValue: postureModeRaw) }
        set { postureModeRaw = newValue?.rawValue ?? "" }
    }

    var dayKey: Date { Calendar.current.startOfDay(for: startedAt) }

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        durationSeconds: Int,
        score: Int,
        goodSeconds: Int,
        borderlineSeconds: Int,
        badSeconds: Int,
        source: PostureSource,
        kind: PostureSessionKind = .legacy,
        postureMode: PostureMode? = nil,
        targetSeconds: Int = 0,
        targetPercent: Int = 0,
        alignedPercent: Int = 0,
        completed: Bool = false,
        passed: Bool = false,
        distanceMeters: Double = 0,
        steps: Int = 0,
        goalIsDistance: Bool = false,
        targetDistanceMeters: Double = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.score = score
        self.goodSeconds = goodSeconds
        self.borderlineSeconds = borderlineSeconds
        self.badSeconds = badSeconds
        self.sourceRaw = source.rawValue
        self.kindRaw = kind.rawValue
        self.postureModeRaw = postureMode?.rawValue ?? ""
        self.targetSeconds = targetSeconds
        self.targetPercent = targetPercent
        self.alignedPercent = alignedPercent
        self.completed = completed
        self.passed = passed
        self.distanceMeters = distanceMeters
        self.steps = steps
        self.goalIsDistance = goalIsDistance
        self.targetDistanceMeters = targetDistanceMeters
    }
}

enum PostureSessionKind: String, Codable, Sendable {
    /// Pre-pivot rows (camera-era or unknown). Never counted for levels.
    case legacy
    /// The bounded daily-practice session.
    case practice
    /// A walking session (Pro). Credits the streak, not the level.
    case walk
}

enum PostureSource: String, Codable, CaseIterable, Sendable {
    case camera
    case airpods
    case watch
}

/// Which posture a practice session trains. A "both"-focus user picks one per
/// session and each has its own level ladder; single-focus users only ever use
/// their one mode. Legacy/walk rows carry no mode.
enum PostureMode: String, Codable, CaseIterable, Sendable {
    case standing
    case sitting

    var label: String {
        switch self {
        case .standing: return "Standing"
        case .sitting: return "Sitting"
        }
    }

    /// Lowercased for inline copy ("standing tall").
    var word: String {
        switch self {
        case .standing: return "standing"
        case .sitting: return "sitting"
        }
    }

    var icon: String {
        switch self {
        case .standing: return "figure.stand"
        case .sitting: return "figure.seated.side"
        }
    }
}
