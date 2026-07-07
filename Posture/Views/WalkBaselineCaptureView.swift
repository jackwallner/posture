import SwiftData
import SwiftUI

/// A one-time, deliberate setup captured the first time a user starts a walk
/// (redoable from Settings or the walk screen): they walk tall for ~30 seconds
/// while we record their own good-posture walking head pitch, then we save it
/// to `Calibration.airpodsWalkingPitch` and reuse it for every future walk.
/// Capturing good posture on purpose beats normalizing to the first 30 seconds
/// of each walk, which risked baking a slouched walk in as the baseline.
///
/// The flow is deliberately unhurried: an intro that explains what's about to
/// happen, a get-moving lead-in so the capture never starts before the user
/// does, and a confirmation the user leaves by choice - nothing auto-starts.
///
/// Self-contained: owns its own head-motion stream and the "are you actually
/// walking" gate, so only walking samples count toward the baseline.
struct WalkBaselineCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Label for the done-screen button. The walk flow starts the real walk
    /// ("Start my walk"); the Settings recalibrate path just closes ("Done").
    var doneButtonTitle: String = "Start my walk"

    /// Called when the user taps the done-screen button; the walk flow then
    /// starts the real walk, the recalibrate flow simply dismisses.
    let onCaptured: () -> Void

    private enum Stage: Equatable {
        case intro
        /// Brief countdown after "Start walking" so the user is moving
        /// before any samples count.
        case getMoving
        case capturing
        case noAirpods
        case done
    }

    @State private var stage: Stage = .intro
    @State private var leadInSeconds: Double = 0
    @State private var walkingSeconds: Double = 0
    @State private var isWalkingNow = true

    @State private var airpods = HeadphoneMotionService()
    @State private var metrics: WalkMetricsService?
    @State private var smoothedPitch: Double?
    @State private var samples: [Double] = []
    @State private var captureTask: Task<Void, Never>?

    /// Seconds of *walking* we need before the baseline is trustworthy.
    private let targetSeconds: Double = 30
    /// The get-moving lead-in before samples start counting.
    private let leadInTarget: Double = 5
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
            case .getMoving: getMovingView
            case .capturing: capturingView
            case .noAirpods: noAirpodsView
            case .done: doneView
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
        .interactiveDismissDisabled(stage == .getMoving || stage == .capturing)
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

            Text("A one-time setup, about half a minute. Pop your AirPods in and walk tall - head level, eyes on the horizon - while Posture learns your best walking posture. Every walk after this is scored against it.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 14)

            Text("You can redo this anytime from Settings.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink3)
                .padding(.top, 10)

            Button { beginLeadIn() } label: {
                Text("Start walking").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.top, 28)
        }
    }

    private var getMovingView: some View {
        VStack(spacing: 14) {
            Text("\(Int(max(1, (leadInTarget - leadInSeconds).rounded(.up))))")
                .font(Theme.font(size: 64, weight: .regular))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(countsDown: true))
                .monospacedDigit()
            Text("Start walking now.")
                .font(Theme.display(24))
                .foregroundStyle(Theme.ink)
            Text("Get moving and stand tall. The 30-second capture begins when the count ends.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
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

            Text(isWalkingNow ? "Walk tall, eyes on the horizon." : "Keep walking, the count holds while you're stopped.")
                .font(Theme.font(.body))
                .foregroundStyle(isWalkingNow ? Theme.ink2 : Theme.badText)
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
                .foregroundStyle(Theme.goodText)
            Text("Walking posture saved.")
                .font(Theme.display(26))
                .foregroundStyle(Theme.ink)
            Text("Every walk is now scored against your own tall stride. Redo this anytime from Settings.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
            Button { onCaptured() } label: {
                Text(doneButtonTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.top, 10)
        }
    }

    // MARK: - Capture

    private func beginLeadIn() {
        guard airpods.isAvailable, !HeadphoneMotionService.isMotionAccessDenied else {
            stage = .noAirpods
            return
        }
        stage = .getMoving
        leadInSeconds = 0
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
        captureTask = Task { await leadInThenCapture() }
    }

    private func leadInThenCapture() async {
        // Get-moving countdown: the user starts walking while the stream and
        // pedometer spin up, so second 1 of the capture is a real stride.
        while !Task.isCancelled, leadInSeconds < leadInTarget {
            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
            leadInSeconds += tick
        }
        guard !Task.isCancelled else { return }
        stage = .capturing
        await captureLoop()
    }

    private func captureLoop() async {
        // Poll at ~5 Hz. Only accrue (and sample) while the pedometer says
        // we're actually walking.
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
        // The user starts the walk from here by choice - no auto-start.
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
