#if DEBUG
import Foundation
import SwiftData

/// Launch with `-SCREENSHOT_SEED` (plus `-PostureProOverride` for the crisp
/// Pro surfaces) to drop straight into a fully-staged app for App Store
/// screenshot capture: onboarding + calibration marked done, an AirPods
/// baseline, a multi-day streak, a week of passed practice sessions, a walk,
/// per-minute history, and a few hand check-ins. DEBUG-only; never ships.
@MainActor
enum ScreenshotSeed {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("SCREENSHOT_SEED")
    }

    static func seedIfNeeded() {
        guard isActive else { return }
        markSetupComplete()
        seedData()
    }

    private static func markSetupComplete() {
        let s = GoalSettings.shared
        s.hasCompletedOnboarding = true
        s.hasCalibrated = true
        s.calibrationDeferred = false
        s.hasSeenOnboardingTrial = true
        s.hasSeenIntroPaywall = true
        s.hasSeenTrainingTour = true
        s.hasSeenSessionCoachMarks = true
        s.hasSeenPivotExplainer = true
        s.didApplyPracticePivotGrace = true
        s.hasAirpods = true
        s.postureFocus = .both
        s.inAppLiveEnabled = false // no live readout jitter in the raws
    }

    private static func seedData() {
        let context = DataService.sharedModelContainer.mainContext
        wipe(context)

        let cal = Calendar.current
        let now = Date.now
        let today = cal.startOfDay(for: now)

        // Calibration baseline (radians) - plausible AirPods head-level values.
        context.insert(Calibration(
            basePitch: 0.02, baseYaw: 0, baseRoll: 0,
            slouchPitchDelta: 0.32,
            airpodsPitch: 0.03, airpodsRoll: 0, airpodsYaw: 0,
            airpodsStandingPitch: 0.01, airpodsSittingPitch: 0.05,
            airpodsWalkingPitch: 0.09,
            baselineConfidence: 0.94,
            standingSlouchDelta: 0.18, sittingSlouchDelta: 0.34
        ))

        // Streak: a healthy run with freezes in the bank.
        context.insert(StreakState(
            currentStreak: 6, longestStreak: 14, freezesAvailable: 2,
            lastActiveDay: today, dailyGoalSeconds: 60
        ))

        // A week of passed practice sessions (one per day), aligned-% climbing.
        let aligned = [84, 88, 81, 90, 86, 92, 89]
        for dayOffset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let startedAt = cal.date(bySettingHour: 8, minute: 25, second: 0, of: day) ?? day
            let pct = aligned[dayOffset]
            let duration = 300 // 5-minute hold
            let good = Int(Double(duration) * Double(pct) / 100.0)
            let borderline = (duration - good) * 2 / 3
            let bad = duration - good - borderline
            context.insert(PostureSession(
                startedAt: startedAt,
                durationSeconds: duration,
                score: pct,
                goodSeconds: good, borderlineSeconds: borderline, badSeconds: bad,
                source: .airpods, kind: .practice,
                targetSeconds: duration, targetPercent: 70,
                alignedPercent: pct, completed: true, passed: pct >= 70
            ))
        }

        // A recent posture walk (Pro), reads "tall" and covers real ground.
        if let walkDay = cal.date(byAdding: .day, value: -1, to: today) {
            let walkStart = cal.date(bySettingHour: 18, minute: 10, second: 0, of: walkDay) ?? walkDay
            let duration = 600
            let good = Int(Double(duration) * 0.87)
            let borderline = (duration - good) * 2 / 3
            context.insert(PostureSession(
                startedAt: walkStart,
                durationSeconds: duration,
                score: 87,
                goodSeconds: good, borderlineSeconds: borderline, badSeconds: duration - good - borderline,
                source: .airpods, kind: .walk,
                targetSeconds: duration, targetPercent: 0,
                alignedPercent: 87, completed: true, passed: false,
                distanceMeters: 1620, steps: 2140,
                goalIsDistance: false, targetDistanceMeters: 0
            ))
        }

        // Per-minute history so Today's ring, the hour rhythm, and History's
        // day chart all look lived-in.
        seedMinutes(context, cal: cal, today: today)

        // A couple of hand check-ins for the journal.
        for (dayOffset, hour) in [(0, 11), (0, 15), (1, 14)] {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: today),
                  let at = cal.date(bySettingHour: hour, minute: 5, second: 0, of: day) else { continue }
            context.insert(AcknowledgmentRecord(
                timestamp: at, method: .manual, quality: .good, deviation: nil, scheduledAt: at
            ))
        }

        try? context.save()
    }

    /// Spread believable good/borderline minutes across working hours for the
    /// last few days (today densest so the ring reads high).
    private static func seedMinutes(_ context: ModelContext, cal: Calendar, today: Date) {
        // (dayOffset, startHour, minutes, goodBias)
        let blocks: [(Int, Int, Int, Double)] = [
            (0, 9, 35, 0.86), (0, 11, 28, 0.82), (0, 14, 40, 0.9), (0, 16, 22, 0.8),
            (1, 10, 30, 0.84), (1, 13, 26, 0.79), (1, 15, 34, 0.88),
            (2, 9, 24, 0.81), (2, 14, 30, 0.85),
            (3, 10, 28, 0.83), (3, 15, 20, 0.78),
            (4, 11, 26, 0.87), (5, 13, 22, 0.82), (6, 10, 24, 0.85),
        ]
        for (dayOffset, startHour, minutes, goodBias) in blocks {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: today),
                  let blockStart = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: day)
            else { continue }
            for m in 0..<minutes {
                guard let minuteStart = cal.date(byAdding: .minute, value: m, to: blockStart) else { continue }
                // Deterministic wobble so the timeline isn't flat.
                let wobble = Double((m * 7) % 11) / 40.0 - 0.12
                let good = max(0, min(1, goodBias + wobble))
                let goodSec = 60.0 * good
                let borderlineSec = 60.0 * (1 - good) * 0.7
                let badSec = 60.0 - goodSec - borderlineSec
                context.insert(PostureMinuteSample(
                    minuteStart: minuteStart,
                    goodSeconds: goodSec, borderlineSeconds: borderlineSec, badSeconds: max(0, badSec),
                    source: .airpods
                ))
            }
        }
    }

    private static func wipe(_ context: ModelContext) {
        try? context.delete(model: PostureSession.self)
        try? context.delete(model: PostureMinuteSample.self)
        try? context.delete(model: AcknowledgmentRecord.self)
        try? context.delete(model: StreakState.self)
        try? context.delete(model: Calibration.self)
    }
}
#endif
