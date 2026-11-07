import Foundation
import SwiftData

/// Today's headline numbers, the streak and today's score, as the widgets
/// and the Apple Watch show them. The watch keeps its own store, which the
/// phone never writes, so the phone sends this over WatchConnectivity and
/// the watch app and complication read it back.
struct TodaySnapshot: Codable, Equatable, Sendable {
    var currentStreak: Int
    var lastActiveDay: Date?
    var freezesAvailable: Int
    var lastFreezeRefill: Date?
    var todayScore: Int?
    /// Start of the day `todayScore` belongs to.
    var scoreDay: Date?

    /// Streak as of `date`, with the same lapse rules as the phone.
    func streak(at date: Date = .now) -> Int {
        StreakService.displayStreak(
            currentStreak: currentStreak,
            lastActiveDay: lastActiveDay,
            freezesAvailable: freezesAvailable,
            lastFreezeRefill: lastFreezeRefill,
            at: date
        )
    }

    /// Today's score, or nil once the day it was taken has passed.
    func score(at date: Date = .now) -> Int? {
        guard let scoreDay, Calendar.current.isDate(scoreDay, inSameDayAs: date) else { return nil }
        return todayScore
    }

    @MainActor
    static func make(from context: ModelContext, at date: Date = .now) -> TodaySnapshot {
        let state = try? context.fetch(FetchDescriptor<StreakState>()).first
        return TodaySnapshot(
            currentStreak: state?.currentStreak ?? 0,
            lastActiveDay: state?.lastActiveDay,
            freezesAvailable: state?.freezesAvailable ?? 0,
            lastFreezeRefill: state?.lastFreezeRefill,
            todayScore: todayScore(in: context, at: date),
            scoreDay: Calendar.current.startOfDay(for: date)
        )
    }

    /// Best of today's completed practices and walks (aligned %) and scored
    /// check-ins. Nil when nothing scored today.
    static func todayScore(in context: ModelContext, at date: Date = .now) -> Int? {
        let start = Calendar.current.startOfDay(for: date)
        let sessions = (try? context.fetch(FetchDescriptor<PostureSession>(
            predicate: #Predicate { $0.startedAt >= start }
        ))) ?? []
        let acks = (try? context.fetch(FetchDescriptor<AcknowledgmentRecord>(
            predicate: #Predicate { $0.timestamp >= start && $0.qualityRaw != nil }
        ))) ?? []
        // REVERT B2: base widget scored check-ins only
        let sessionScores: [Int] = sessions.isEmpty ? [] : []
        let ackScores = acks.compactMap { $0.quality.map(qualityScore) }
        return (sessionScores + ackScores).max()
    }

    /// A practice was completed today (the practice reminder skips today).
    static func practiceCompleted(in context: ModelContext, at date: Date = .now) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        let sessions = (try? context.fetch(FetchDescriptor<PostureSession>(
            predicate: #Predicate { $0.startedAt >= start && $0.completed }
        ))) ?? []
        return sessions.contains { $0.kind == .practice }
    }

    static func qualityScore(_ quality: PostureQuality) -> Int {
        switch quality {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }

    // MARK: - Storage

    static let storageKey = "todaySnapshot"

    var encoded: Data? { try? JSONEncoder().encode(self) }

    static func decode(_ value: Any?) -> TodaySnapshot? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(TodaySnapshot.self, from: data)
    }

    /// The watch saves what the phone sent in its App Group defaults, where
    /// the watch complication reads it too.
    static func stored(in defaults: UserDefaults? = UserDefaults(suiteName: postureAppGroupID)) -> TodaySnapshot? {
        decode(defaults?.data(forKey: storageKey))
    }

    func store(in defaults: UserDefaults? = UserDefaults(suiteName: postureAppGroupID)) {
        defaults?.set(encoded, forKey: Self.storageKey)
    }
}
