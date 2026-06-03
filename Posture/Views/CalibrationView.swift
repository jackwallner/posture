import SwiftData
import SwiftUI

/// AirPods-only calibration. We start the headphone motion service and
/// drive a small state machine: waiting (no AirPods yet) → capture (3s
/// stable samples) → done. If after a generous timeout no motion ever
/// arrives, we surface the "compatible AirPods required" gate.
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
    @State private var capturedPitch: Double?
    @State private var capturedYaw: Double?
    @State private var capturedRoll: Double?
    @State private var captureTask: Task<Void, Never>?
    @State private var waitDeadlineTask: Task<Void, Never>?
    @State private var permissionWatchTask: Task<Void, Never>?

    enum Phase {
        case waiting          // AirPods not yet sending samples
        case capturing        // got first sample, running countdown
        case unsupported      // gave up — show the gate
        case permissionDenied // motion access is off, not missing hardware
        case done             // saved
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
            case .capturing: capturingStep
            case .unsupported: unsupportedStep
            case .permissionDenied: permissionDeniedStep
            case .done: doneStep
            }
        }
        .dawnBackground()
        .task { begin() }
        .onChange(of: airpods.isConnected) { _, connected in
            if connected, phase == .waiting {
                startCapture()
            }
        }
        .onDisappear {
            captureTask?.cancel()
            waitDeadlineTask?.cancel()
            permissionWatchTask?.cancel()
            airpods.stop()
        }
    }

    // MARK: - States

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

            Text("We use the head-motion sensor in your AirPods to read posture. Make sure they're connected to this iPhone — iOS will ask permission to read motion.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            // M5: never leave the user stranded on a static screen. After a
            // few seconds, offer a way into the app without AirPods. The
            // manual "check in by hand" loop works without calibration.
            if showSkipHint && mode == .onboarding {
                Button { skipWithoutAirpods() } label: { Text("Continue without AirPods") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
            }

            if mode == .quickRecalibrate {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var capturingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 200, height: 200)
                Text("\(countdown)")
                    .font(Theme.displaySerif(96))
                    .foregroundStyle(Theme.sage)
                    .contentTransition(.numericText())
                    .animation(.default, value: countdown)
            }
            .frame(maxWidth: .infinity)

            Text("Sit upright.")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 24)

            Text("Look straight ahead and hold still. We're learning your aligned posture.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()
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

            Text("Posture reads alignment from the head-motion sensor in AirPods Pro (1st & 2nd gen), AirPods 3rd gen, AirPods 4 with ANC, or AirPods Max. Connect a supported pair to this iPhone and try again.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { retry() } label: { Text("Try Again") }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

            // B1: an escape so a user/reviewer without compatible AirPods is
            // never dead-ended at the gate. Drops them into the app on a
            // neutral baseline; the manual check-in loop works without AirPods.
            if mode == .onboarding {
                Button { skipWithoutAirpods() } label: { Text("Continue without AirPods") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
            } else {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
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

            Text("Posture needs permission to read your AirPods' motion sensor. Turn on Motion & Fitness for Posture in Settings, then try again.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button { openSettings() } label: { Text("Open Settings") }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

            if mode == .onboarding {
                Button { skipWithoutAirpods() } label: { Text("Continue without AirPods") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
            } else {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
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

            Text("We've learned your aligned posture. From here on, every check-in is just three quiet seconds.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer()

            Button {
                if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
            } label: {
                Text(mode == .quickRecalibrate ? "Done" : "Let's go")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - State machine

    private func begin() {
        airpods.start()
        // If AirPods are already in, the first sample arrives within a
        // tick and onChange flips us to capture. If not, give the user a
        // generous window to physically put them in before showing the
        // unsupported gate.
        if airpods.isConnected {
            startCapture()
            return
        }
        armWaiting()
    }

    /// Start (or restart) the no-AirPods countdowns: a short timer that reveals
    /// the "Continue without AirPods" escape, and the longer deadline that
    /// surfaces the unsupported gate. A parallel watcher catches a denied
    /// motion permission so we show the right message (not "need AirPods").
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
            // Poll briefly so a "Don't Allow" tap surfaces the permission
            // state quickly rather than after the full connect deadline.
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
            startCapture()
            return
        }
        armWaiting()
    }

    /// B1: leave the AirPods gate without being trapped. Save a neutral
    /// baseline (scans fall back to a 0 baseline) and flag setup as deferred so
    /// Today can nudge the user to finish calibrating once AirPods are around.
    private func skipWithoutAirpods() {
        captureTask?.cancel()
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
        settings.calibrationDeferred = true
        if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func startCapture() {
        waitDeadlineTask?.cancel()
        permissionWatchTask?.cancel()
        phase = .capturing
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")

        captureTask?.cancel()
        captureTask = Task {
            // 5-second countdown so the user can settle into an aligned
            // posture before the read.
            for i in stride(from: 5, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                guard airpods.isConnected else {
                    // AirPods popped out mid-countdown — rewind to waiting.
                    phase = .waiting
                    return
                }
                countdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            // Sample 10 readings over ~1 second and average them.
            var pitch: [Double] = []
            var yaw: [Double] = []
            var roll: [Double] = []
            for _ in 0..<10 {
                guard !Task.isCancelled else { return }
                if let p = airpods.lastPitch { pitch.append(p) }
                if let y = airpods.lastYaw { yaw.append(y) }
                if let r = airpods.lastRoll { roll.append(r) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            guard pitch.count >= 5 else {
                phase = .waiting
                return
            }

            capturedPitch = pitch.reduce(0, +) / Double(pitch.count)
            capturedYaw = yaw.isEmpty ? nil : yaw.reduce(0, +) / Double(yaw.count)
            capturedRoll = roll.isEmpty ? nil : roll.reduce(0, +) / Double(roll.count)

            save()
            phase = .done
        }
    }

    private func save() {
        guard let pitch = capturedPitch else { return }
        // Camera baseline (`basePitch`) stays at 0 — the legacy camera
        // scan path is gone, so nothing reads it. AirPods pitch/yaw/roll
        // are the live baseline.
        let cal = Calibration(
            basePitch: 0,
            baseYaw: 0,
            baseRoll: 0,
            slouchPitchDelta: .pi / 24,
            airpodsPitch: pitch,
            airpodsRoll: capturedRoll,
            airpodsYaw: capturedYaw
        )
        CalibrationService(context: context).save(cal)
        // A real AirPods capture happened — clear any deferred-setup flag so
        // Today stops nudging the user to finish calibration.
        settings.calibrationDeferred = false
        AnalyticsService.calibrateCompleted()
        airpods.stop()
    }
}
