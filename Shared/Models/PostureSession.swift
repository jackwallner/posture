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

    var source: PostureSource {
        get { PostureSource(rawValue: sourceRaw) ?? .camera }
        set { sourceRaw = newValue.rawValue }
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
        source: PostureSource
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.score = score
        self.goodSeconds = goodSeconds
        self.borderlineSeconds = borderlineSeconds
        self.badSeconds = badSeconds
        self.sourceRaw = source.rawValue
    }
}

enum PostureSource: String, Codable, CaseIterable, Sendable {
    case camera
    case airpods
    case watch
}
