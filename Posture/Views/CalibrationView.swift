import SwiftData
import SwiftUI

struct CalibrationView: View {
    enum Mode {
        /// Full onboarding flow — starts with AirPods question.
        case onboarding
        /// Quick recalibrate — skips AirPods question, goes straight to capture.
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

    enum Step {
        case airpodsQuestion, captureBaseline, done
    }

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case .airpodsQuestion:
                airpodsQuestionStep
            case .captureBaseline:
                captureStep
            case .done:
                doneStep
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            if mode == .quickRecalibrate, step == .airpodsQuestion {
                step = .captureBaseline
            }
            if step == .captureBaseline { await face.start() }
            airpods.start()
        }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
            airpods.stop()
        }
    }

    private var airpodsQuestionStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "airpodspro")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(Theme.brandGradient)
            Text("Do you have AirPods?")
                .font(Theme.bigNumber(28))
            Text("Posture works best hands-free with AirPods Pro, AirPods (3rd gen), or AirPods Max.\n\nWithout AirPods, we'll use your iPhone camera to track your posture.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    hasAirpods = true
                    step = .captureBaseline
                    Task { await face.start() }
                } label: {
                    HStack {
                        Image(systemName: "airpodspro")
                        Text("Yes, I have AirPods")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
                }

                Button {
                    hasAirpods = false
                    step = .captureBaseline
                    Task { await face.start() }
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("No, use my camera")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.cardSurface, in: .rect(cornerRadius: 14))
                    .foregroundStyle(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private var captureStep: some View {
        let title = "Sit upright"
        let bodyText: String
        if hasAirpods == true {
            bodyText = "Pop in your AirPods, phone at eye level, and look straight ahead. We'll capture your baseline posture in 5 seconds."
        } else {
            bodyText = "Phone at eye level, look straight ahead. We'll capture your baseline posture in 5 seconds."
        }

        return VStack(spacing: 20) {
            Text(title).font(Theme.bigNumber(28)).foregroundStyle(Theme.brandPrimary)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            CameraPreview(session: face.session)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20).stroke(Theme.brandPrimary, lineWidth: 3)
                }
                .padding(.horizontal, 32)

            if hasAirpods == true {
                if airpods.isConnected {
                    HStack(spacing: 6) {
                        Image(systemName: "airpodspro")
                            .foregroundStyle(Theme.good)
                        Text("AirPods connected — capturing baseline")
                            .font(.caption)
                            .foregroundStyle(Theme.good)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.good.opacity(0.1), in: .rect(cornerRadius: 8))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "airpodspro")
                            .foregroundStyle(Theme.textSecondary)
                        Text("AirPods not connected — pop them in for hands-free tracking")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.textSecondary.opacity(0.1), in: .rect(cornerRadius: 8))
                }
            }

            if capturing {
                Text("\(countdown)")
                    .font(Theme.bigNumber(64))
                    .foregroundStyle(Theme.brandPrimary)
                Text("Hold still to set your baseline posture…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                guard face.faceDetected else { return }
                runCountdown()
            } label: {
                Text(capturing ? "Hold still…" : "Capture")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(face.faceDetected ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.textTertiary), in: .rect(cornerRadius: 14))
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
            if hasAirpods == true {
                Text("Posture tracks your AirPods head motion for hands-free sessions. Your phone camera stays as a backup when AirPods are off.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Posture uses your front camera during daily sessions to measure head orientation. For best results, prop your phone up at eye level.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Button {
                if mode == .quickRecalibrate {
                    dismiss()
                } else {
                    settings.hasCalibrated = true
                }
            } label: {
                Text(mode == .quickRecalibrate ? "Done" : "Start using Posture")
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

    private func runCountdown() {
        capturing = true
        countdown = 5
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")
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
            // Persist AirPods baseline if connected
            if hasAirpods == true, !airpodsPitch.isEmpty {
                capturedAirpodsBasePitch = airpodsPitch.reduce(0, +) / Double(airpodsPitch.count)
                capturedAirpodsBaseYaw = airpodsYaw.isEmpty ? nil : airpodsYaw.reduce(0, +) / Double(airpodsYaw.count)
                capturedAirpodsBaseRoll = airpodsRoll.isEmpty ? nil : airpodsRoll.reduce(0, +) / Double(airpodsRoll.count)
            }
            guard !Task.isCancelled else { return }
            capturing = false
            countdown = 0
            capturedBasePitch = faceAvg
            guard !Task.isCancelled else { return }
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
            slouchPitchDelta: .pi / 24,  // Default 7.5° minimum threshold
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
