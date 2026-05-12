import SwiftData
import SwiftUI

struct CalibrationView: View {
    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var step: Step = .intro
    @State private var face = FaceTrackingService()
    @State private var airpods = HeadphoneMotionService()
    @State private var capturedBasePitch: Double?
    @State private var capturedSlouchPitch: Double?
    @State private var capturedAirpodsBasePitch: Double?
    @State private var capturedAirpodsBaseYaw: Double?
    @State private var capturedAirpodsBaseRoll: Double?
    @State private var countdown: Int = 0
    @State private var capturing: Bool = false
    @State private var countdownTask: Task<Void, Never>?

    enum Step {
        case intro, captureBaseline, captureSlouch, done
    }

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case .intro:
                introStep
            case .captureBaseline:
                captureStep(
                    title: "Sit upright",
                    body: "Phone at eye level, look straight ahead. We'll capture in 5 seconds.",
                    accent: Theme.good
                ) { pitch in
                    capturedBasePitch = pitch
                    step = .captureSlouch
                }
            case .captureSlouch:
                captureStep(
                    title: "Now slouch",
                    body: "Drop your head and shoulders the way you do when scrolling.",
                    accent: Theme.bad
                ) { pitch in
                    capturedSlouchPitch = pitch
                    save()
                    step = .done
                }
            case .done:
                doneStep
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            if step != .intro { await face.start() }
            airpods.start()
        }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
            airpods.stop()
        }
    }

    private var introStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brandGradient)
            Text("Calibrate your posture")
                .font(Theme.bigNumber(28))
            Text("Two quick captures: one upright, one slouched. Prop your phone up roughly at eye level.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                step = .captureBaseline
                Task { await face.start() }
            } label: {
                Text("Begin")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func captureStep(
        title: String,
        body: String,
        accent: Color,
        onCapture: @escaping (Double) -> Void
    ) -> some View {
        VStack(spacing: 20) {
            Text(title).font(Theme.bigNumber(28)).foregroundStyle(accent)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            CameraPreview(session: face.session)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20).stroke(accent, lineWidth: 3)
                }
                .padding(.horizontal, 32)

            HStack(spacing: 8) {
                Image(systemName: face.faceDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(face.faceDetected ? Theme.good : Theme.bad)
                Text(face.faceDetected ? "Face detected" : "Position your face in frame")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            if airpods.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "airpodspro")
                        .foregroundStyle(Theme.brandPrimary)
                    Text("AirPods baseline being captured too")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if capturing {
                Text("\(countdown)")
                    .font(Theme.bigNumber(64))
                    .foregroundStyle(accent)
            }

            Spacer()

            Button {
                guard face.faceDetected else { return }
                runCountdown(onCapture: onCapture)
            } label: {
                Text(capturing ? "Hold still…" : "Capture")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accent, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(capturing || !face.faceDetected)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.good)
            Text("You're calibrated")
                .font(Theme.bigNumber(28))
            Text("Posture knows what your good and slouched poses look like.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                settings.hasCalibrated = true
            } label: {
                Text("Start using Posture")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func runCountdown(onCapture: @escaping (Double) -> Void) {
        capturing = true
        countdown = 5
        countdownTask?.cancel()
        countdownTask = Task {
            defer {
                capturing = false
                countdown = 0
            }
            for i in stride(from: 5, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                countdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }
            // Average pitch over a 1-second sample
            var faceSamples: [Double] = []
            var airpodsPitch: [Double] = []
            var airpodsYaw: [Double] = []
            var airpodsRoll: [Double] = []
            for _ in 0..<10 {
                if let p = face.lastPitch { faceSamples.append(p) }
                if let p = airpods.lastPitch { airpodsPitch.append(p) }
                if let y = airpods.lastYaw { airpodsYaw.append(y) }
                if let r = airpods.lastRoll { airpodsRoll.append(r) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            let faceAvg = faceSamples.isEmpty ? 0 : faceSamples.reduce(0, +) / Double(faceSamples.count)
            // Only persist AirPods baseline on the first capture step (the upright one)
            if step == .captureBaseline, !airpodsPitch.isEmpty {
                capturedAirpodsBasePitch = airpodsPitch.reduce(0, +) / Double(airpodsPitch.count)
                capturedAirpodsBaseYaw = airpodsYaw.isEmpty ? nil : airpodsYaw.reduce(0, +) / Double(airpodsYaw.count)
                capturedAirpodsBaseRoll = airpodsRoll.isEmpty ? nil : airpodsRoll.reduce(0, +) / Double(airpodsRoll.count)
            }
            guard !Task.isCancelled else { return }
            capturing = false
            countdown = 0
            guard !Task.isCancelled else { return }
            onCapture(faceAvg)
        }
    }

    private func save() {
        guard let base = capturedBasePitch, let slouch = capturedSlouchPitch else { return }
        let delta = abs(slouch - base)
        let cal = Calibration(
            basePitch: base,
            baseYaw: face.lastYaw ?? 0,
            baseRoll: face.lastRoll ?? 0,
            slouchPitchDelta: max(delta, .pi / 24),  // 7.5° floor
            airpodsPitch: capturedAirpodsBasePitch,
            airpodsRoll: capturedAirpodsBaseRoll,
            airpodsYaw: capturedAirpodsBaseYaw
        )
        CalibrationService(context: context).save(cal)
        face.stop()
        airpods.stop()
    }
}
