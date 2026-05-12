import Foundation
import SwiftData

@Model
final class BeforeAfterPhoto {
    var id: UUID
    var takenAt: Date
    var fileName: String
    var headForwardAngle: Double?
    var note: String?

    init(
        id: UUID = UUID(),
        takenAt: Date = .now,
        fileName: String,
        headForwardAngle: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.takenAt = takenAt
        self.fileName = fileName
        self.headForwardAngle = headForwardAngle
        self.note = note
    }
}
