import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(AirpodsBackgroundMonitor.self) private var airpodsMonitor: AirpodsBackgroundMonitor?
    @Query private var streaks: [StreakState]
    @Query(sort: \AcknowledgmentRecord.timestamp, order: .reverse) private var acknowledgments: [AcknowledgmentRecord]

    @State private var showingAck = false
    @State private var showingRecalibrate = false
    @State private var showingMonitorLog = false
    @State private var showingSession = false
    @State private var showingWalk = false
    @State private var showingWalkPaywall = false
    @State private var showingAchievements = false
    @State private var showingLevelLadder = false
    @State private var showingStreakDetail = false
    @State private var nextReminderText = "–"
    @State private var remainingReminders = 0
    @State private var currentTip = PostureTipService.randomTip()
    @State private var subscriptions = SubscriptionService.shared
    @Query(sort: \Calibration.capturedAt, order: .reverse) private var calibrations: [Calibration]
    @Query private var passiveSamples: [PosturePassiveSample]
    @Query private var minuteSamples: [PostureMinuteSample]
    @Query(sort: \PostureSession.startedAt, order: .reverse) private var sessions: [PostureSession]

    private var passiveSamplesToday: Int {
        let today = DateHelpers.startOfDay()
        return passiveSamples.filter { $0.timestamp >= today }.count
    }

    /// Live day stats from the continuous monitor's minute aggregates.
    private var dayStats: PostureDayStats {
        let today = DateHelpers.startOfDay()
        return PostureDayStats.compute(
            minutes: minuteSamples.filter { $0.minuteStart >= today }.map(\.statsIngest)
        )
    }

    /// A real AirPods calibration baseline exists - required before the live
    /// monitor can honestly score posture.
    private var hasAirpodsBaseline: Bool {
        calibrations.first?.airpodsPitch != nil
    }

    /// The continuous monitor when it's actually producing a trustworthy live
    /// reading: armed, AirPods connected, and calibrated. This is the primary
    /// posture signal - the on-demand scan is now the fallback.
    private var liveMonitor: AirpodsBackgroundMonitor? {
        guard let m = airpodsMonitor, m.isMonitoring, m.isConnected, hasAirpodsBaseline else { return nil }
        return m
    }

    /// Show a soft prompt to recalibrate after 30+ days - head pose drifts
    /// against the saved baseline (especially with AirPods which sit
    /// differently each time).
    private var needsRecalibration: Bool {
        guard let last = calibrations.first else { return false }
        let days = Calendar.current.dateComponents([.day], from: last.capturedAt, to: .now).day ?? 0
        return days >= 30
    }

    /// Display-only streak. Does not insert a StreakState during body
    /// evaluation (audit P1-10) - creation is owned by StreakService.
    /// `displayStreak` zeroes out a run that already lapsed, so we never
    /// show "12 days" when the streak is dead.
    private var currentStreak: Int { StreakService.displayStreak(for: streaks.first) }

    /// Display-only freeze count - so users know their streak has a safety net.
    private var freezesAvailable: Int { streaks.first?.freezesAvailable ?? 0 }

    private var todayAcks: [AcknowledgmentRecord] {
        let today = DateHelpers.startOfDay()
        return acknowledgments.filter { $0.timestamp >= today }
    }

    // MARK: - Practice progression inputs

    private var passedPracticeCount: Int {
        sessions.filter { $0.kind == .practice && $0.passed }.count
    }

    /// The practice level, capped for free users.
    private var practiceLevel: Int {
        PracticeProgression.effectiveLevel(
            level: PracticeProgression.level(passedSessions: passedPracticeCount),
            isPro: subscriptions.isProSubscriber
        )
    }

    private var isLevelCappedByFreeTier: Bool {
        !subscriptions.isProSubscriber
            && PracticeProgression.level(passedSessions: passedPracticeCount) > PracticeProgression.freeLevelCap
    }

    /// Today's completed practice session, if any (newest first).
    private var todayCompletedPractice: PostureSession? {
        let today = DateHelpers.startOfDay()
        return sessions.first { $0.kind == .practice && $0.completed && $0.startedAt >= today }
    }

    private var scoredAcks: [AcknowledgmentRecord] {
        todayAcks.compactMap { $0.quality == nil ? nil : $0 }
    }

    /// Mean of today's scored check-ins, 0–100, or nil if none scored.
    private var alignmentScore: Int? {
        let scores = scoredAcks.compactMap { $0.quality.map(qualityScore) }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerGreeting

                    if isAirpodsUser {
                        airpodsTodayContent
                    } else {
                        manualTodayContent
                    }

                    tipCard(tip: currentTip)
                        .onTapGesture {
                            withAnimation { currentTip = PostureTipService.randomTip() }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .dawnBackground()
            .navigationBarHidden(true)
            // Settings' "Replay practice coach marks" resets the flag and
            // relaunches a session so the marks run again.
            .onReceive(NotificationCenter.default.publisher(for: .postureReplaySessionCoachMarks)) { _ in
                showingSession = true
            }
            .fullScreenCover(isPresented: $showingAck) {
                AcknowledgmentView(scheduledAt: .now, notificationIndex: nil)
            }
            .fullScreenCover(isPresented: $showingSession) {
                PracticeSessionView()
            }
            .fullScreenCover(isPresented: $showingWalk) {
                WalkSessionView()
            }
            .sheet(isPresented: $showingWalkPaywall) {
                PaywallView(paywallImpressionId: "posture_walk_gate")
            }
            .sheet(isPresented: $showingRecalibrate) {
                CalibrationView(mode: .quickRecalibrate)
            }
            .sheet(isPresented: $showingMonitorLog) {
                MonitoringLogView()
            }
            .sheet(isPresented: $showingAchievements) {
                AchievementsView()
            }
            .sheet(isPresented: $showingLevelLadder) {
                LevelLadderView()
            }
            .sheet(isPresented: $showingStreakDetail) {
                StreakDetailView()
            }
            .task { await refreshReminderStatus() }
            // The cold-launch reschedule rewrites the pending-notification
            // queue while our .task above is reading it, so the first read
            // often lands mid-rewrite and shows "0 more today". Re-read once
            // the scheduler says the queue is settled.
            .onReceive(NotificationCenter.default.publisher(for: .postureRemindersRescheduled)) { _ in
                Task { await refreshReminderStatus() }
            }
            .onChange(of: settings.reminderEnabled) { _, _ in
                Task { await refreshReminderStatus() }
            }
            .onChange(of: settings.reminderIntervalMinutes) { _, _ in
                Task { await refreshReminderStatus() }
            }
        }
    }

    // MARK: - Header

    private var headerGreeting: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeOfDayGreeting)
                    .font(Theme.font(.caption, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Text("Today")
                    .font(Theme.font(size: 34, weight: .regular))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            if currentStreak > 0 {
                Button { showingStreakDetail = true } label: {
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.sand)
                            Text("\(currentStreak)-day streak")
                                .font(Theme.font(.footnote, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .dawnCapsule()
                        if freezesAvailable > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("\(freezesAvailable) \(freezesAvailable == 1 ? "save" : "saves") ready")
                                    .font(Theme.font(.caption2, weight: .semibold))
                            }
                            .foregroundStyle(Theme.ink3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(currentStreak) day streak, \(freezesAvailable) saves ready. Tap for streak details.")
            }
        }
        .padding(.top, 12)
    }

    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello, night owl"
        }
    }

    /// AirPods owners are the core experience: continuous monitoring is the
    /// product, so the manual check-in is demoted to a tiny link.
    private var isAirpodsUser: Bool { settings.hasAirpods == true }

    // MARK: - AirPods (practice-first) content

    @ViewBuilder
    private var airpodsTodayContent: some View {
        // Live posture leads the page: with AirPods in and the app open, the
        // top card is your alignment right now (free, on by default).
        if let m = airpodsMonitor, m.isMonitoring || m.userPaused {
            VStack(spacing: 6) {
                if m.userPaused {
                    pausedMonitorCard(m)
                } else {
                    if let monitor = liveMonitor {
                        liveAlignmentCard(monitor: monitor)
                    } else {
                        armedCard(monitor: m)
                    }
                    monitorStopRow(m)
                }
            }
        }

        practiceHero

        achievementsRow

        walkCard

        // One-time explainer for users who learned the old monitoring-first
        // loop: the streak now comes from the daily practice.
        if settings.hasSeenTrainingTour && !settings.hasSeenPivotExplainer {
            softBanner(
                title: "Your streak has a new home.",
                body: "Posture is now built around one short daily practice: a few minutes held tall, with live coaching. Finishing it keeps your streak. All-day monitoring still lives in Settings if you want it.",
                actionLabel: "Got it",
                action: { settings.hasSeenPivotExplainer = true }
            )
        }

        todayReportCard

        if needsRecalibration {
            softBanner(
                title: "Time for a quick recalibrate.",
                body: "AirPods sit a little differently over time, and posture shifts too. A quick reset keeps readings honest.",
                actionLabel: "Recalibrate",
                action: { showingRecalibrate = true }
            )
        }

        // Manual check-in is a minor escape hatch here, not the main event.
        Button { showingAck = true } label: {
            Text("Log a manual check-in")
                .font(Theme.font(.footnote, weight: .medium))
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    // MARK: - Practice hero (the core loop)

    @ViewBuilder
    private var practiceHero: some View {
        if let done = todayCompletedPractice {
            practiceCompletedCard(done)
        } else {
            practiceStartCard
        }
    }

    private var practiceStartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's practice")
                    .font(Theme.font(.caption, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.sage)
                Spacer()
                levelBadge
            }
            Text("\(practiceMinutesLabel), held tall.")
                .font(Theme.display(24))
                .foregroundStyle(Theme.ink)
            Text("Pop your AirPods in and hold your best posture with live coaching. Finish it and today's streak day is yours.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button { showingSession = true } label: {
                Text("Begin today's practice")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.top, 4)
            practiceProgressStrip
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    private func practiceCompletedCard(_ session: PostureSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Practice complete")
                    .font(Theme.font(.caption, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.sage)
                Spacer()
                levelBadge
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(session.alignedPercent)%")
                    .font(Theme.font(size: 40, weight: .regular))
                    .foregroundStyle(session.passed ? Theme.sage : Theme.sand)
                Text(session.passed ? "aligned, target met." : "aligned today.")
                    .font(Theme.display(19))
                    .foregroundStyle(Theme.ink)
            }
            Text(session.passed
                 ? "Target met. That pip counts toward your next level."
                 : "The streak day is yours. Hit the \(session.targetPercent)% bar to fill a pip.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            practiceProgressStrip
            Button { showingSession = true } label: {
                Text("Practice again →")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    /// Walk mode entry (Pro). Free users see it locked - tapping opens the
    /// walk paywall, so the feature sells itself.
    private var walkCard: some View {
        Button {
            if subscriptions.isProSubscriber {
                showingWalk = true
            } else {
                showingWalkPaywall = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.sageTint)
                        .frame(width: 40, height: 40)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.sage)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Take it for a walk")
                        .font(Theme.font(.body, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("See how tall you carry yourself out there.")
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
                Image(systemName: subscriptions.isProSubscriber ? "chevron.right" : "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subscriptions.isProSubscriber
            ? "Start a posture walk"
            : "Posture walks, a Posture plus feature")
    }

    private var levelBadge: some View {
        Button { showingLevelLadder = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.up.2")
                    .font(.system(size: 9, weight: .semibold))
                Text("Level \(practiceLevel)")
                    .font(Theme.font(.caption, weight: .semibold))
            }
            .foregroundStyle(Theme.sage)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.sageTint, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Level \(practiceLevel). Tap to see how levels work.")
    }

    @ViewBuilder
    private var practiceProgressStrip: some View {
        if isLevelCappedByFreeTier {
            Button { showingLevelLadder = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Level \(PracticeProgression.freeLevelCap) · full program with Posture+")
                        .font(Theme.font(.caption, weight: .semibold))
                }
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                NotificationCenter.default.post(name: .postureSelectProgressTab, object: nil)
            } label: {
                HStack(spacing: 12) {
                    if currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.sand)
                            Text("\(currentStreak)")
                                .font(Theme.font(.caption, weight: .bold))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    Spacer(minLength: 8)
                    let progress = PracticeProgression.progressInLevel(passedSessions: passedPracticeCount)
                    LevelPipsView(filled: progress.done, total: progress.needed, size: .compact)
                    Text("Level \(practiceLevel + 1)")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.paper3, in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Level progress, \(progressAccessibilityLabel). Tap to open program.")
        }
    }

    private var progressAccessibilityLabel: String {
        let progress = PracticeProgression.progressInLevel(passedSessions: passedPracticeCount)
        return PracticeProgressCopy.levelUpCaption(
            done: progress.done,
            needed: progress.needed,
            nextLevel: practiceLevel + 1
        )
    }

    private var practiceMinutesLabel: String {
        let minutes = PracticeProgression.sessionSeconds(forLevel: practiceLevel) / 60
        return minutes == 1 ? "One minute" : "\(minutes) minutes"
    }

    // MARK: - No-AirPods (manual) content - the compliance exception

    @ViewBuilder
    private var manualTodayContent: some View {
        checkInAlignmentCard

        weekCard

        VStack(spacing: 12) {
            Button { showingAck = true } label: { Text("Check in now") }
                .buttonStyle(.daylight(.primary))
            metaRow
        }
        .padding(.top, 4)

        if settings.calibrationDeferred {
            softBanner(
                title: "Get AirPods for the full experience.",
                body: "With AirPods, Posture watches your posture all day on its own. Without them, log how you're sitting to keep your streak.",
                actionLabel: "Set up AirPods",
                action: { showingRecalibrate = true }
            )
        } else if todayAcks.isEmpty {
            softBanner(
                title: "A new habit, gently.",
                body: "Check in a couple of times today. The pattern shows up in about a week.",
                actionLabel: "Do your first check-in",
                action: { showingAck = true }
            )
        }
    }

    // MARK: - Live alignment card (continuous monitor - primary signal)

    private func liveAlignmentCard(monitor: AirpodsBackgroundMonitor) -> some View {
        let quality = monitor.currentQuality
        return Button { showingMonitorLog = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(liveColor(quality))
                        .frame(width: 7, height: 7)
                    Text("Right now")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        Text("Activity")
                        Image(systemName: "chevron.right")
                    }
                    .font(Theme.font(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                }
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(Theme.ringTrack, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: liveRingFraction(quality))
                            .stroke(liveColor(quality), style: .init(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.5), value: quality)
                        Image(systemName: liveIcon(quality))
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(liveColor(quality))
                    }
                    .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(liveWord(quality))
                            .font(Theme.display(20))
                            .foregroundStyle(liveColor(quality))
                        Text(liveSubtitle)
                            .font(Theme.font(.footnote))
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Posture right now: \(liveWord(quality)). Tap for activity.")
    }

    /// Quiet stop control under the live card. Every monitored minute is
    /// already recorded, so stopping loses nothing already earned.
    private func monitorStopRow(_ monitor: AirpodsBackgroundMonitor) -> some View {
        Button {
            monitor.userPaused = true
            monitor.stop()
        } label: {
            Text("Stop for now")
                .font(Theme.font(.caption, weight: .semibold))
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop the live posture readout")
    }

    /// The user hit Stop - reassure that the minutes were kept and offer the
    /// way back in.
    private func pausedMonitorCard(_ monitor: AirpodsBackgroundMonitor) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.ink3)
                    .frame(width: 7, height: 7)
                Text("Live readout stopped")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Spacer(minLength: 0)
            }
            Text("Your monitored minutes are saved in today's report. Start again any time.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                monitor.userPaused = false
                let wantsBackground = subscriptions.isProSubscriber && settings.airpodsBackgroundEnabled
                _ = monitor.start(background: wantsBackground)
            } label: {
                Text("Start reading again →")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    private func liveColor(_ q: PostureQuality) -> Color {
        switch q {
        case .good: return Theme.sage
        case .borderline: return Theme.sand
        case .bad: return Theme.clay
        }
    }

    private func liveRingFraction(_ q: PostureQuality) -> Double {
        switch q {
        case .good: return 0.92
        case .borderline: return 0.55
        case .bad: return 0.22
        }
    }

    private func liveIcon(_ q: PostureQuality) -> String {
        switch q {
        case .good: return "checkmark"
        case .borderline: return "chevron.down"
        case .bad: return "exclamationmark"
        }
    }

    private func liveWord(_ q: PostureQuality) -> String {
        switch q {
        case .good: return "Aligned"
        case .borderline: return "Drifting"
        case .bad: return "Slouching"
        }
    }

    private var liveSubtitle: String {
        let stats = dayStats
        guard let percent = stats.alignedPercent else { return "Monitoring your posture live." }
        return "\(percent)% aligned · \(PostureDayStats.wearLabel(seconds: stats.wearSeconds)) today"
    }

    // MARK: - Check-in alignment card (fallback - discrete check-ins)

    private var checkInAlignmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's alignment")
                .font(Theme.font(.footnote, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Theme.ringTrack, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: Double(alignmentScore ?? 0) / 100.0)
                        .stroke(Theme.ringSweep, style: .init(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: alignmentScore)
                    Text(alignmentScore.map { "\($0)" } ?? "–")
                        .font(Theme.font(size: 34, weight: .regular))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    // Dawn: the quality word is the ritual moment - serif italic.
                    Text(readoutLabel)
                        .font(Theme.display(20))
                        .foregroundStyle(alignmentRingColor)
                    Text(readoutSubtitle)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    private var alignmentRingColor: Color {
        guard let s = alignmentScore else { return Theme.ink3 }
        switch s {
        case 70...: return Theme.sage
        case 40..<70: return Theme.sand
        default: return Theme.clay
        }
    }

    // MARK: - Week card

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today, hour by hour")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Text("\(todayAcks.count) today")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }
            DayStrip(
                acks: todayAcks,
                activeWindow: settings.activeHoursStart...settings.activeHoursEnd
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    // MARK: - Armed card (monitoring on, waiting for a live reading)

    /// Shown when monitoring is armed but not yet producing a scored reading
    /// (AirPods out of ear, or no baseline yet). Reassures the user it's on and
    /// waiting rather than broken.
    private func armedCard(monitor: AirpodsBackgroundMonitor) -> some View {
        let needsBaseline = monitor.isConnected && !hasAirpodsBaseline
        return Button { showingMonitorLog = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Theme.sand)
                        .frame(width: 7, height: 7)
                    Text("Monitoring on")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.ink3)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        Text("Activity")
                        Image(systemName: "chevron.right")
                    }
                    .font(Theme.font(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                }
                Text(needsBaseline ? "Calibrate to start reading." : "Waiting for your AirPods.")
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.ink)
                Text(needsBaseline
                     ? "Pop in your AirPods and recalibrate, and live posture readings begin."
                     : "Put your AirPods in and Posture starts watching your posture automatically.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if monitor.isConnected {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(monitorActivityLine(monitor: monitor, now: timeline.date))
                            .font(Theme.font(.caption))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Monitoring is on, waiting for AirPods")
    }

    // MARK: - Today report card (all-day rhythm - summary lives in the card)

    private var todayReportCard: some View {
        PassiveTimelineView()
    }

    // MARK: - Achievements teaser

    /// Compact badge strip: the latest earned badge or the next one worth
    /// chasing. Tap for the full badge wall.
    private var achievementsRow: some View {
        let latest = AchievementCatalog.all(streak: streaks.first, sessions: sessions)
            .filter(\.isEarned)
            .max { ($0.earnedAt ?? .distantPast) < ($1.earnedAt ?? .distantPast) }
        let next = AchievementCatalog.nextUp(streak: streaks.first, sessions: sessions)
        return Button { showingAchievements = true } label: {
            HStack(spacing: 12) {
                Image(systemName: latest?.systemImage ?? "rosette")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.lavender)
                    .frame(width: 32, height: 32)
                    .background(Theme.lavenderTint, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    if let latest {
                        Text("Latest badge: \(latest.title)")
                            .font(Theme.font(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    } else {
                        Text("Badges")
                            .font(Theme.font(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    if let next {
                        Text("Next up: \(next.title)")
                            .font(Theme.font(.caption))
                            .foregroundStyle(Theme.ink3)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .dawnCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Badges. Tap to see all badges.")
    }

    private func monitorActivityLine(monitor: AirpodsBackgroundMonitor, now: Date) -> String {
        guard let last = monitor.lastSampleAt else { return "Waiting for the first reading…" }
        let ago = max(0, Int(now.timeIntervalSince(last)))
        let agoText = ago <= 2 ? "just now" : "\(ago)s ago"
        return "\(monitor.samplesToday.formatted()) readings today · last \(agoText)"
    }

    // MARK: - Soft banner

    private func softBanner(title: String, body: String, actionLabel: String?, action: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel + " →")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.sage)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.lavenderTint)
        )
    }

    private func tipCard(tip: PostureTip) -> some View {
        TipLine(tip: tip)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dawnCard()
    }

    // MARK: - Readout copy

    private var readoutLabel: String {
        guard let s = alignmentScore else {
            return todayAcks.isEmpty ? "No scans yet" : "Checked in"
        }
        switch s {
        case 70...: return "Aligned"
        case 40..<70: return "Drifting"
        default: return "Slouching"
        }
    }

    private var readoutSubtitle: String {
        if scoredAcks.isEmpty {
            return todayAcks.isEmpty ? "Your first reading lands after a scan." : "Manual check-ins only"
        }
        let onTrack = scoredAcks.filter { $0.quality == .good }.count
        return "\(onTrack) of \(scoredAcks.count) scans on track"
    }

    // MARK: - Meta row

    @ViewBuilder
    private var metaRow: some View {
        if settings.reminderEnabled {
            Text("Next reminder \(nextReminderText) · \(remainingReminders) more today")
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
        } else {
            HStack(spacing: 6) {
                Text("Reminders are off.")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
                Button {
                    settings.reminderEnabled = true
                    Task { await ReminderScheduler.reschedule() }
                } label: {
                    Text("Turn on →")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundStyle(Theme.sage)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func qualityScore(_ q: PostureQuality) -> Int {
        switch q {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }

    private func refreshReminderStatus() async {
        if settings.reminderEnabled {
            let next = await ReminderScheduler.nextReminderDate()
            nextReminderText = next.map { formatReminderTime($0) } ?? "later today"
            remainingReminders = await ReminderScheduler.remainingCount()
        } else {
            nextReminderText = "–"
            remainingReminders = 0
        }
    }

    private func formatReminderTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
