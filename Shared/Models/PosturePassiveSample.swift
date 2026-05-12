import Foundation
import SwiftData

@Model
final class PosturePassiveSample {
    var id: UUID
    var timestamp: Date
    var severity: Double
    var sourceRaw: String

    var source: PostureSource {
        get { PostureSource(rawValue: sourceRaw) ?? .watch }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        severity: Double,
        source: PostureSource
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.sourceRaw = source.rawValue
    }
}
