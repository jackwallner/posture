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

    // AirPods baseline (radians) - nil if AirPods weren't connected during calibration.
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

    // Walking aligned baseline (radians): the user's own good-posture head pitch
    // while actually walking, captured once in a deliberate setup the first time
    // they start a walk (walking's honest neutral - forward lean, head bob -
    // differs from a standing hold). Saved and reused for every later walk so a
    // walk is scored from its first second, instead of re-normalizing to the
    // first 30s of each walk (which risked baking a bad-posture walk in). nil
    // until that setup runs; scoring falls back to the per-walk auto-capture.
    var airpodsWalkingPitch: Double?

    // How steady the aligned captures were (0…1). A tight, still hold scores
    // near 1; a fidgety capture scores low. Surfaced to the user and used to
    // decide whether the baseline is trustworthy enough to judge against.
    var baselineConfidence: Double?

    // Watch wrist gravity baseline - nil if watch wasn't worn
    var watchGravityX: Double?
    var watchGravityY: Double?
    var watchGravityZ: Double?

    // Slouch reference: how far the user actually tilts when slouching (radians)
    var slouchPitchDelta: Double

    // Per-posture slouch references (2026-07): the drop from the standing
    // aligned pose into a standing slouch, and sitting into a sitting slouch.
    // Standing slouches are mostly shoulders (small pitch change); sitting
    // slouches collapse further - one shared delta blurred both. nil on
    // legacy rows; scoring falls back to `slouchPitchDelta`.
    var standingSlouchDelta: Double?
    var sittingSlouchDelta: Double?

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
        airpodsWalkingPitch: Double? = nil,
        baselineConfidence: Double? = nil,
        standingSlouchDelta: Double? = nil,
        sittingSlouchDelta: Double? = nil,
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
        self.airpodsWalkingPitch = airpodsWalkingPitch
        self.baselineConfidence = baselineConfidence
        self.standingSlouchDelta = standingSlouchDelta
        self.sittingSlouchDelta = sittingSlouchDelta
        self.watchGravityX = watchGravityX
        self.watchGravityY = watchGravityY
        self.watchGravityZ = watchGravityZ
    }
}
