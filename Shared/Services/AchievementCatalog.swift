import Foundation

/// One display-only badge. Nothing is persisted - every badge derives at
/// read time from `StreakState` and the `PostureSession` rows, so the
/// catalog can never drift from the data.
struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isEarned: Bool
    let earnedAt: Date?
}

/// Pure derivation of the badge set. No I/O, no state, easy to test.
enum AchievementCatalog {
    nonisolated static func all(
        streak: StreakState?,
        sessions: [PostureSession],
        at date: Date = .now,
        isPro: Bool = true
    ) -> [Achievement] {
        let practices = sessions.filter { $0.kind == .practice }
        let completedPractices = practices.filter(\.completed).sorted { $0.startedAt < $1.startedAt }
        let passedPractices = practices.filter(\.passed).sorted { $0.startedAt < $1.startedAt }
        let walks = sessions.filter { $0.kind == .walk && $0.completed }.sorted { $0.startedAt < $1.startedAt }

        // Levels are per-posture ladders now (standing/sitting). Pre-split rows
        // (nil mode) are grandfathered into both, matching the ladder counts.
        // A level badge reflects the *highest* ladder reached, and is earned the
        // moment *either* ladder crosses it - so a "both" user doesn't have to
        // double the work, and a legacy/single-focus user is unaffected.
        let standingPassed = passedPractices.filter { $0.postureMode == .standing || $0.postureMode == nil }
        let sittingPassed = passedPractices.filter { $0.postureMode == .sitting || $0.postureMode == nil }
        // Capped for free users, matching the ladder they actually play: a level
        // badge can't be earned for a level the app never let them reach. It
        // lands retroactively the moment they upgrade.
        let level = PracticeProgression.effectiveLevel(
            level: max(
                PracticeProgression.level(passedSessions: standingPassed.count),
                PracticeProgression.level(passedSessions: sittingPassed.count)
            ),
            isPro: isPro
        )
        let bestStreak = max(streak?.longestStreak ?? 0, StreakService.displayStreak(for: streak, at: date))
        let streakDate = streak?.lastActiveDay

        /// The earliest date at which *either* ladder reached `target`.
        func levelEarnedAt(_ target: Int) -> Date? {
            let needed = PracticeProgression.threshold(forLevel: target)
            guard needed > 0 else { return nil }
            func date(_ rows: [PostureSession]) -> Date? {
                rows.count >= needed ? rows[needed - 1].startedAt : nil
            }
            return [date(standingPassed), date(sittingPassed)].compactMap { $0 }.min()
        }

        func streakBadge(_ days: Int, icon: String, subtitle: String) -> Achievement {
            Achievement(
                id: "streak_\(days)",
                title: "\(days)-day streak",
                subtitle: subtitle,
                systemImage: icon,
                isEarned: bestStreak >= days,
                earnedAt: bestStreak >= days ? streakDate : nil
            )
        }

        return [
            Achievement(
                id: "first_practice",
                title: "First practice",
                subtitle: "Finished your first daily practice.",
                systemImage: "figure.stand",
                isEarned: !completedPractices.isEmpty,
                earnedAt: completedPractices.first?.startedAt
            ),
            Achievement(
                id: "first_pass",
                title: "First pass",
                subtitle: "Met a session's aligned target.",
                systemImage: "checkmark.seal",
                isEarned: !passedPractices.isEmpty,
                earnedAt: passedPractices.first?.startedAt
            ),
            Achievement(
                id: "level_5",
                title: "Level 5",
                subtitle: "Seven minutes held tall.",
                systemImage: "chevron.up.2",
                isEarned: level >= 5,
                earnedAt: level >= 5 ? levelEarnedAt(5) : nil
            ),
            Achievement(
                id: "level_10",
                title: "Level 10",
                subtitle: "Twelve minutes, high bar.",
                systemImage: "chevron.up.2",
                isEarned: level >= 10,
                earnedAt: level >= 10 ? levelEarnedAt(10) : nil
            ),
            streakBadge(7, icon: "flame", subtitle: "A full week of practice."),
            streakBadge(14, icon: "flame", subtitle: "Two weeks straight."),
            streakBadge(30, icon: "flame.fill", subtitle: "A whole month of practice."),
            streakBadge(60, icon: "flame.fill", subtitle: "Two months, still standing tall."),
            streakBadge(100, icon: "flame.circle", subtitle: "One hundred days."),
            Achievement(
                id: "first_walk",
                title: "First walk",
                subtitle: "Took your posture outside.",
                systemImage: "figure.walk",
                isEarned: !walks.isEmpty,
                earnedAt: walks.first?.startedAt
            ),
            Achievement(
                id: "walk_10",
                title: "Ten walks",
                subtitle: "Ten walks, head high.",
                systemImage: "figure.walk.motion",
                isEarned: walks.count >= 10,
                earnedAt: walks.count >= 10 ? walks[9].startedAt : nil
            ),
            Achievement(
                id: "freeze_saved",
                title: "Safety net",
                subtitle: "Earned a streak save.",
                systemImage: "snowflake",
                isEarned: (streak?.freezesAvailable ?? 0) > 0 || bestStreak >= 7,
                earnedAt: (streak?.freezesAvailable ?? 0) > 0 || bestStreak >= 7 ? streakDate : nil
            ),
        ]
    }

    /// Earned badge ids only - the compact set for "did this session unlock
    /// anything new?" comparisons.
    nonisolated static func earnedIDs(
        streak: StreakState?,
        sessions: [PostureSession],
        at date: Date = .now,
        isPro: Bool = true
    ) -> Set<String> {
        Set(
            all(streak: streak, sessions: sessions, at: date, isPro: isPro)
                .filter(\.isEarned).map(\.id)
        )
    }

    /// The next unearned badge worth chasing, for the Today teaser row.
    nonisolated static func nextUp(
        streak: StreakState?,
        sessions: [PostureSession],
        at date: Date = .now,
        isPro: Bool = true
    ) -> Achievement? {
        all(streak: streak, sessions: sessions, at: date, isPro: isPro).first { !$0.isEarned }
    }
}
