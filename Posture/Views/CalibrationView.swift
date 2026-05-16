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

    @State private var step: Step = .airpodsQuestion
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

    enum Step { case airpodsQuestion, captureBaseline, done }

    var body: some View {
        Group {
            switch step {
            case .airpodsQuestion: airpodsQuestionStep
            case .captureBaseline: captureStep
            case .done: doneStep
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .task {
            if mode == .quickRecalibrate, step == .airpodsQuestion {
                step = .captureBaseline
            }
            if step == .captureBaseline { await face.start() }
            // P1-13: only spin up AirPods motion when the user has them.
            if hasAirpods == true { airpods.start() }
        }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
            airpods.stop()
        }
    }

    // MARK: - AirPods question

    private var airpodsQuestionStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CALIBRATION")
                .font(.caption.weight(.semibold)).tracking(2)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 16)

            Spacer()

            Text("do you have\nairpods?")
                .font(Theme.displaySerif(40))
                .foregroundStyle(Theme.ink)

            Text("If yes, we'll use their motion sensor to catch slouches without staring at the camera.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 14)

            Spacer()

            Button {
                hasAirpods = false
                step = .captureBaseline
                Task { await face.start() }
            } label: { Text("no — use my camera") }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

            Button {
                hasAirpods = true
                step = .captureBaseline
                airpods.start()
                Task { await face.start() }
            } label: { Text("yes — link them") }
                .buttonStyle(.plain)
                .daylightCTA(.secondary)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Capture

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
                     ? "AirPods in, phone at eye level, look straight ahead."
                     : "Phone at eye level, look straight ahead.")
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
                    Text("we'll enable this once we can see your face.")
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
            Text("calibrated.")
                .font(Theme.displaySerif(40))
                .foregroundStyle(Theme.ink)
            Text(hasAirpods == true
                 ? "We track your AirPods head motion for hands-free check-ins. The camera stays as a backup."
                 : "We use your front camera during quick scans to read head orientation. Prop the phone at eye level for the best read.")
                .font(.body)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 14)
            HorizonMeter(quality: .good)
                .frame(height: 44)
                .padding(.vertical, 24)
            Spacer()
            Button {
                if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
            } label: {
                Text(mode == .quickRecalibrate ? "done" : "start using posture")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Capture logic

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
