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

    var source: PostureSource {
        get { PostureSource(rawValue: sourceRaw) ?? .camera }
        set { sourceRaw = newValue.rawValue }
    }

    var kind: PostureSessionKind {
        get { PostureSessionKind(rawValue: kindRaw) ?? .legacy }
        set { kindRaw = newValue.rawValue }
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
        targetSeconds: Int = 0,
        targetPercent: Int = 0,
        alignedPercent: Int = 0,
        completed: Bool = false,
        passed: Bool = false
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
        self.targetSeconds = targetSeconds
        self.targetPercent = targetPercent
        self.alignedPercent = alignedPercent
        self.completed = completed
        self.passed = passed
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
