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
        StreakService.refillFreezesIfNeeded(state, at: date)
        StreakService.applySession(to: state, at: date)
        StreakService.awardMilestoneFreezes(state, at: date)
        try? context.save()
        return state
    }

    /// Call after the user acknowledges a posture reminder (camera scan or manual).
    /// Counts as a streak day if this is the first acknowledgment today.
    @discardableResult
    func recordAcknowledgment(at date: Date = .now) -> StreakState {
        let state = currentState()
        StreakService.refillFreezesIfNeeded(state, at: date)
        StreakService.applySession(to: state, at: date)
        StreakService.awardMilestoneFreezes(state, at: date)
        try? context.save()
        return state
    }

    /// Compute the user's acknowledgment response rate for a given date.
    /// This is a best-effort estimate — we can't always count total reminders
    /// that were sent vs acknowledged, so we use the app's scheduled count.
    nonisolated static func responseRate(
        for date: Date,
        acknowledgments: [AcknowledgmentRecord],
        scheduledCount: Int
    ) -> Double {
        let dayStart = DateHelpers.startOfDay(date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let todaysAcks = acknowledgments.filter {
            $0.timestamp >= dayStart && $0.timestamp < dayEnd
        }
        guard scheduledCount > 0 else { return 1.0 }
        let ackCount = todaysAcks.count
        return min(Double(ackCount) / Double(scheduledCount), 1.0)
    }

    /// Weekly freeze refill — resets to 2 available freezes every 7 days.
    nonisolated static func refillFreezesIfNeeded(_ state: StreakState, at date: Date) {
        let maxFreezes = 2
        guard state.freezesAvailable < maxFreezes else { return }
        guard let lastRefill = state.lastFreezeRefill else {
            state.lastFreezeRefill = date
            state.freezesAvailable = maxFreezes
            return
        }
        let daysSince = DateHelpers.daysBetween(DateHelpers.startOfDay(lastRefill), DateHelpers.startOfDay(date))
        guard daysSince >= 7 else { return }
        state.lastFreezeRefill = date
        state.freezesAvailable = maxFreezes
    }

    /// Bonus freeze at streak milestones: 7, 14, 30, 60, 100 days.
    private nonisolated static let milestoneDays: Set<Int> = [7, 14, 30, 60, 100]
    nonisolated static func awardMilestoneFreezes(_ state: StreakState, at date: Date) {
        guard milestoneDays.contains(state.currentStreak) else { return }
        state.freezesAvailable += 1
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
