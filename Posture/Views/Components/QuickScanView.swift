import SwiftUI
import SwiftData

/// A 3-second posture scan using the front camera. Shows live quality indicator
/// during the scan and reports the final result on completion.
struct QuickScanView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings

    let scheduledAt: Date
    let onComplete: (PostureQuality?) -> Void

    @State private var face = FaceTrackingService()
    @State private var samples: [Double] = []
    @State private var currentQuality: PostureQuality = .good
    @State private var scanComplete = false
    @State private var elapsedSeconds = 0
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            Text("Hold still…")
                .font(.headline)
                .foregroundStyle(Theme.textSecondary)

            CameraPreview(session: face.session)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20).stroke(Theme.brandPrimary, lineWidth: 2)
                }
                .overlay(alignment: .bottom) {
                    PostureLiveIndicator(quality: currentQuality)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)

            Text("\(3 - elapsedSeconds)…")
                .font(.title2.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())
                .animation(.default, value: elapsedSeconds)

            if !scanComplete {
                ProgressView()
                    .tint(Theme.brandPrimary)
            }
        }
        .frame(maxHeight: 360)
        .task {
            await face.start()
            runScan()
        }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
        }
    }

    private func runScan() {
        countdownTask?.cancel()
        countdownTask = Task {
            // Sample pitch for 3 seconds at ~5Hz
            for second in 0..<3 {
                guard !Task.isCancelled else { return }
                for _ in 0..<5 {
                    guard !Task.isCancelled else { return }
                    if let pitch = face.lastPitch {
                        samples.append(pitch)
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                // Update current quality for live indicator
                let calibration = CalibrationService(context: context).current()
                let baseline = calibration?.basePitch ?? 0
                let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)
                let deviation = (samples.last ?? 0) - baseline
                currentQuality = PostureScoring.quality(
                    deviation: deviation,
                    slouchDelta: slouchDelta,
                    sensitivity: settings.sensitivity
                )
                elapsedSeconds = second + 1
            }

            guard !Task.isCancelled else { return }

            // Compute final quality from the median sample
            let calibration = CalibrationService(context: context).current()
            let baseline = calibration?.basePitch ?? 0
            let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)

            // Use the last few samples for the final reading
            let recentSamples = samples.suffix(5)
            let finalDeviation = recentSamples.isEmpty
                ? 0
                : (recentSamples.reduce(0, +) / Double(recentSamples.count)) - baseline

            let finalQuality = PostureScoring.quality(
                deviation: finalDeviation,
                slouchDelta: slouchDelta,
                sensitivity: settings.sensitivity
            )

            scanComplete = true
            face.stop()

            // Brief pause so user sees the final result
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }
            onComplete(finalQuality)
        }
    }
}

#Preview {
    QuickScanView(scheduledAt: .now) { _ in }
        .padding()
        .background(Theme.background)
}
