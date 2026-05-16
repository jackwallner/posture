import Foundation
import SwiftData

@Model
final class AcknowledgmentRecord {
    var id: UUID
    var timestamp: Date
    var methodRaw: String
    var qualityRaw: String?
    var deviation: Double?
    var scheduledAt: Date

    var method: AcknowledgmentMethod {
        get { AcknowledgmentMethod(rawValue: methodRaw) ?? .manual }
        set { methodRaw = newValue.rawValue }
    }

    var quality: PostureQuality? {
        get { qualityRaw.flatMap { PostureQuality(rawValue: $0) } }
        set { qualityRaw = newValue?.rawValue }
    }

    var dayKey: Date { Calendar.current.startOfDay(for: timestamp) }

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        method: AcknowledgmentMethod,
        quality: PostureQuality? = nil,
        deviation: Double? = nil,
        scheduledAt: Date
    ) {
        self.id = id
        self.timestamp = timestamp
        self.methodRaw = method.rawValue
        self.qualityRaw = quality?.rawValue
        self.deviation = deviation
        self.scheduledAt = scheduledAt
    }
}

enum AcknowledgmentMethod: String, Codable, Sendable {
    case camera
    case manual
}
