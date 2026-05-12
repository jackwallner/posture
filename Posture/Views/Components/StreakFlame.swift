import SwiftUI

struct StreakFlame: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(streak > 0 ? Theme.streakFlame : Theme.textTertiary)
            Text("\(streak)")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(streak == 1 ? "day" : "days")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.cardSurface, in: .capsule)
    }
}
