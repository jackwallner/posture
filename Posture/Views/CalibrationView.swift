import SwiftData
import SwiftUI

/// AirPods calibration. We start the headphone motion service and capture the
/// user's aligned posture twice, standing then sitting, each behind a
/// steadiness gate so a fidgety hold is retried rather than baked into the
/// baseline. A slouch pose then sets the personal range. The two aligned reads
/// are averaged into one high-confidence baseline. If no motion ever arrives we
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
    @State private var countdown: Int = 5
    @State private var showSkipHint = false
    @State private var showSteadyRetry = false

    // Aligned captures accumulate here as the sequence advances.
    @State private var standingCapture: PoseCapture?
    @State private var sittingCapture: PoseCapture?
    @State private var capturedSlouchDelta: Double?
    @State private var savedConfidence: Double?

    @State private var sequenceTask: Task<Void, Never>?
    @State private var waitDeadlineTask: Task<Void, Never>?
    @State private var permissionWatchTask: Task<Void, Never>?

    /// One steady read of a pose: its mean pitch, how tight the hold was, and
    /// the accompanying yaw/roll means (kept from the sitting read).
    private struct PoseCapture {
        let pitch: Double
        let standardDeviation: Double
        let yaw: Double?
        let roll: Double?
    }

    enum Phase {
        case waiting          // AirPods not yet sending samples
        case standing         // capturing standing-upright
        case sitting          // capturing sitting-upright
        case slouch           // reading the user's slouch
        case unsupported      // gave up — show the gate
        case permissionDenied // motion access is off, not missing hardware
        case done             // saved
    }

    /// Generous: lets a user pop AirPods in after launching the app.
    private let connectDeadlineSeconds: Double = 30
    /// After this long with no AirPods, offer an escape so a user (or reviewer)
    /// without compatible AirPods is never trapped on a static screen.
    private let skipHintSeconds: Double = 6
    /// Settle countdown before each read, and how many times a too-jittery
    /// aligned read is retried before we accept the best-effort hold.
    private let settleSeconds = 4
    private let maxAlignedAttempts = 2

    var body: some View {
        Group {
            switch phase {
            case .waiting: waitingStep
            case .standing: alignedCaptureStep(
                eyebrow: "Aligned · standing",
                title: "Stand tall.",
                instruction: "Stack your ears over your shoulders, shoulders over hips. Lengthen up through the crown of your head, chin level. Hold still while we read it.",
                accent: Theme.sage, wash: Theme.sageTint
            )
            case .sitting: alignedCaptureStep(
                eyebrow: "Aligned · sitting",
                title: "Now sit tall.",
                instruction: "Sit back so your hips fill the seat, both feet flat. Same long spine, ears over shoulders, chin level. Hold still.",
                accent: Theme.sage, wash: Theme.sageTint
            )
            case .slouch: slouchStep
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
        // Samples are the ground truth that AirPods are in and streaming —
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

    // MARK: - Steps

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
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            Text("We use the head-motion sensor in your AirPods to read posture. Make sure they're connected to this iPhone. iOS will ask permission to read motion.")
                .font(.system(.body, design: .rounded))
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

    private func alignedCaptureStep(eyebrow: String, title: String, instruction: String, accent: Color, wash: Color) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(eyebrow.uppercased())
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 8)
            Spacer()
            ZStack {
                Circle()
                    .fill(wash)
                    .frame(width: 200, height: 200)
                Text("\(countdown)")
                    .font(Theme.displaySerif(96))
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                    .animation(.default, value: countdown)
            }
            .frame(maxWidth: .infinity)

            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)

            Text(instruction)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            if showSteadyRetry {
                Label("That read was a little shaky. Hold as still as you can.", systemImage: "hand.raised.slash")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.sand)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var slouchStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("YOUR RANGE")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 8)
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.clayTint)
                    .frame(width: 200, height: 200)
                Text("\(countdown)")
                    .font(Theme.displaySerif(96))
                    .foregroundStyle(Theme.clay)
                    .contentTransition(.numericText())
                    .animation(.default, value: countdown)
            }
            .frame(maxWidth: .infinity)

            Text("Now let go.")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)

            Text("Settle into the slump you usually catch yourself in, and hold it. The distance between tall and slumped becomes your personal range.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { finishWithDefaultSlouch() } label: { Text("Skip, use the standard range") }
                .buttonStyle(.daylight(.ghost))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Text("Posture reads alignment from the head-motion sensor in AirPods Pro (1st and 2nd gen), AirPods 3rd gen, AirPods 4 with ANC, or AirPods Max. Connect a supported pair to this iPhone and try again.")
                .font(.system(.body, design: .rounded))
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
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Text("Posture needs permission to read your AirPods' motion sensor. Turn on Motion and Fitness for Posture in Settings, then try again.")
                .font(.system(.body, design: .rounded))
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
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)

            Text(doneSubtitle)
                .font(.system(.body, design: .rounded))
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
        let base = "We've learned your aligned posture standing and sitting"
        let range = capturedSlouchDelta != nil ? ", and your slouch." : "."
        return base + range + " Every check-in is scored against your own range."
    }

    // MARK: - State machine

    private func begin() {
        // Take exclusive ownership of the head-motion stream — the shared
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

    /// Run the full standing → sitting → slouch capture sequence. Each aligned
    /// pose is retried if the hold was too shaky; a mid-sequence AirPods drop
    /// rewinds cleanly to the waiting screen so we never dead-end.
    private func startSequence() {
        guard phase == .waiting else { return }
        waitDeadlineTask?.cancel()
        permissionWatchTask?.cancel()
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")

        sequenceTask?.cancel()
        sequenceTask = Task {
            guard let standing = await captureAlignedPose(phase: .standing) else {
                rewindToWaiting(); return
            }
            standingCapture = standing
            guard let sitting = await captureAlignedPose(phase: .sitting) else {
                rewindToWaiting(); return
            }
            sittingCapture = sitting

            countdown = 3
            showSteadyRetry = false
            phase = .slouch
            await captureSlouch(uprightSitting: sitting.pitch)
        }
    }

    /// Capture one aligned pose, retrying up to `maxAlignedAttempts` times when
    /// the hold is shakier than the steadiness threshold. Returns nil only when
    /// AirPods drop or never deliver enough samples (caller rewinds).
    private func captureAlignedPose(phase target: Phase) async -> PoseCapture? {
        for attempt in 0..<maxAlignedAttempts {
            phase = target
            showSteadyRetry = attempt > 0

            for i in stride(from: settleSeconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return nil }
                guard airpods.isConnected else { return nil }
                countdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            var pitch: [Double] = []
            var yaw: [Double] = []
            var roll: [Double] = []
            // ~2s window at 10 Hz — enough to measure the spread of the hold.
            for _ in 0..<20 {
                guard !Task.isCancelled else { return nil }
                if let p = airpods.lastPitch { pitch.append(p) }
                if let y = airpods.lastYaw { yaw.append(y) }
                if let r = airpods.lastRoll { roll.append(r) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            guard pitch.count >= 10 else { return nil }

            let mean = pitch.reduce(0, +) / Double(pitch.count)
            let sd = PostureScoring.standardDeviation(pitch)
            let steady = sd <= PostureScoring.stableCaptureThreshold
            if steady || attempt == maxAlignedAttempts - 1 {
                return PoseCapture(
                    pitch: mean,
                    standardDeviation: sd,
                    yaw: yaw.isEmpty ? nil : yaw.reduce(0, +) / Double(yaw.count),
                    roll: roll.isEmpty ? nil : roll.reduce(0, +) / Double(roll.count)
                )
            }
            // Too shaky and attempts remain — loop and re-read this pose.
        }
        return nil
    }

    /// Second-stage slouch read. Any failure (drop, too few samples) falls back
    /// to the default range — both aligned reads are already in hand, so the
    /// user is never rewound from here.
    private func captureSlouch(uprightSitting: Double) async {
        for i in stride(from: 3, through: 1, by: -1) {
            guard !Task.isCancelled else { return }
            guard airpods.isConnected else { finishWithDefaultSlouch(); return }
            countdown = i
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        var pitch: [Double] = []
        for _ in 0..<10 {
            guard !Task.isCancelled else { return }
            if let p = airpods.lastPitch { pitch.append(p) }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard !Task.isCancelled else { return }
        guard pitch.count >= 5 else { finishWithDefaultSlouch(); return }

        let slouchPitch = pitch.reduce(0, +) / Double(pitch.count)
        capturedSlouchDelta = PostureScoring.calibratedSlouchDelta(
            uprightPitch: uprightSitting,
            slouchedPitch: slouchPitch
        )
        save()
        phase = .done
    }

    private func rewindToWaiting() {
        guard !Task.isCancelled else { return }
        phase = .waiting
        showSteadyRetry = false
        armWaiting()
    }

    private func finishWithDefaultSlouch() {
        sequenceTask?.cancel()
        capturedSlouchDelta = nil
        save()
        phase = .done
    }

    private func save() {
        guard let sitting = sittingCapture else { return }
        let standing = standingCapture
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

        let cal = Calibration(
            basePitch: 0,
            baseYaw: 0,
            baseRoll: 0,
            slouchPitchDelta: capturedSlouchDelta ?? .pi / 24,
            airpodsPitch: baseline,
            airpodsRoll: sitting.roll,
            airpodsYaw: sitting.yaw,
            airpodsStandingPitch: standing?.pitch,
            airpodsSittingPitch: sitting.pitch,
            baselineConfidence: confidence
        )
        CalibrationService(context: context).save(cal)
        // A real AirPods capture happened — clear any deferred/no-AirPods flags.
        settings.calibrationDeferred = false
        settings.hasAirpods = true
        AnalyticsService.calibrateCompleted()
        airpods.stop()
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
                .font(.system(.footnote, design: .rounded).weight(.semibold))
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
