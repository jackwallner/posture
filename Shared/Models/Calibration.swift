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

    // AirPods baseline (radians) — nil if AirPods weren't connected during calibration.
    // `airpodsPitch` is the effective baseline scoring reads: the mean of the
    // standing + sitting aligned captures (they're both "head level", so a
    // single robust number, cross-checked across two postures).
    var airpodsPitch: Double?
    var airpodsRoll: Double?
    var airpodsYaw: Double?

    // Per-posture aligned baselines, captured separately during onboarding so we
    // can teach + verify good posture standing AND sitting. nil on legacy rows
    // or a single-pose recalibration.
    var airpodsStandingPitch: Double?
    var airpodsSittingPitch: Double?

    // How steady the aligned captures were (0…1). A tight, still hold scores
    // near 1; a fidgety capture scores low. Surfaced to the user and used to
    // decide whether the baseline is trustworthy enough to judge against.
    var baselineConfidence: Double?

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
        airpodsStandingPitch: Double? = nil,
        airpodsSittingPitch: Double? = nil,
        baselineConfidence: Double? = nil,
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
        self.airpodsStandingPitch = airpodsStandingPitch
        self.airpodsSittingPitch = airpodsSittingPitch
        self.baselineConfidence = baselineConfidence
        self.watchGravityX = watchGravityX
        self.watchGravityY = watchGravityY
        self.watchGravityZ = watchGravityZ
    }
}
