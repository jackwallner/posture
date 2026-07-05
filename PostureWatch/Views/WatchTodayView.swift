import SwiftData
import SwiftUI

struct WatchTodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var streaks: [StreakState]
    @State private var settings = GoalSettings.shared
    @State private var subscriptions = SubscriptionService.shared
    @State private var background = BackgroundPostureWorkout.shared

    /// Display-only - never insert a StreakState during body evaluation
    /// (audit P1-10). Creation is owned by StreakService on the phone.
    private var currentStreak: Int { StreakService.displayStreak(for: streaks.first) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(currentStreak > 0 ? Theme.streakFlame : Theme.textTertiary)
                        Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s")")
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
            .containerBackground(Theme.dawnWash, for: .navigation)
        }
        .task {
            WatchSyncService.shared.activate()
            WatchSyncService.shared.onAlwaysOnReceived = { _ in
                Task { await applyAlwaysOn() }
            }
            await applyAlwaysOn()
        }
        .onChange(of: settings.alwaysOnEnabled) { _, _ in
            Task { await applyAlwaysOn() }
        }
    }

    /// Reconcile the (possibly phone-synced) preference with the live
    /// workout: start it when monitoring is on for a Pro user, stop it
    /// otherwise. Idempotent - safe to call on launch and on every change.
    @MainActor
    private func applyAlwaysOn() async {
        let shouldRun = settings.alwaysOnEnabled && subscriptions.isProSubscriber
        if shouldRun, !background.isActive {
            let cal = CalibrationService(context: context).current()
                ?? Calibration(basePitch: 0, baseYaw: 0, baseRoll: 0, slouchPitchDelta: .pi / 6)
            _ = await background.requestAuthorization()
            await background.start(calibration: cal)
        } else if !shouldRun, background.isActive {
            background.stop()
        }
    }

    /// Best quality score from today's camera acknowledgments or sessions.
    private var bestTodayScore: Int {
        let today = Calendar.current.startOfDay(for: .now)

        // Check scored AcknowledgmentRecords (camera or airpods) for today
        let ackPredicate = #Predicate<AcknowledgmentRecord> { record in
            (record.methodRaw == "camera" || record.methodRaw == "airpods")
                && record.qualityRaw != nil
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
    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: 8)
            // Dawn: sand → lavender sweep, matching the phone ring.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.ringSweep, style: .init(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: 80, height: 80)
    }
}
