import SwiftData
import SwiftUI

struct WatchTodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var streaks: [StreakState]

    @State private var showingSession = false

    private var streak: StreakState {
        if let s = streaks.first { return s }
        let fresh = StreakState()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(streak.currentStreak > 0 ? Theme.streakFlame : Theme.textTertiary)
                        Text("\(streak.currentStreak) day\(streak.currentStreak == 1 ? "" : "s")")
                            .font(.headline)
                    }

                    // Posture ring showing today's best check-in quality
                    // (watch reads from shared App Group SwiftData)
                    PostureRingCompact(score: bestTodayScore)

                    Text(bestTodayScore > 0 ? "Today: \(bestTodayScore)" : "Check in on your iPhone")
                        .font(.subheadline)
                        .foregroundStyle(bestTodayScore > 0 ? Theme.good : Theme.textSecondary)

                    NavigationLink {
                        WatchSettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Posture")
        }
    }

    /// Best quality score from today's camera acknowledgments or sessions.
    private var bestTodayScore: Int {
        let today = Calendar.current.startOfDay(for: .now)

        // Check AcknowledgmentRecords (camera-based) for today
        let ackPredicate = #Predicate<AcknowledgmentRecord> { record in
            record.methodRaw == "camera" && record.qualityRaw != nil
        }
        let todayAcks = (try? context.fetch(FetchDescriptor<AcknowledgmentRecord>(predicate: ackPredicate))) ?? []
        let todayAcksFiltered = todayAcks.filter { $0.timestamp >= today }

        if let bestAck = todayAcksFiltered.compactMap({ $0.quality }).map({ qualityToScore($0) }).max() {
            return bestAck
        }

        // Fallback to PostureSession
        let sessionPredicate = #Predicate<PostureSession> { session in
            session.startedAt >= today
        }
        let todaySessions = (try? context.fetch(FetchDescriptor<PostureSession>(predicate: sessionPredicate))) ?? []
        return todaySessions.map(\.score).max() ?? 0
    }

    private func qualityToScore(_ quality: PostureQuality) -> Int {
        switch quality {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }
}

private struct PostureRingCompact: View {
    let score: Int
    private var progress: Double { Double(score) / 100.0 }
    private var color: Color {
        switch score {
        case 80...: return Theme.good
        case 50..<80: return Theme.borderline
        default: return Theme.bad
        }
    }
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: .init(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: 80, height: 80)
    }
}
