import SwiftUI

/// Educational section showing posture habits, ergonomics tips, and stretches.
struct PostureHabitsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    categorySection(title: "Desk Ergonomics", icon: "desktopcomputer", category: .ergonomics)
                    categorySection(title: "Daily Habits", icon: "arrow.triangle.2.circlepath", category: .habit)
                    categorySection(title: "Stretches", icon: "figure.cooldown", category: .stretch)
                    categorySection(title: "Awareness", icon: "brain", category: .awareness)
                }
                .padding(.vertical)
            }
            .dawnBackground()
            .navigationTitle("Posture Habits")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Build better habits")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Small adjustments throughout the day add up to lasting change.")
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private func categorySection(title: String, icon: String, category: TipCategory) -> some View {
        let tips = PostureTipService.tips(category: category)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(Theme.font(.headline))
                    .foregroundStyle(Theme.brandPrimary)
                Text(title)
                    .font(Theme.font(.headline))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 4)

            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                PostureTipCard(tip: tip)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    PostureHabitsView()
}
