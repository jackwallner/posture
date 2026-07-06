import Foundation
import SwiftData

@MainActor
final class CalibrationService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func current() -> Calibration? {
        var descriptor = FetchDescriptor<Calibration>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func save(_ calibration: Calibration) {
        context.insert(calibration)
        try? context.save()
    }

    /// Persist the walking aligned baseline onto the current calibration row
    /// (captured once in the first-walk setup, then reused for every walk).
    /// No-op if there's no calibration yet.
    func setWalkingBaseline(_ pitch: Double) {
        guard let calibration = current() else { return }
        calibration.airpodsWalkingPitch = pitch
        try? context.save()
    }

    func clear() {
        let all = (try? context.fetch(FetchDescriptor<Calibration>())) ?? []
        for c in all { context.delete(c) }
        try? context.save()
    }
}
