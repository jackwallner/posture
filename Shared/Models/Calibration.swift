import Foundation
import SwiftData

@Model
final class Calibration {
    var id: UUID
    var capturedAt: Date

    // Front-camera face-pose baseline (radians)
    var basePitch: Double
    var baseYaw: Double
    var baseRoll: Double

    // AirPods baseline (radians) — nil if AirPods weren't connected during calibration
    var airpodsPitch: Double?
    var airpodsRoll: Double?
    var airpodsYaw: Double?

    // Watch wrist gravity baseline — nil if watch wasn't worn
    var watchGravityX: Double?
    var watchGravityY: Double?
    var watchGravityZ: Double?

    // Slouch reference: how far the user actually tilts when slouching (radians)
    var slouchPitchDelta: Double

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        basePitch: Double,
        baseYaw: Double,
        baseRoll: Double,
        slouchPitchDelta: Double,
        airpodsPitch: Double? = nil,
        airpodsRoll: Double? = nil,
        airpodsYaw: Double? = nil,
        watchGravityX: Double? = nil,
        watchGravityY: Double? = nil,
        watchGravityZ: Double? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.basePitch = basePitch
        self.baseYaw = baseYaw
        self.baseRoll = baseRoll
        self.slouchPitchDelta = slouchPitchDelta
        self.airpodsPitch = airpodsPitch
        self.airpodsRoll = airpodsRoll
        self.airpodsYaw = airpodsYaw
        self.watchGravityX = watchGravityX
        self.watchGravityY = watchGravityY
        self.watchGravityZ = watchGravityZ
    }
}
