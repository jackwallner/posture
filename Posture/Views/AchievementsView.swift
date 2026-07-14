import SwiftData
import SwiftUI

/// Display-only badge wall. Everything derives at read time from streak +
/// session rows - nothing here is persisted.
struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var streaks: [StreakState]
    @Query private var sessions: [PostureSession]
    @State private var subscriptions = SubscriptionService.shared

    private var achievements: [Achievement] {
        AchievementCatalog.all(
            streak: streaks.first,
            sessions: sessions,
            isPro: subscriptions.isProSubscriber
        )
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let earned = achievements.filter(\.isEarned).count
                    Text(earned == 0
                         ? "Your first badge is one practice away."
                         : "\(earned) of \(achievements.count) earned.")
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.ink)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(achievements) { badge in
                            badgeCell(badge)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .dawnBackground()
            .navigationTitle("Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(Theme.font(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private func badgeCell(_ badge: Achievement) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isEarned ? Theme.sageTint : Theme.paper3)
                    .frame(width: 62, height: 62)
                Image(systemName: badge.systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(badge.isEarned ? Theme.goodText : Theme.ink3.opacity(0.5))
            }
            Text(badge.title)
                .font(Theme.font(.caption, weight: .semibold))
                .foregroundStyle(badge.isEarned ? Theme.ink : Theme.ink3)
                .multilineTextAlignment(.center)
            Text(badge.isEarned ? earnedLabel(badge) : badge.subtitle)
                .font(Theme.font(.caption2))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .dawnCard(cornerRadius: 16)
        .opacity(badge.isEarned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title). \(badge.subtitle). \(badge.isEarned ? "Earned" : "Not earned yet")")
    }

    private func earnedLabel(_ badge: Achievement) -> String {
        guard let date = badge.earnedAt else { return badge.subtitle }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
