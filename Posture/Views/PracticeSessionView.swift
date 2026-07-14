import SwiftData
import SwiftUI

/// The daily practice session: a bounded, AirPods-coached posture hold.
/// Pre-start → live (ring + countdown) → paused (pods out / by hand) →
/// summary. The first-ever session doubles as the tutorial via three
/// lightweight coach marks.
struct PracticeSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    /// Which posture ladder this session trains. Today passes the user's
    /// selected mode; the notification-tap path defaults to standing.
    var mode: PostureMode = .standing

    @State private var controller: PracticeSessionController?
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var showingEndConfirm = false
    @State private var coachStep: CoachStep? = nil
    @State private var coachSlouchFelt = false
    @State private var showRepsSkip = false
    /// Custom session length (minutes). nil = the level's own duration.
    @State private var customMinutes: Int? = nil

    private let customDurationOptions = [3, 5, 10, 15, 20, 30]

    private enum CoachStep: Int {
        case ring, slouch, hold
    }

    var body: some View {
        Group {
            if let controller {
                content(controller)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if controller == nil {
                controller = PracticeSessionController(context: context)
            }
        }
        .onDisappear {
            // Covers swipe-dismiss and parent teardown: hand the motion
            // stream back and record an honest partial if one exists.
            controller?.cancel()
        }
        .sheet(isPresented: $showingPaywall, onDismiss: { dismiss() }) {
            PaywallView(paywallImpressionId: "posture_post_first_session")
        }
        .interactiveDismissDisabled(isLive)
    }

    private var isLive: Bool {
        guard let phase = controller?.phase else { return false }
        switch phase {
        case .running, .waiting, .paused, .reps: return true
        case .idle, .finished: return false
        }
    }

    @ViewBuilder
    private func content(_ controller: PracticeSessionController) -> some View {
        switch controller.phase {
        case .idle:
            preStartView(controller)
        case .reps:
            repsView(controller)
        case .waiting, .running, .paused:
            liveView(controller)
        case .finished:
            if let result = controller.result {
                SessionSummaryView(result: result, onDone: { finishAndMaybePaywall(result) })
            }
        }
    }

    // MARK: - Pre-start

    private func preStartView(_ controller: PracticeSessionController) -> some View {
        let base = PracticeSessionController.nextConfig(
            context: context, isPro: subscriptions.isProSubscriber, mode: mode
        )
        let config = configApplyingCustomDuration(base)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                levelChip(config.level)
                Spacer()
                closeButton
            }
            .padding(.top, 16)

            Spacer()

            Text("\(mode.label) practice.")
                .font(Theme.display(40))
                .foregroundStyle(Theme.ink)

            Text("A quick chin-tuck warm-up, then \(minutesLabel(config.targetSeconds)) \(focusPhrase) with your AirPods in. The ring shows your alignment live, and a nudge catches you if you drift.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 14)

            HStack(spacing: 12) {
                statPill(value: minutesLabel(config.targetSeconds), label: "duration")
                statPill(value: "\(config.targetPercent)%", label: "aligned to pass")
            }
            .padding(.top, 24)

            durationPicker(base)

            if let error = controller.lastError {
                Text(error)
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.badText)
                    .padding(.top, 12)
            }

            Spacer()

            Button {
                controller.start(config: config)
            } label: {
                Text("Begin")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dawnBackground()
    }

    /// Custom lengths keep the streak but sit outside the ladder - the level
    /// only moves at its own duration, so a 3-minute custom day can't farm
    /// passes.
    private func configApplyingCustomDuration(
        _ base: PracticeSessionController.Config
    ) -> PracticeSessionController.Config {
        guard let minutes = customMinutes, minutes * 60 != base.targetSeconds else { return base }
        return PracticeSessionController.Config(
            kind: .practice,
            targetSeconds: minutes * 60,
            targetPercent: base.targetPercent,
            level: base.level,
            repsTarget: base.repsTarget,
            countsForLevel: false,
            postureMode: base.postureMode,
            isPro: base.isPro
        )
    }

    private func durationPicker(_ base: PracticeSessionController.Config) -> some View {
        let levelMinutes = base.targetSeconds / 60
        return VStack(alignment: .leading, spacing: 6) {
            Menu {
                Button {
                    customMinutes = nil
                } label: {
                    Label("Level \(base.level) length · \(levelMinutes) min", systemImage: customMinutes == nil ? "checkmark" : "chevron.up.2")
                }
                ForEach(customDurationOptions.filter { $0 != levelMinutes }, id: \.self) { minutes in
                    Button {
                        customMinutes = minutes
                    } label: {
                        if customMinutes == minutes {
                            Label("\(minutes) minutes", systemImage: "checkmark")
                        } else {
                            Text("\(minutes) minutes")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text(customMinutes == nil ? "Change length" : "Custom length: \(customMinutes!) min")
                        .font(Theme.font(.footnote, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.goodText)
            }
            if customMinutes != nil {
                Text("Custom lengths keep your streak. Level progress needs the level's own length.")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Chin-tuck warm-up

    private func repsView(_ controller: PracticeSessionController) -> some View {
        let done = controller.repsCompleted
        let target = max(controller.repsTarget, 1)
        return VStack(spacing: 0) {
            HStack {
                warmupChip
                Spacer()
                Button {
                    controller.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(.body, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End session")
            }
            .padding(.top, 16)

            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.ringTrack, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: Double(done) / Double(target))
                    .stroke(Theme.lavender, style: .init(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: done)
                VStack(spacing: 6) {
                    Text("\(done)")
                        .font(Theme.font(size: 64, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: done)
                    Text("of \(target) reps")
                        .font(Theme.display(19))
                        .foregroundStyle(Theme.lavender)
                }
            }
            .frame(width: 240, height: 240)
            .accessibilityLabel("\(done) of \(target) chin tucks done")

            VStack(spacing: 10) {
                Text("Warm up your neck.")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ink)
                Text(controller.isAirpodsConnected
                     ? "Gently draw your chin straight back, like a small double chin, then return to level. Slow and easy."
                     : "Pop your AirPods in to begin. Reps count from your first reading.")
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.top, 26)

            Spacer()

            if showRepsSkip {
                Button {
                    AnalyticsService.chinTuckWarmupSkipped(repsCompleted: done)
                    controller.skipReps()
                } label: {
                    Text("Skip the warm-up")
                }
                .buttonStyle(.daylight(.ghost))
                .padding(.bottom, 8)
            }
            #if DEBUG
            Button { controller.debugCountRep() } label: {
                Text("Done with this rep (debug)")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
            #else
            Color.clear.frame(height: 20)
            #endif
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
        .task {
            // If detection isn't landing (odd AirPods pitch response, wrong
            // fit), never dead-end the session behind the warm-up. Offer the
            // skip quickly so no one is stranded staring at "0 of 5".
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if controller.phase == .reps { withAnimation { showRepsSkip = true } }
        }
    }

    private var warmupChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "figure.flexibility")
                .font(.system(size: 11, weight: .semibold))
            Text("Warm-up")
                .font(Theme.font(.footnote, weight: .semibold))
        }
        .foregroundStyle(Theme.lavender)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.lavenderTint, in: .capsule)
    }

    // MARK: - Live

    private func liveView(_ controller: PracticeSessionController) -> some View {
        let quality = controller.currentQuality
        let paused = isPaused(controller.phase)
        return ZStack {
            VStack(spacing: 0) {
                HStack {
                    if let config = controller.config {
                        levelChip(config.level)
                    }
                    Spacer()
                    Button {
                        if controller.elapsedSeconds >= 30 {
                            showingEndConfirm = true
                        } else {
                            controller.cancel()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(Theme.font(.body, weight: .medium))
                            .foregroundStyle(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("End session")
                }
                .padding(.top, 16)

                Spacer()

                sessionRing(controller, quality: quality, paused: paused)

                Text(statusLine(controller))
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .animation(.easeInOut(duration: 0.25), value: controller.phase)

                Spacer()

                HStack(spacing: 12) {
                    if case .paused(.user) = controller.phase {
                        Button { controller.resume() } label: {
                            Text("Resume").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.daylight(.primary))
                    } else {
                        Button { controller.pauseByUser() } label: {
                            Text("Pause").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.daylight(.secondary))
                        .disabled(paused)
                    }
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)

            if let step = coachStep {
                coachOverlay(step: step, controller: controller)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
        .onAppear {
            // First session: the coach marks teach the hold, after the warm-up.
            if !settings.hasSeenSessionCoachMarks, coachStep == nil {
                coachStep = .ring
            }
        }
        .onChange(of: quality) { _, newQuality in
            if coachStep == .slouch, newQuality == .bad {
                withAnimation { coachSlouchFelt = true }
            }
        }
        .confirmationDialog("End this session?", isPresented: $showingEndConfirm) {
            Button("End session", role: .destructive) {
                controller.endEarly()
            }
            Button("Keep going", role: .cancel) { }
        } message: {
            Text("Ending early keeps today's minutes but doesn't finish the practice.")
        }
    }

    private func sessionRing(_ controller: PracticeSessionController, quality: PostureQuality, paused: Bool) -> some View {
        let progress = sessionProgress(controller)
        let color = paused ? Theme.ink3 : qualityColor(quality)
        return ZStack {
            Circle()
                .stroke(Theme.ringTrack, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: .init(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            VStack(spacing: 6) {
                Text(timeLabel(controller.remainingSeconds))
                    .font(Theme.font(size: 54, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.2), value: controller.remainingSeconds)
                Text(paused ? "paused" : qualityWord(quality))
                    .font(Theme.display(19))
                    .foregroundStyle(paused ? Theme.ink3 : Theme.qualityTextColor(quality))
                if controller.elapsedSeconds > 10 {
                    Text("\(Int((controller.alignedFractionSoFar * 100).rounded()))% aligned")
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityLabel("\(timeLabel(controller.remainingSeconds)) remaining, currently \(qualityWord(quality))")
    }

    // MARK: - Coach marks (first session = tutorial)

    private func coachOverlay(step: CoachStep, controller: PracticeSessionController) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text(coachTitle(step))
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(coachBody(step, controller: controller))
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    advanceCoach(from: step)
                } label: {
                    // The waiting state stays fully readable (the old 35%-
                    // opacity treatment was near-invisible on the tint).
                    Text(step == .slouch && !coachSlouchFelt
                         ? "Waiting for the slouch…"
                         : coachAction(step) + " →")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(step == .slouch && !coachSlouchFelt ? Theme.ink2 : Theme.goodText)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .disabled(step == .slouch && !coachSlouchFelt)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.lavenderTint)
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: coachStep)
    }

    private func coachTitle(_ step: CoachStep) -> String {
        switch step {
        case .ring: return "This ring is your alignment."
        case .slouch: return coachSlouchFelt ? "Felt it?" : "Now slouch. On purpose."
        case .hold: return "That's the whole practice."
        }
    }

    private func coachBody(_ step: CoachStep, controller: PracticeSessionController) -> String {
        switch step {
        case .ring:
            return "Green means aligned, amber means drifting, coral means slouching. Your AirPods read it about 25 times a second."
        case .slouch:
            return coachSlouchFelt
                ? "Sit back up and watch it turn green. During practice, a slouch held for ~15 seconds earns a gentle buzz."
                : "Really let go, chin toward your chest, shoulders forward. Watch the ring flip."
        case .hold:
            return "Hold it tall for \(timeLabel(controller.remainingSeconds)) more. Finish and today's streak day is yours; hit the target % and you level up."
        }
    }

    private func coachAction(_ step: CoachStep) -> String {
        switch step {
        case .ring: return "Got it"
        case .slouch: return "Sitting tall again"
        case .hold: return "Let's go"
        }
    }

    private func advanceCoach(from step: CoachStep) {
        withAnimation {
            switch step {
            case .ring: coachStep = .slouch
            case .slouch: coachStep = .hold
            case .hold:
                coachStep = nil
                settings.hasSeenSessionCoachMarks = true
            }
        }
    }

    // MARK: - Finish

    private func finishAndMaybePaywall(_ result: PracticeSessionController.Result) {
        if result.completed, !subscriptions.isProSubscriber, !settings.hasSeenIntroPaywall {
            settings.hasSeenIntroPaywall = true
            showingPaywall = true
        } else {
            dismiss()
        }
    }

    // MARK: - Bits

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(Theme.font(.body, weight: .medium))
                .foregroundStyle(Theme.ink3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func levelChip(_ level: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.up.2")
                .font(.system(size: 10, weight: .semibold))
            Text("Level \(level)")
                .font(Theme.font(.footnote, weight: .semibold))
        }
        .foregroundStyle(Theme.goodText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.sageTint, in: .capsule)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.font(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .dawnCard()
    }

    private func isPaused(_ phase: PracticeSessionController.Phase) -> Bool {
        if case .paused = phase { return true }
        if case .waiting = phase { return true }
        return false
    }

    private func statusLine(_ controller: PracticeSessionController) -> String {
        switch controller.phase {
        case .waiting:
            return "Pop your AirPods in to begin, the clock starts with your first reading."
        case .paused(.airpodsOut):
            return "AirPods are out. The clock is paused until they're back in."
        case .paused(.user):
            return "Paused. Your minutes are safe."
        case .running:
            switch controller.currentQuality {
            case .good: return "Tall and easy. Keep breathing."
            case .borderline: return "Drifting a little, lift the crown of your head."
            case .bad: return "Curled forward. Ears back over shoulders."
            }
        default:
            return ""
        }
    }

    private func sessionProgress(_ controller: PracticeSessionController) -> Double {
        guard let target = controller.config?.targetSeconds, target > 0 else { return 0 }
        return min(controller.elapsedSeconds / Double(target), 1)
    }

    private func qualityColor(_ q: PostureQuality) -> Color {
        switch q {
        case .good: return Theme.sage
        case .borderline: return Theme.sand
        case .bad: return Theme.clay
        }
    }

    private func qualityWord(_ q: PostureQuality) -> String {
        switch q {
        case .good: return "Aligned"
        case .borderline: return "Drifting"
        case .bad: return "Slouching"
        }
    }

    private func timeLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func minutesLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    /// Coaching copy names the posture this session is training.
    private var focusPhrase: String {
        switch mode {
        case .standing: return "standing tall"
        case .sitting: return "sitting tall"
        }
    }
}
