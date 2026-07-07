import SwiftData
import SwiftUI

/// What the streak is, what saves are, and the recent history of active
/// days - opened by tapping the streak chip on Today.
struct StreakDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var streaks: [StreakState]
    @Query private var sessions: [PostureSession]
    @Query private var acknowledgments: [AcknowledgmentRecord]

    private let cal = Calendar.current

    private var streak: StreakState? { streaks.first }
    private var currentStreak: Int { StreakService.displayStreak(for: streak) }
    private var savesAvailable: Int { streak?.freezesAvailable ?? 0 }

    /// Day-starts (last 35 days) that earned streak credit: a completed
    /// session or a check-in.
    private var activeDays: Set<Date> {
        let cutoff = DateHelpers.daysAgo(35)
        var days = Set<Date>()
        for s in sessions where s.completed && s.startedAt >= cutoff {
            days.insert(cal.startOfDay(for: s.startedAt))
        }
        for a in acknowledgments where a.timestamp >= cutoff {
            days.insert(cal.startOfDay(for: a.timestamp))
        }
        return days
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statRow
                    calendarCard
                    savesCard
                    milestonesCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .dawnBackground()
            .navigationTitle("Streak")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.streakFlame)
                Text(currentStreak == 1 ? "1 day" : "\(currentStreak) days")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.ink)
            }
            Text(currentStreak == 0
                 ? "Finish today's practice and day one begins."
                 : "One finished practice (or walk, or check-in) a day keeps it alive.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
        }
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(streak?.longestStreak ?? 0)", label: "longest streak")
            statCard(value: "\(savesAvailable)", label: savesAvailable == 1 ? "save ready" : "saves ready")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.font(size: 28, weight: .regular))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .dawnCard(cornerRadius: 14)
    }

    /// Five rows of seven dots - the last 35 days, oldest first.
    private var calendarCard: some View {
        let today = DateHelpers.startOfDay()
        let days: [Date] = (0..<35).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
        let active = activeDays
        return VStack(alignment: .leading, spacing: 10) {
            Text("Last five weeks")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink3)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    Circle()
                        .fill(active.contains(day) ? Theme.sage : Theme.paper3)
                        .frame(height: 16)
                        .overlay {
                            if cal.isDateInToday(day) {
                                Circle().stroke(Theme.ink2, lineWidth: 1.5)
                            }
                        }
                }
            }
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Circle().fill(Theme.sage).frame(width: 8, height: 8)
                    Text("active day")
                }
                HStack(spacing: 5) {
                    Circle().fill(Theme.paper3).frame(width: 8, height: 8)
                    Text("missed")
                }
            }
            .font(Theme.font(.caption2))
            .foregroundStyle(Theme.ink3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar of the last 35 days. \(activeDays.count) active days.")
    }

    private var savesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "snowflake")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.lavender)
                Text("What a save is")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text("Miss a single day and a save spends itself automatically, your streak carries on as if you'd practiced. You hold up to two, they refill weekly, and streak milestones (7, 14, 30, 60, 100 days) award a bonus one. Miss two days in a row and the streak resets; saves can't cover that.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }

    private var milestonesCard: some View {
        let milestones = StreakService.streakMilestoneDays.sorted()
        let best = max(streak?.longestStreak ?? 0, currentStreak)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Milestones")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink3)
            ForEach(milestones, id: \.self) { day in
                HStack(spacing: 10) {
                    Image(systemName: best >= day ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(best >= day ? Theme.goodText : Theme.ink3.opacity(0.4))
                    Text("\(day)-day streak")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(best >= day ? Theme.ink : Theme.ink2)
                    Spacer()
                    Text("+1 save")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }
}
