import SwiftData
import SwiftUI

struct WatchTodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PostureSession.startedAt, order: .reverse) private var sessions: [PostureSession]
    @Query private var streaks: [StreakState]

    @State private var showingSession = false

    private var todaySession: PostureSession? {
        sessions.first { Calendar.current.isDateInToday($0.startedAt) }
    }

    private var streak: StreakState {
        if let s = streaks.first { return s }
        let fresh = StreakState()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    private var dailyGoal: Int {
        StreakService.dailyGoalSeconds(forStreak: streak.currentStreak)
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

                    PostureRingCompact(score: todaySession?.score ?? 0)

                    if let s = todaySession {
                        Text("Today: \(s.score)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.good)
                    } else {
                        Text("\(dailyGoal)s session")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Button {
                        showingSession = true
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandPrimary)

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
            .fullScreenCover(isPresented: $showingSession) {
                WatchSessionView(targetSeconds: dailyGoal)
            }
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
