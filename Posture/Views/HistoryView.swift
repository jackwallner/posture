import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \PostureSession.startedAt, order: .reverse) private var sessions: [PostureSession]
    @State private var subscriptions = SubscriptionService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if subscriptions.isProSubscriber {
                        PassiveTimelineView()
                            .padding(.horizontal)
                    }

                    if sessions.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(sessions) { session in
                                row(for: session)
                                if session.id != sessions.last?.id {
                                    Divider().padding(.leading, 80)
                                }
                            }
                        }
                        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No sessions yet")
                .font(.headline)
            Text("Complete a posture session to start your history.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func row(for session: PostureSession) -> some View {
        HStack(spacing: 14) {
            PostureRing(score: session.score, size: 52, lineWidth: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(DateHelpers.mediumDate(session.startedAt))
                    .font(.headline)
                Text("\(session.durationSeconds)s · \(session.source.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
