import SwiftData
import SwiftUI

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

    @State private var step: Step = .captureBaseline
    @State private var hasAirpods: Bool?
    @State private var face = FaceTrackingService()
    @State private var airpods = HeadphoneMotionService()
    @State private var capturedBasePitch: Double?
    @State private var capturedAirpodsBasePitch: Double?
    @State private var capturedAirpodsBaseYaw: Double?
    @State private var capturedAirpodsBaseRoll: Double?
    @State private var countdown: Int = 0
    @State private var capturing: Bool = false
    @State private var countdownTask: Task<Void, Never>?
    @State private var captureError: String?
    @State private var heroPulse: Bool = false

    enum Step { case captureBaseline, done }

    var body: some View {
        Group {
            switch step {
            case .captureBaseline:
                if hasAirpods == true { airpodsCaptureStep } else { captureStep }
            case .done: doneStep
            }
        }
        .dawnBackground()
        .task {
            // First-time calibration trusts the onboarding answer. Quick
            // recalibrate inherits the prior calibration's source. Either
            // way the question step is dead code — we just skip to capture.
            if mode == .quickRecalibrate {
                let last = CalibrationService(context: context).current()
                hasAirpods = (last?.airpodsPitch != nil)
            } else if hasAirpods == nil {
                hasAirpods = settings.hasAirpods ?? false
            }
            if step == .captureBaseline {
                if hasAirpods == true {
                    airpods.start()
                } else {
                    await face.start()
                }
            }
        }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
            airpods.stop()
        }
    }

    // MARK: - AirPods-only capture

    private var airpodsCaptureStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("calibration")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 24)

            Text("sit upright.")
                .font(.system(size: 40, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)

            Text("Pop your AirPods in, look straight ahead. Hold the shape for five seconds.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 12)

            Spacer(minLength: 8)

            calibrationHero
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

            Spacer(minLength: 8)

            if let captureError {
                Text(captureError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.clay)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
            }

            Button {
                guard airpods.isConnected else { return }
                runAirpodsCountdown()
            } label: { Text(capturing ? "hold still…" : "calibrate") }
                .buttonStyle(.plain)
                .daylightCTA(airpods.isConnected && !capturing ? .primary : .secondary)
                .disabled(capturing || !airpods.isConnected)
                .opacity(airpods.isConnected ? 1.0 : 0.55)

            if !airpods.isConnected && !capturing {
                Button { switchToCamera() } label: { Text("use iPhone camera instead") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    /// Escape hatch from the AirPods waiting state: drop to the camera path
    /// without forcing an app restart, and remember the choice.
    private func switchToCamera() {
        countdownTask?.cancel()
        airpods.stop()
        captureError = nil
        settings.hasAirpods = false
        hasAirpods = false
        Task { await face.start() }
    }

    /// Large central status circle. Three states: waiting (sand pulse),
    /// linked (sage steady), capturing (sage with countdown numeral).
    private var calibrationHero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(heroTintWash)
                    .frame(width: 200, height: 200)
                    .scaleEffect(heroPulse ? 1.06 : 0.96)
                    .opacity(heroPulse ? 0.55 : 1.0)
                Circle()
                    .fill(heroTintWash)
                    .frame(width: 150, height: 150)
                if capturing {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeOut(duration: 0.2), value: countdown)
                } else {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(heroAccent)
                }
            }
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: heroPulse)
            .onAppear { heroPulse = true }

            HStack(spacing: 8) {
                Circle().fill(heroAccent).frame(width: 7, height: 7)
                Text(heroCaption)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(heroAccent)
            }
        }
    }

    private var heroAccent: Color {
        if !airpods.isConnected { return Theme.sand }
        return Theme.sage
    }

    private var heroTintWash: Color {
        if !airpods.isConnected { return Theme.sandTint }
        return Theme.sageTint
    }

    private var heroCaption: String {
        if capturing { return "reading…" }
        return airpods.isConnected ? "AirPods linked" : "waiting for AirPods"
    }

    // MARK: - Camera capture (fallback)

    private var captureStep: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: face.session).ignoresSafeArea()

            GeometryReader { geo in
                Ellipse()
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: geo.size.width * 0.56, height: geo.size.width * 0.56 / 0.72)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            }
            .ignoresSafeArea()

            VStack {
                Text("sit upright")
                    .font(Theme.displaySerif(28))
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                Text(hasAirpods == true
                     ? "AirPods in, phone at eye level, look straight ahead. Hold still while we set your baseline."
                     : "Phone at eye level, look straight ahead. Hold still while we set your baseline.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if capturing {
                    Spacer()
                    Text("\(countdown)")
                        .font(Theme.displaySerif(72))
                        .foregroundStyle(.white.opacity(0.95))
                }

                Spacer()

                if let captureError {
                    Text(captureError)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 6)
                } else if !face.faceDetected && !capturing {
                    Text("align your face inside the guide to begin.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 6)
                }

                Button {
                    guard face.faceDetected else { return }
                    runCountdown()
                } label: {
                    Text(capturing ? "hold still…" : "capture")
                }
                .buttonStyle(.plain)
                .daylightCTA(face.faceDetected && !capturing ? .primary : .secondary)
                .disabled(capturing || !face.faceDetected)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Done

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

            Text("all set.")
                .font(.system(size: 40, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)

            Text("We've learned your aligned posture. From here on, every check-in is just three quiet seconds.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer()

            Button {
                if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
            } label: {
                Text(mode == .quickRecalibrate ? "done" : "let's go")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Capture logic

    private func runAirpodsCountdown() {
        capturing = true
        captureError = nil
        countdown = 5
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")
        countdownTask?.cancel()
        countdownTask = Task {
            defer { capturing = false; countdown = 0 }
            for i in stride(from: 5, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                guard airpods.isConnected else {
                    captureError = "Lost the AirPods — put them back in and try again."
                    return
                }
                countdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }

            var pitches: [Double] = []
            var yaws: [Double] = []
            var rolls: [Double] = []
            for _ in 0..<10 {
                if let p = airpods.lastPitch { pitches.append(p) }
                if let y = airpods.lastYaw { yaws.append(y) }
                if let r = airpods.lastRoll { rolls.append(r) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            guard pitches.count >= 5 else {
                captureError = "Couldn't get a steady read — try again."
                return
            }

            capturedAirpodsBasePitch = pitches.reduce(0, +) / Double(pitches.count)
            capturedAirpodsBaseYaw = yaws.isEmpty ? nil : yaws.reduce(0, +) / Double(yaws.count)
            capturedAirpodsBaseRoll = rolls.isEmpty ? nil : rolls.reduce(0, +) / Double(rolls.count)
            // basePitch (camera frame) stays 0 — we never opened the camera.
            capturedBasePitch = 0
            guard !Task.isCancelled else { return }
            save()
            step = .done
        }
    }

    private func runCountdown() {
        capturing = true
        captureError = nil
        countdown = 5
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")
        countdownTask?.cancel()
        countdownTask = Task {
            defer { capturing = false; countdown = 0 }
            for i in stride(from: 5, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                // P1-5: abort if the face leaves the frame mid-countdown.
                guard face.faceDetected else {
                    captureError = "Lost your face — let's try that again."
                    return
                }
                countdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }

            var faceSamples: [Double] = []
            var airpodsPitch: [Double] = []
            var airpodsYaw: [Double] = []
            var airpodsRoll: [Double] = []
            for _ in 0..<10 {
                if face.faceDetected, let p = face.lastPitch { faceSamples.append(p) }
                if let p = airpods.lastPitch { airpodsPitch.append(p) }
                if let y = airpods.lastYaw { airpodsYaw.append(y) }
                if let r = airpods.lastRoll { airpodsRoll.append(r) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            // P1-5: require enough valid samples — never persist a 0 baseline.
            guard faceSamples.count >= 5 else {
                captureError = "Couldn't get a steady read — try again."
                return
            }

            let faceAvg = faceSamples.reduce(0, +) / Double(faceSamples.count)
            if hasAirpods == true, !airpodsPitch.isEmpty {
                capturedAirpodsBasePitch = airpodsPitch.reduce(0, +) / Double(airpodsPitch.count)
                capturedAirpodsBaseYaw = airpodsYaw.isEmpty ? nil : airpodsYaw.reduce(0, +) / Double(airpodsYaw.count)
                capturedAirpodsBaseRoll = airpodsRoll.isEmpty ? nil : airpodsRoll.reduce(0, +) / Double(airpodsRoll.count)
            }
            guard !Task.isCancelled else { return }
            capturedBasePitch = faceAvg
            save()
            step = .done
        }
    }

    private func save() {
        guard let base = capturedBasePitch else { return }
        let cal = Calibration(
            basePitch: base,
            baseYaw: face.lastYaw ?? 0,
            baseRoll: face.lastRoll ?? 0,
            slouchPitchDelta: .pi / 24,
            airpodsPitch: capturedAirpodsBasePitch,
            airpodsRoll: capturedAirpodsBaseRoll,
            airpodsYaw: capturedAirpodsBaseYaw
        )
        CalibrationService(context: context).save(cal)
        AnalyticsService.calibrateCompleted()
        face.stop()
        airpods.stop()
    }
}
