import SwiftData
import SwiftUI

struct SessionView: View {
    let targetSeconds: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var face = FaceTrackingService()
    @State private var airpods = HeadphoneMotionService()
    @State private var engine: SessionEngine?
    @State private var activeSource: PostureSource = .camera
    @State private var cameraDenied: Bool = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if cameraDenied {
                cameraDeniedView
            } else if let engine {
                runningView(engine: engine)
            } else {
                ProgressView("Preparing…")
            }
        }
        .task { await prepare() }
        .onChange(of: engine?.state) { _, newState in
            if case .finished = newState {
                StreakService(context: context).recordSessionCompleted()
            }
        }
        .onDisappear {
            face.stop()
            airpods.stop()
            engine?.cancel()
        }
    }

    private func runningView(engine: SessionEngine) -> some View {
        VStack(spacing: 20) {
            HStack {
                Button("Cancel") {
                    engine.cancel()
                    dismiss()
                }
                .foregroundStyle(Theme.textSecondary)
                Spacer()
                sourceBadge
                Spacer()
                Text("\(remaining(engine: engine))s")
                    .font(Theme.bigNumber(20))
                    .monospacedDigit()
            }
            .padding(.horizontal)

            switch activeSource {
            case .camera:
                CameraPreview(session: face.session)
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 20))
                    .padding(.horizontal)
            case .airpods, .watch:
                airpodsHeroView(engine: engine)
            }

            PostureLiveIndicator(quality: engine.currentQuality)

            Spacer()

            switch engine.state {
            case .finished(let score):
                summaryCard(score: score)
            default:
                EmptyView()
            }
        }
        .padding(.vertical)
    }

    private var sourceBadge: some View {
        let (icon, label): (String, String) = switch activeSource {
        case .airpods: ("airpodspro", "AirPods")
        case .camera: ("camera.fill", "Camera")
        case .watch: ("applewatch", "Watch")
        }
        return HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.cardSurface, in: .capsule)
    }

    private func airpodsHeroView(engine: SessionEngine) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "airpodspro")
                .font(.system(size: 90, weight: .light))
                .foregroundStyle(Theme.qualityColor(engine.currentQuality))
                .padding(.top, 24)
            Text("Sit upright. Eyes forward.")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
        .padding(.horizontal)
    }

    private func summaryCard(score: Int) -> some View {
        VStack(spacing: 12) {
            PostureRing(score: score, size: 160)
            Text(scoreLabel(score))
                .font(.headline)
                .foregroundStyle(Theme.qualityColor(qualityForScore(score)))
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Theme.cardSurface, in: .rect(cornerRadius: Theme.cardRadius))
        .padding(.horizontal)
    }

    private func remaining(engine: SessionEngine) -> Int {
        max(0, targetSeconds - engine.elapsedSeconds)
    }

    private func qualityForScore(_ score: Int) -> PostureQuality {
        switch score {
        case 80...: return .good
        case 50..<80: return .borderline
        default: return .bad
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 90...: return "Outstanding"
        case 75..<90: return "Strong"
        case 50..<75: return "Keep practicing"
        default: return "Reset & try again"
        }
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("Camera access needed")
                .font(Theme.bigNumber(22))
            Text("Posture uses the front camera during sessions to measure head orientation. Grant permission in Settings → Privacy → Camera.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            Button {
                dismiss()
            } label: {
                Text("Go back")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func prepare() async {
        let calService = CalibrationService(context: context)
        guard let calibration = calService.current() else {
            dismiss()
            return
        }

        // Probe AirPods first — if connected and we have a baseline, prefer them.
        airpods.start()
        try? await Task.sleep(nanoseconds: 400_000_000)

        let useAirpods = airpods.isConnected && calibration.airpodsPitch != nil
        activeSource = useAirpods ? .airpods : .camera

        let engine = SessionEngine(context: context, calibration: calibration, source: activeSource, sensitivity: GoalSettings.shared.sensitivity)

        if useAirpods, let baseline = calibration.airpodsPitch {
            airpods.onSample = { pitch, _, _ in
                engine.ingestPitchDeviation(pitch - baseline)
            }
        } else {
            airpods.stop()
            face.onSample = { pitch, _, _ in
                engine.ingestPitchDeviation(pitch - calibration.basePitch)
            }
            await face.start()
            if !face.isRunning {
                // Camera access was denied — show error UI
                cameraDenied = true
                return
            }
        }

        engine.start(targetSeconds: targetSeconds)
        self.engine = engine
    }
}
