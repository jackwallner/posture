import Foundation
import SwiftData

@MainActor
final class StreakService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func currentState() -> StreakState {
        let descriptor = FetchDescriptor<StreakState>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let fresh = StreakState()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    /// Call after the user completes a qualifying session. Returns the updated state.
    @discardableResult
    func recordSessionCompleted(at date: Date = .now) -> StreakState {
        let state = currentState()
        StreakService.applySession(to: state, at: date)
        try? context.save()
        return state
    }

    /// Pure side-effect-free helper for testing.
    nonisolated static func applySession(to state: StreakState, at date: Date) {
        let today = DateHelpers.startOfDay(date)
        guard let last = state.lastActiveDay else {
            state.currentStreak = 1
            state.longestStreak = max(1, state.longestStreak)
            state.lastActiveDay = today
            state.dailyGoalSeconds = StreakService.dailyGoalSeconds(forStreak: state.currentStreak)
            return
        }
        let lastDay = DateHelpers.startOfDay(last)
        let gap = DateHelpers.daysBetween(lastDay, today)

        switch gap {
        case 0:
            // Same day — streak unchanged
            return
        case 1:
            state.currentStreak += 1
        case 2 where state.freezesAvailable > 0:
            // One missed day, but a freeze covers it
            state.freezesAvailable -= 1
            state.currentStreak += 1
        default:
            state.currentStreak = 1
        }
        state.longestStreak = max(state.longestStreak, state.currentStreak)
        state.lastActiveDay = today
        state.dailyGoalSeconds = StreakService.dailyGoalSeconds(forStreak: state.currentStreak)
    }

    /// Daily goal pacing: 60s on day 1, +30s every 3 streak days, capped at 5 min.
    nonisolated static func dailyGoalSeconds(forStreak streak: Int) -> Int {
        let base = 60
        let bonus = (streak / 3) * 30
        return min(base + bonus, 300)
    }
}
