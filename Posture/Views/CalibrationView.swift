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
    @State private var capturedPitch: Double?
    @State private var capturedYaw: Double?
    @State private var capturedRoll: Double?
    @State private var captureTask: Task<Void, Never>?
    @State private var waitDeadlineTask: Task<Void, Never>?

    enum Phase {
        case waiting          // AirPods not yet sending samples
        case capturing        // got first sample, running countdown
        case unsupported      // gave up — show the gate
        case done             // saved
    }

    /// Generous: lets a user pop AirPods in after launching the app.
    private let connectDeadlineSeconds: Double = 30

    var body: some View {
        Group {
            switch phase {
            case .waiting: waitingStep
            case .capturing: capturingStep
            case .unsupported: unsupportedStep
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

            Text("We use the head-motion sensor in your AirPods to read posture. Make sure they're connected to this iPhone.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

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
        waitDeadlineTask?.cancel()
        waitDeadlineTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(connectDeadlineSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if phase == .waiting { phase = .unsupported }
        }
    }

    private func retry() {
        phase = .waiting
        airpods.stop()
        airpods.start()
        waitDeadlineTask?.cancel()
        waitDeadlineTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(connectDeadlineSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if phase == .waiting { phase = .unsupported }
        }
    }

    private func startCapture() {
        waitDeadlineTask?.cancel()
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
        AnalyticsService.calibrateCompleted()
        airpods.stop()
    }
}
