import Foundation
import SwiftData

@Model
final class StreakState {
    var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var freezesAvailable: Int
    var lastActiveDay: Date?
    var lastFreezeRefill: Date?
    var dailyGoalSeconds: Int

    init(
        id: UUID = UUID(),
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        freezesAvailable: Int = 2,
        lastActiveDay: Date? = nil,
        lastFreezeRefill: Date? = nil,
        dailyGoalSeconds: Int = 60
    ) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.freezesAvailable = freezesAvailable
        self.lastActiveDay = lastActiveDay
        self.lastFreezeRefill = lastFreezeRefill
        self.dailyGoalSeconds = dailyGoalSeconds
    }
}
