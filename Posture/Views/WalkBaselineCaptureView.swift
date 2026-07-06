import SwiftData
import SwiftUI

/// A one-time, deliberate setup captured the first time a user starts a walk:
/// they walk tall for ~30 seconds while we record their own good-posture
/// walking head pitch, then we save it to `Calibration.airpodsWalkingPitch`
/// and reuse it for every future walk. Capturing good posture on purpose beats
/// normalizing to the first 30 seconds of each walk, which risked baking a
/// slouched walk in as the baseline.
///
/// Self-contained: owns its own head-motion stream and the "are you actually
/// walking" gate, so only walking samples count toward the baseline.
struct WalkBaselineCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Called once the baseline is saved; the caller then starts the real walk.
    let onCaptured: () -> Void

    private enum Stage: Equatable {
        case intro
        case capturing
        case noAirpods
        case done
    }

    @State private var stage: Stage = .intro
    @State private var walkingSeconds: Double = 0
    @State private var isWalkingNow = true

    @State private var airpods = HeadphoneMotionService()
    @State private var metrics: WalkMetricsService?
    @State private var smoothedPitch: Double?
    @State private var samples: [Double] = []
    @State private var captureTask: Task<Void, Never>?

    /// Seconds of *walking* we need before the baseline is trustworthy.
    private let targetSeconds: Double = 30
    private let tick: Double = 0.2

    private var progress: Double { min(1, walkingSeconds / targetSeconds) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { finishCancel() } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(.body, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.top, 16)

            Spacer(minLength: 0)

            switch stage {
            case .intro: introView
            case .capturing: capturingView
            case .noAirpods: noAirpodsView
            case .done: doneView
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
        .interactiveDismissDisabled(stage == .capturing)
        .onDisappear { teardown() }
    }

    // MARK: - Stages

    private var introView: some View {
        VStack(alignment: .leading, spacing: 0) {
            PoseDiagram(pose: .stack, height: 150)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)

            Text("Set your walking posture.")
                .font(Theme.display(32))
                .foregroundStyle(Theme.ink)

            Text("Just once. Pop your AirPods in, then walk tall for about half a minute so Posture learns the head position of your best walking posture. We reuse it for every walk after this, so scoring is honest from your very first step.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 14)

            Button { beginCapture() } label: {
                Text("I'm ready to walk").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.top, 28)
        }
    }

    private var capturingView: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().stroke(Theme.ringTrack, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isWalkingNow ? Theme.sage : Theme.ink3,
                            style: .init(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)
                VStack(spacing: 4) {
                    Text("\(Int(max(0, targetSeconds - walkingSeconds)))")
                        .font(Theme.font(size: 52, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text("seconds")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }
            .frame(width: 240, height: 240)

            Text(isWalkingNow ? "Walk tall, eyes on the horizon." : "Keep walking, we pause when you stop.")
                .font(Theme.font(.body))
                .foregroundStyle(isWalkingNow ? Theme.ink2 : Theme.ink3)
                .multilineTextAlignment(.center)
                .padding(.top, 26)
                .padding(.horizontal, 12)
        }
    }

    private var noAirpodsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "airpodspro")
                .font(.system(size: 40))
                .foregroundStyle(Theme.ink3)
            Text("Pop your AirPods in")
                .font(Theme.display(24))
                .foregroundStyle(Theme.ink)
            Text(HeadphoneMotionService.isMotionAccessDenied
                 ? "Motion access is off. Turn it on in Settings to capture your walking posture."
                 : "Compatible AirPods (Pro, 3rd-gen, or Max) are needed to read your head position.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
            Button { stage = .intro } label: {
                Text("Try again").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.top, 8)
        }
    }

    private var doneView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.sage)
            Text("Walking posture saved.")
                .font(Theme.display(26))
                .foregroundStyle(Theme.ink)
            Text("You're set. This walk (and every walk after) is scored against your own tall stride.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Capture

    private func beginCapture() {
        guard airpods.isAvailable, !HeadphoneMotionService.isMotionAccessDenied else {
            stage = .noAirpods
            return
        }
        stage = .capturing
        walkingSeconds = 0
        samples = []
        smoothedPitch = nil

        // Exclusive head-motion stream for the capture, like the scan/session.
        AirpodsBackgroundMonitor.shared.suspendForForegroundRead()
        airpods.start()
        let m = WalkMetricsService()
        m.start(useGPS: false)
        metrics = m

        captureTask?.cancel()
        captureTask = Task { await captureLoop() }
    }

    private func captureLoop() async {
        // Give the stream a moment to hand off, then poll at ~5 Hz. Only accrue
        // (and sample) while the pedometer says we're actually walking.
        var sawAnySample = false
        var noSampleTicks = 0
        while !Task.isCancelled, walkingSeconds < targetSeconds {
            metrics?.tick()
            let walking = metrics?.isWalking ?? true
            if isWalkingNow != walking { isWalkingNow = walking }

            if let pitch = airpods.lastPitch {
                sawAnySample = true
                smoothedPitch = PostureScoring.smoothed(previous: smoothedPitch, sample: pitch, alpha: 0.15)
                if walking, let sp = smoothedPitch {
                    samples.append(sp)
                    walkingSeconds += tick
                }
            } else if !sawAnySample {
                noSampleTicks += 1
                // ~4s with no reading at all ⇒ AirPods never came online.
                if noSampleTicks >= 20 {
                    stage = .noAirpods
                    teardown()
                    return
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        finishCapture()
    }

    private func finishCapture() {
        guard let baseline = PostureScoring.median(samples) else {
            stage = .noAirpods
            teardown()
            return
        }
        CalibrationService(context: context).setWalkingBaseline(baseline)
        teardown()
        stage = .done
        // Brief beat on the confirmation, then hand back to start the walk.
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onCaptured()
        }
    }

    private func finishCancel() {
        teardown()
        dismiss()
    }

    private func teardown() {
        captureTask?.cancel()
        captureTask = nil
        airpods.stop()
        metrics?.stop()
        metrics = nil
        AirpodsBackgroundMonitor.shared.resumeAfterForegroundRead()
    }
}
