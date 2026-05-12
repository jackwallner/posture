import SwiftData
import SwiftUI

struct TodayView: View {
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
                VStack(spacing: 24) {
                    StreakFlame(streak: streak.currentStreak)
                        .padding(.top, 8)

                    PostureRing(score: todaySession?.score ?? 0, size: 220)
                        .padding(.vertical, 8)

                    if let s = todaySession {
                        completedCard(session: s)
                    } else {
                        startCard
                    }

                    statsRow

                    Spacer()
                }
                .padding(.horizontal)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingSession) {
                SessionView(targetSeconds: dailyGoal)
            }
        }
    }

    private var startCard: some View {
        VStack(spacing: 12) {
            Text("\(dailyGoal) second session")
                .font(.headline)
            Text("Day \(streak.currentStreak + 1) of your streak")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button {
                showingSession = true
            } label: {
                Text("Start session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private func completedCard(session: PostureSession) -> some View {
        VStack(spacing: 8) {
            Text("Today's session — done")
                .font(.headline)
                .foregroundStyle(Theme.good)
            Text("\(session.durationSeconds)s · score \(session.score)")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button {
                showingSession = true
            } label: {
                Text("Do another")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.cardSurfaceLight, in: .rect(cornerRadius: 12))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(label: "Longest", value: "\(streak.longestStreak)")
            statTile(label: "Freezes", value: "\(streak.freezesAvailable)")
            statTile(label: "Sessions", value: "\(sessions.count)")
        }
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.cardSurface, in: .rect(cornerRadius: 14))
    }
}
