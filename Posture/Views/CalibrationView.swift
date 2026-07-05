import SwiftData
import SwiftUI

/// AirPods calibration. Four reads, each confirmed by the user with a redo
/// option: standing tall → standing slouch → sitting tall → sitting slouch.
/// The aligned reads become per-posture baselines; each slouch read sets that
/// posture's personal range, so a subtle standing slouch and a deep chair
/// collapse are judged on their own scales. If no motion ever arrives we
/// surface the "compatible AirPods required" gate.
struct CalibrationView: View {
    enum Mode {
        case onboarding
        case quickRecalibrate
    }

    let mode: Mode

    init(mode: Mode = .onboarding) {
        self.mode = mode
    }

    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var airpods = HeadphoneMotionService()
    @State private var phase: Phase = .waiting
    @State private var countdown: Int = 4
    @State private var showSkipHint = false

    @State private var captures: [PoseStep: PoseCapture] = [:]
    @State private var savedConfidence: Double?

    @State private var sequenceTask: Task<Void, Never>?
    @State private var waitDeadlineTask: Task<Void, Never>?
    @State private var permissionWatchTask: Task<Void, Never>?

    /// Set by the per-step buttons; the capture sequence polls these.
    @State private var prepDecision: PrepDecision?
    @State private var reviewDecision: ReviewDecision?

    private enum PrepDecision { case confirmed, skipped }
    private enum ReviewDecision { case accepted, redo }

    /// One steady read of a pose: its mean pitch, how tight the hold was, and
    /// the accompanying yaw/roll means (kept from the sitting read).
    private struct PoseCapture {
        let pitch: Double
        let standardDeviation: Double
        let yaw: Double?
        let roll: Double?
    }

    /// The four reads, in order.
    enum PoseStep: CaseIterable, Equatable {
        case standing
        case standingSlouch
        case sitting
        case sittingSlouch

        var isSlouch: Bool { self == .standingSlouch || self == .sittingSlouch }
    }

    enum Phase: Equatable {
        case waiting              // AirPods not yet sending samples
        case prep(PoseStep)       // instructions, wait for "I'm ready"
        case capturing(PoseStep)  // countdown + read
        case review(PoseStep)     // confirm the measurement or redo
        case unsupported          // gave up, show the gate
        case permissionDenied     // motion access is off, not missing hardware
        case done                 // saved
    }

    /// Generous: lets a user pop AirPods in after launching the app.
    private let connectDeadlineSeconds: Double = 30
    /// After this long with no AirPods, offer an escape so a user (or reviewer)
    /// without compatible AirPods is never trapped on a static screen.
    private let skipHintSeconds: Double = 6

    var body: some View {
        Group {
            switch phase {
            case .waiting: waitingStep
            case .prep(let step): prepView(step)
            case .capturing(let step): captureView(step)
            case .review(let step): reviewView(step)
            case .unsupported: unsupportedStep
            case .permissionDenied: permissionDeniedStep
            case .done: doneStep
            }
        }
        .dawnBackground()
        .task { begin() }
        .onChange(of: airpods.isConnected) { _, connected in
            if connected, phase == .waiting {
                startSequence()
            }
        }
        // Samples are the ground truth that AirPods are in and streaming -
        // `isConnected` can already be true (so onChange never re-fires) when a
        // capture rewound to .waiting, e.g. because the Motion & Fitness
        // permission dialog swallowed the first capture window.
        .onChange(of: airpods.lastPitch) { _, pitch in
            if pitch != nil, phase == .waiting {
                startSequence()
            }
        }
        .onDisappear {
            sequenceTask?.cancel()
            waitDeadlineTask?.cancel()
            permissionWatchTask?.cancel()
            airpods.stop()
            AirpodsBackgroundMonitor.shared.resumeAfterForegroundRead()
        }
    }

    // MARK: - Step copy

    private func eyebrow(_ step: PoseStep) -> String {
        switch step {
        case .standing: return "1 of 4 · Standing tall"
        case .standingSlouch: return "2 of 4 · Standing slouch"
        case .sitting: return "3 of 4 · Sitting tall"
        case .sittingSlouch: return "4 of 4 · Sitting slouch"
        }
    }

    private func prepTitle(_ step: PoseStep) -> String {
        switch step {
        case .standing: return "Stand up tall."
        case .standingSlouch: return "Now slouch, standing."
        case .sitting: return "Now sit down tall."
        case .sittingSlouch: return "Last one: slouch in the chair."
        }
    }

    private func prepInstruction(_ step: PoseStep) -> String {
        switch step {
        case .standing:
            return "Stand with your feet hip-width apart. Stack your ears over your shoulders, shoulders over hips, and lengthen up through the crown of your head, chin level. When you're standing tall and steady, tap below."
        case .standingSlouch:
            return "Stay on your feet and let it all go: shoulders rolled forward, chest sunk, head drifting ahead of your spine. This is the standing slump we'll coach you out of. When you're in it, tap below."
        case .sitting:
            return "Sit back so your hips fill the seat, both feet flat on the floor. Same long spine, ears over shoulders, chin level. When you're sitting tall and steady, tap below."
        case .sittingSlouch:
            return "Settle into the slump you usually catch yourself in at a desk: rounded back, chin toward your chest. When you're in your natural slouch, tap below."
        }
    }

    private func prepConfirmLabel(_ step: PoseStep) -> String {
        switch step {
        case .standing: return "I'm standing tall"
        case .standingSlouch: return "I'm slouched"
        case .sitting: return "I'm sitting tall"
        case .sittingSlouch: return "I'm slouched"
        }
    }

    private func poseDiagram(_ step: PoseStep) -> PoseDiagram.Pose {
        switch step {
        case .standing: return .standing
        case .sitting: return .sitting
        case .standingSlouch, .sittingSlouch: return .slouching
        }
    }

    private func captureAccent(_ step: PoseStep) -> (Color, Color) {
        step.isSlouch ? (Theme.clay, Theme.clayTint) : (Theme.sage, Theme.sageTint)
    }

    // MARK: - Steps UI

    private var waitingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.lavenderTint)
                    .frame(width: 200, height: 200)
                Image(systemName: "airpodspro")
                    .font(.system(size: 80, weight: .regular))
                    .foregroundStyle(Theme.lavender)
            }
            .frame(maxWidth: .infinity)

            Text("Pop in your AirPods.")
                .font(Theme.font(size: 32, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            Text("We use the head-motion sensor in your AirPods to read posture. Make sure they're connected to this iPhone. iOS will ask permission to read motion.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            // Never leave the user stranded on a static screen. After a few
            // seconds, offer a way into the app without AirPods.
            if showSkipHint && mode == .onboarding {
                Button { skipWithoutAirpods() } label: { Text("I don't have AirPods") }
                    .buttonStyle(.daylight(.ghost))
            }

            if mode == .quickRecalibrate {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.daylight(.ghost))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prepView(_ step: PoseStep) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow(step))
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 8)
            Spacer()
            PoseDiagram(pose: poseDiagram(step), height: 170)

            Text(prepTitle(step))
                .font(Theme.font(size: 32, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)

            Text(prepInstruction(step))
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { prepDecision = .confirmed } label: { Text(prepConfirmLabel(step)) }
                .buttonStyle(.daylight(.primary))

            if step.isSlouch {
                Button { prepDecision = .skipped } label: { Text("Skip, use the standard range") }
                    .buttonStyle(.daylight(.ghost))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func captureView(_ step: PoseStep) -> some View {
        let (accent, wash) = captureAccent(step)
        return VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow(step))
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 8)
            Spacer()
            ZStack {
                Circle()
                    .fill(wash)
                    .frame(width: 200, height: 200)
                Text("\(countdown)")
                    .font(Theme.display(96))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                    .animation(.default, value: countdown)
            }
            .frame(maxWidth: .infinity)

            Text("Hold it.")
                .font(Theme.font(size: 32, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)

            Text(step.isSlouch
                 ? "Stay in the slump, nice and still, while we read it."
                 : "Stay tall and still, looking straight ahead, while we read this pose.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The user confirms each read before it becomes part of the baseline -
    /// a shaky or mistimed capture gets a redo, not a bake-in.
    private func reviewView(_ step: PoseStep) -> some View {
        let capture = captures[step]
        let steady = (capture?.standardDeviation ?? 1) <= PostureScoring.stableCaptureThreshold
        return VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow(step))
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 8)
            Spacer()

            ZStack {
                Circle()
                    .fill(steady ? Theme.sageTint : Theme.sandTint)
                    .frame(width: 160, height: 160)
                Image(systemName: steady ? "checkmark" : "water.waves")
                    .font(.system(size: 54, weight: .regular))
                    .foregroundStyle(steady ? Theme.sage : Theme.sand)
            }
            .frame(maxWidth: .infinity)

            Text(steady ? "Got it." : "That read was a little shaky.")
                .font(Theme.font(size: 32, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)

            Text(reviewSummary(step, capture: capture, steady: steady))
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { reviewDecision = .accepted } label: { Text("Looks right") }
                .buttonStyle(.daylight(.primary))
            Button { reviewDecision = .redo } label: { Text("Redo this read") }
                .buttonStyle(.daylight(.ghost))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reviewSummary(_ step: PoseStep, capture: PoseCapture?, steady: Bool) -> String {
        guard let capture else { return "We couldn't read that pose. Try a redo." }
        if step.isSlouch {
            let upright = captures[step == .standingSlouch ? .standing : .sitting]?.pitch
            if let upright {
                let degrees = Int((abs(capture.pitch - upright) * 180 / .pi).rounded())
                if degrees < 2 {
                    return "That slouch reads almost identical to your tall pose. If you were holding back, redo it and really let go."
                }
                return "Your \(step == .standingSlouch ? "standing" : "sitting") slouch drops your head about \(degrees)° from tall. That distance becomes your personal range."
            }
            return "Slouch captured. That distance becomes your personal range."
        }
        return steady
            ? "A clean, steady read of your \(step == .standing ? "standing" : "sitting") posture. This is the baseline you'll be coached back to."
            : "You can keep it, but a stiller hold gives more honest coaching. Re-settle and redo if you can."
    }

    private var unsupportedStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.sandTint)
                    .frame(width: 96, height: 96)
                Image(systemName: "airpods.gen3")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Theme.sand)
            }
            .frame(maxWidth: .infinity)

            Text("We need compatible AirPods.")
                .font(Theme.font(size: 30, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Text("Posture reads alignment from the head-motion sensor in AirPods Pro (1st and 2nd gen), AirPods 3rd gen, AirPods 4 with ANC, or AirPods Max. Connect a supported pair to this iPhone and try again.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { retry() } label: { Text("Try Again") }
                .buttonStyle(.daylight(.primary))

            // An escape so a user/reviewer without compatible AirPods is never
            // dead-ended at the gate. Drops them into the no-AirPods (manual
            // check-in) mode on a neutral baseline.
            if mode == .onboarding {
                Button { skipWithoutAirpods() } label: { Text("I don't have AirPods") }
                    .buttonStyle(.daylight(.ghost))
            } else {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.daylight(.ghost))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.sandTint)
                    .frame(width: 96, height: 96)
                Image(systemName: "hand.raised.slash")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(Theme.sand)
            }
            .frame(maxWidth: .infinity)

            Text("Motion access is off.")
                .font(Theme.font(size: 30, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Text("Posture needs permission to read your AirPods' motion sensor. Turn on Motion and Fitness for Posture in Settings, then try again.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { openSettings() } label: { Text("Open Settings") }
                .buttonStyle(.daylight(.primary))

            if mode == .onboarding {
                Button { skipWithoutAirpods() } label: { Text("I don't have AirPods") }
                    .buttonStyle(.daylight(.ghost))
            } else {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.daylight(.ghost))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 180, height: 180)
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Theme.sage)
            }
            .frame(maxWidth: .infinity)

            Text("All set.")
                .font(Theme.font(size: 40, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)

            Text(doneSubtitle)
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .padding(.top, 10)

            if let confidence = savedConfidence {
                ConfidenceBar(confidence: confidence)
                    .padding(.top, 20)
            }

            Spacer()

            Button {
                if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
            } label: {
                Text(mode == .quickRecalibrate ? "Done" : "Let's go")
            }
            .buttonStyle(.daylight(.primary))
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    private var doneSubtitle: String {
        let hasBothSlouches = captures[.standingSlouch] != nil && captures[.sittingSlouch] != nil
        let hasAnySlouch = captures[.standingSlouch] != nil || captures[.sittingSlouch] != nil
        if hasBothSlouches {
            return "We've learned your tall posture standing and sitting, and your slouch in each. Every reading is scored against your own range for that posture."
        }
        if hasAnySlouch {
            return "We've learned your tall posture standing and sitting, and one of your slouches. Every reading is scored against your own range."
        }
        return "We've learned your tall posture standing and sitting. Readings are scored against the standard range until you capture your slouch."
    }

    // MARK: - State machine

    private func begin() {
        // Take exclusive ownership of the head-motion stream - the shared
        // background monitor would otherwise starve this capture's own
        // CMHeadphoneMotionManager. Resumed in onDisappear.
        AirpodsBackgroundMonitor.shared.suspendForForegroundRead()
        airpods.start()
        if airpods.isConnected {
            startSequence()
            return
        }
        armWaiting()
    }

    /// Start (or restart) the no-AirPods countdowns: a short timer that reveals
    /// the "I don't have AirPods" escape, and the longer deadline that surfaces
    /// the unsupported gate. A parallel watcher catches a denied motion
    /// permission so we show the right message (not "need AirPods").
    private func armWaiting() {
        showSkipHint = false

        waitDeadlineTask?.cancel()
        waitDeadlineTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(skipHintSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if phase == .waiting { withAnimation { showSkipHint = true } }

            try? await Task.sleep(nanoseconds: UInt64((connectDeadlineSeconds - skipHintSeconds) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if phase == .waiting {
                phase = HeadphoneMotionService.isMotionAccessDenied ? .permissionDenied : .unsupported
            }
        }

        permissionWatchTask?.cancel()
        permissionWatchTask = Task {
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                if phase == .waiting, HeadphoneMotionService.isMotionAccessDenied {
                    phase = .permissionDenied
                    return
                }
                if phase != .waiting { return }
            }
        }
    }

    private func retry() {
        phase = .waiting
        airpods.stop()
        airpods.start()
        if airpods.isConnected {
            startSequence()
            return
        }
        armWaiting()
    }

    /// Leave the AirPods gate without being trapped. Save a neutral baseline
    /// (scoring falls back to a 0 baseline; the no-AirPods mode uses manual
    /// check-ins) and flag setup as deferred + no-AirPods so the app routes to
    /// self-report instead of AirPods reads.
    private func skipWithoutAirpods() {
        sequenceTask?.cancel()
        waitDeadlineTask?.cancel()
        permissionWatchTask?.cancel()
        airpods.stop()
        AnalyticsService.calibrateStarted(mode: "skipped")
        let cal = Calibration(
            basePitch: 0,
            baseYaw: 0,
            baseRoll: 0,
            slouchPitchDelta: .pi / 24
        )
        CalibrationService(context: context).save(cal)
        settings.hasAirpods = false
        settings.calibrationDeferred = true
        if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Run the four reads in order: standing → standing slouch → sitting →
    /// sitting slouch. Every read ends on a review screen where the user
    /// accepts it or redoes it. A mid-sequence AirPods drop on an aligned
    /// read rewinds cleanly to the waiting screen so we never dead-end;
    /// a dropped slouch read just falls back to the standard range.
    private func startSequence() {
        guard phase == .waiting else { return }
        waitDeadlineTask?.cancel()
        permissionWatchTask?.cancel()
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")

        captures = [:]
        sequenceTask?.cancel()
        sequenceTask = Task {
            for step in PoseStep.allCases {
                let outcome = await runStep(step)
                switch outcome {
                case .completed, .skipped:
                    continue
                case .airpodsLost:
                    rewindToWaiting()
                    return
                case .cancelled:
                    return
                }
            }
            save()
            phase = .done
        }
    }

    private enum StepOutcome {
        case completed
        case skipped      // slouch step skipped → standard range
        case airpodsLost
        case cancelled
    }

    private func runStep(_ step: PoseStep) async -> StepOutcome {
        while true {
            phase = .prep(step)
            switch await waitForPrepDecision() {
            case nil:
                return .cancelled
            case .skipped:
                captures[step] = nil
                return .skipped
            case .confirmed:
                break
            }

            phase = .capturing(step)
            guard let capture = await captureRead(step) else {
                // A dropped slouch read shouldn't rewind two good aligned
                // captures - fall back to the standard range for it.
                return step.isSlouch ? .skipped : .airpodsLost
            }
            captures[step] = capture

            phase = .review(step)
            switch await waitForReviewDecision() {
            case nil:
                return .cancelled
            case .accepted:
                return .completed
            case .redo:
                captures[step] = nil
                continue
            }
        }
    }

    /// Park on the prep screen until the user answers. nil = cancelled.
    private func waitForPrepDecision() async -> PrepDecision? {
        prepDecision = nil
        while prepDecision == nil {
            guard !Task.isCancelled else { return nil }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
        return prepDecision
    }

    /// Park on the review screen until the user answers. nil = cancelled.
    private func waitForReviewDecision() async -> ReviewDecision? {
        reviewDecision = nil
        while reviewDecision == nil {
            guard !Task.isCancelled else { return nil }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
        return reviewDecision
    }

    /// Settle countdown, then a ~2s sampling window. Returns nil when
    /// AirPods drop or too few samples arrive.
    private func captureRead(_ step: PoseStep) async -> PoseCapture? {
        let settle = step.isSlouch ? 3 : 4
        for i in stride(from: settle, through: 1, by: -1) {
            guard !Task.isCancelled else { return nil }
            guard airpods.isConnected else { return nil }
            countdown = i
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        var pitch: [Double] = []
        var yaw: [Double] = []
        var roll: [Double] = []
        // ~2s window at 10 Hz - enough to measure the spread of the hold.
        for _ in 0..<20 {
            guard !Task.isCancelled else { return nil }
            if let p = airpods.lastPitch { pitch.append(p) }
            if let y = airpods.lastYaw { yaw.append(y) }
            if let r = airpods.lastRoll { roll.append(r) }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard pitch.count >= 10 else { return nil }

        return PoseCapture(
            pitch: pitch.reduce(0, +) / Double(pitch.count),
            standardDeviation: PostureScoring.standardDeviation(pitch),
            yaw: yaw.isEmpty ? nil : yaw.reduce(0, +) / Double(yaw.count),
            roll: roll.isEmpty ? nil : roll.reduce(0, +) / Double(roll.count)
        )
    }

    private func rewindToWaiting() {
        guard !Task.isCancelled else { return }
        phase = .waiting
        armWaiting()
    }

    private func save() {
        guard let sitting = captures[.sitting] else { return }
        let standing = captures[.standing]
        // Both aligned reads are "head level", so their mean is a more robust
        // baseline than either alone; confidence is how tight the two holds were.
        let poseMeans = [standing?.pitch, sitting.pitch].compactMap { $0 }
        let baseline = PostureScoring.combinedBaseline(poseMeans) ?? sitting.pitch
        let confidences = [standing?.standardDeviation, sitting.standardDeviation]
            .compactMap { $0 }
            .map { PostureScoring.captureConfidence(standardDeviation: $0) }
        let confidence = confidences.isEmpty
            ? nil
            : confidences.reduce(0, +) / Double(confidences.count)
        savedConfidence = confidence

        // Per-posture slouch ranges: each slouch read against its own tall pose.
        let standingSlouch: Double? = zip2(standing?.pitch, captures[.standingSlouch]?.pitch)
            .map { PostureScoring.calibratedSlouchDelta(uprightPitch: $0, slouchedPitch: $1) }
        let sittingSlouch: Double? = captures[.sittingSlouch].map {
            PostureScoring.calibratedSlouchDelta(uprightPitch: sitting.pitch, slouchedPitch: $0.pitch)
        }
        // Legacy combined delta stays as the fallback for scoring paths that
        // don't know the posture.
        let combinedDeltas = [standingSlouch, sittingSlouch].compactMap { $0 }
        let combinedDelta = combinedDeltas.isEmpty
            ? .pi / 24
            : combinedDeltas.reduce(0, +) / Double(combinedDeltas.count)

        let cal = Calibration(
            basePitch: 0,
            baseYaw: 0,
            baseRoll: 0,
            slouchPitchDelta: combinedDelta,
            airpodsPitch: baseline,
            airpodsRoll: sitting.roll,
            airpodsYaw: sitting.yaw,
            airpodsStandingPitch: standing?.pitch,
            airpodsSittingPitch: sitting.pitch,
            baselineConfidence: confidence,
            standingSlouchDelta: standingSlouch,
            sittingSlouchDelta: sittingSlouch
        )
        CalibrationService(context: context).save(cal)
        // A real AirPods capture happened - clear any deferred/no-AirPods flags.
        settings.calibrationDeferred = false
        settings.hasAirpods = true
        AnalyticsService.calibrateCompleted()
        airpods.stop()
    }

    /// Optional-pair helper: both present or nil.
    private func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
        guard let a, let b else { return nil }
        return (a, b)
    }
}

// MARK: - Confidence bar

/// A quiet strength meter on the done screen so the user can see how solid
/// their baseline is (and reassures that we captured a real, steady read).
private struct ConfidenceBar: View {
    let confidence: Double  // 0…1

    private var label: String {
        switch confidence {
        case 0.8...: return "Strong baseline"
        case 0.5..<0.8: return "Good baseline"
        default: return "Baseline saved"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.paper3)
                    Capsule()
                        .fill(Theme.sage)
                        .frame(width: max(8, geo.size.width * confidence))
                }
            }
            .frame(height: 8)
        }
    }
}
