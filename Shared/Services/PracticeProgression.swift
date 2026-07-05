import Foundation

/// The daily-practice level ramp. Pure functions only — level is derived
/// from the count of *passed* practice sessions, never stored, so it can't
/// drift from the session rows and needs no migration.
///
/// Semantics: completing a session's duration credits the streak; meeting
/// the session's aligned-% target marks it `passed`, and passed sessions
/// are what advance the level. Kind on the bad days, ambitious on the ramp.
enum PracticeProgression {
    /// Passed sessions needed to *reach* each level. Index 0 → level 1.
    /// Beyond the table, each level costs `lateLevelStride` more.
    private nonisolated static let levelThresholds = [0, 2, 5, 9, 14, 20, 27, 35, 44, 54]
    private nonisolated static let lateLevelStride = 12

    /// Session length starts at 3 minutes and grows a minute per level,
    /// topping out at 15 — long enough to matter, short enough to finish.
    nonisolated static let baseSessionSeconds = 180
    nonisolated static let sessionSecondsPerLevel = 60
    nonisolated static let maxSessionSeconds = 900

    /// Aligned-% target starts winnable and ramps gently. 80% is the
    /// ceiling — posture is a practice, not a perfection contest.
    nonisolated static let baseTargetPercent = 50
    nonisolated static let targetPercentPerLevel = 3
    nonisolated static let maxTargetPercent = 80

    /// Free tier stops ramping here; higher levels are Posture+.
    nonisolated static let freeLevelCap = 5

    nonisolated static func level(passedSessions: Int) -> Int {
        guard passedSessions >= 0 else { return 1 }
        if passedSessions >= levelThresholds.last! {
            let beyond = passedSessions - levelThresholds.last!
            return levelThresholds.count + beyond / lateLevelStride
        }
        // Highest level whose threshold is met.
        var level = 1
        for (index, needed) in levelThresholds.enumerated() where passedSessions >= needed {
            level = index + 1
        }
        return level
    }

    /// Passed sessions needed to reach `level` (inverse of `level(passedSessions:)`).
    nonisolated static func threshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        if level <= levelThresholds.count {
            return levelThresholds[level - 1]
        }
        return levelThresholds.last! + (level - levelThresholds.count) * lateLevelStride
    }

    nonisolated static func sessionSeconds(forLevel level: Int) -> Int {
        let clamped = max(level, 1)
        return min(baseSessionSeconds + (clamped - 1) * sessionSecondsPerLevel, maxSessionSeconds)
    }

    nonisolated static func targetPercent(forLevel level: Int) -> Int {
        let clamped = max(level, 1)
        return min(baseTargetPercent + (clamped - 1) * targetPercentPerLevel, maxTargetPercent)
    }

    nonisolated static func effectiveLevel(level: Int, isPro: Bool) -> Int {
        isPro ? level : min(level, freeLevelCap)
    }

    /// Progress within the current level, for the ladder UI:
    /// `done` of `needed` passed sessions toward the next level.
    nonisolated static func progressInLevel(passedSessions: Int) -> (done: Int, needed: Int) {
        let current = level(passedSessions: passedSessions)
        let floor = threshold(forLevel: current)
        let ceiling = threshold(forLevel: current + 1)
        return (passedSessions - floor, ceiling - floor)
    }
}
