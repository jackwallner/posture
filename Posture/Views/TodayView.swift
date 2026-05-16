import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Query(sort: \PostureSession.startedAt, order: .reverse) private var sessions: [PostureSession]
    @Query private var streaks: [StreakState]
    @Query(sort: \AcknowledgmentRecord.timestamp, order: .reverse) private var acknowledgments: [AcknowledgmentRecord]

    @State private var showingAck = false
    @State private var showingHabits = false
    @State private var nextReminderText = "—"
    @State private var remainingReminders = 0
    @State private var currentTip = PostureTipService.randomTip()

    private var streak: StreakState {
        if let s = streaks.first { return s }
        let fresh = StreakState()
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    /// Acknowledgments from today.
    private var todayAcks: [AcknowledgmentRecord] {
        let today = DateHelpers.startOfDay()
        return acknowledgments.filter { $0.timestamp >= today }
    }

    /// Number of camera-based acknowledgments today.
    private var cameraAckCount: Int {
        todayAcks.filter { $0.method == .camera }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    StreakFlame(streak: streak.currentStreak)
                        .padding(.top, 8)

                    // Reminder status
                    if settings.reminderEnabled {
                        reminderStatusCard
                    } else {
                        remindersOffCard
                    }

                    // Response progress (only meaningful if reminders are on)
                    if settings.reminderEnabled {
                        responseProgressCard
                    }

                    // Today's check-ins summary
                    if !todayAcks.isEmpty {
                        todaySummaryCard
                    }

                    // Immediate check-in buttons
                    checkInCard

                    // Tip of the day
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(Theme.borderline)
                                .font(.caption)
                            Text("Tip")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 4)

                        PostureTipCard(tip: currentTip)
                            .onTapGesture {
                                withAnimation { currentTip = PostureTipService.randomTip() }
                            }
                    }

                    // Learn more
                    Button {
                        showingHabits = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                            Text("All posture tips")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Theme.brandPrimary)
                    }

                    statsRow

                    Spacer()
                }
                .padding(.horizontal)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingAck) {
                AcknowledgmentView(scheduledAt: .now, notificationIndex: nil)
            }
            .sheet(isPresented: $showingHabits) {
                PostureHabitsView()
            }
            .task {
                await refreshReminderStatus()
            }
            .onChange(of: settings.reminderEnabled) { _, _ in
                Task { await refreshReminderStatus() }
            }
            .onChange(of: settings.reminderIntervalMinutes) { _, _ in
                Task { await refreshReminderStatus() }
            }
        }
    }

    // MARK: - Reminder Status

    private var reminderStatusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.title2)
                .foregroundStyle(Theme.brandPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders active")
                    .font(.headline)
                Text("Every \(settings.reminderIntervalMinutes) min · Next: \(nextReminderText)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if remainingReminders > 0 {
                Text("\(remainingReminders) left")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.cardSurfaceLight, in: .capsule)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    private var remindersOffCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.slash.fill")
                .font(.title2)
                .foregroundStyle(Theme.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders off")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                Text("Turn them on in Settings")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    // MARK: - Response Progress

    private var responseProgressCard: some View {
        let ackCount = todayAcks.count
        let total = max(ackCount, remainingReminders + ackCount)
        let rate = total > 0 ? Double(ackCount) / Double(total) : 0

        return VStack(spacing: 10) {
            HStack {
                Text("Today's response rate")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(ackCount)/\(total)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
            }

            ProgressView(value: rate)
                .tint(rate > 0.6 ? Theme.good : (rate > 0.3 ? Theme.borderline : Theme.bad))
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    // MARK: - Today's Summary

    private var todaySummaryCard: some View {
        HStack(spacing: 16) {
            // Camera scan count
            VStack(spacing: 4) {
                Image(systemName: "camera.viewfinder")
                    .font(.title3)
                    .foregroundStyle(Theme.brandPrimary)
                Text("\(cameraAckCount)")
                    .font(.title3.bold())
                Text(cameraAckCount == 1 ? "scan" : "scans")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            // Manual check count
            VStack(spacing: 4) {
                Image(systemName: "hand.tap")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary)
                Text("\(todayAcks.count - cameraAckCount)")
                    .font(.title3.bold())
                Text("manual")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40)

            // Streak day
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.streakFlame)
                Text("\(streak.currentStreak)")
                    .font(.title3.bold())
                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
    }

    // MARK: - Check-in

    private var checkInCard: some View {
        Button {
            showingAck = true
        } label: {
            HStack {
                Image(systemName: "figure.stand")
                    .font(.headline)
                Text("Check in now")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(label: "Longest", value: "\(streak.longestStreak)")
            statTile(label: "Freezes", value: "\(streak.freezesAvailable)")
            statTile(label: "Total check-ins", value: "\(acknowledgments.count)")
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

    // MARK: - Helpers

    private func refreshReminderStatus() async {
        if settings.reminderEnabled {
            let next = await ReminderScheduler.nextReminderDate()
            nextReminderText = next.map { formatReminderTime($0) } ?? "later today"
            remainingReminders = await ReminderScheduler.remainingCount()
        } else {
            nextReminderText = "—"
            remainingReminders = 0
        }
    }

    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
