import SwiftData
import SwiftUI

struct WatchSessionView: View {
    let targetSeconds: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var motion = WatchMotionService()
    @State private var elapsed: Int = 0
    @State private var goodSeconds: Int = 0
    @State private var borderlineSeconds: Int = 0
    @State private var badSeconds: Int = 0
    @State private var currentQuality: PostureQuality = .good
    @State private var smoothedDeviation: Double?
    @State private var lastBadHaptic: Date?
    @State private var ticker: Task<Void, Never>?
    @State private var finished: Bool = false
    @State private var finalScore: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            if finished {
                summaryView
            } else {
                runningView
            }
        }
        .padding(.horizontal, 6)
        .task { await begin() }
        .onDisappear {
            ticker?.cancel()
            motion.stop()
            motion.onDeviation = nil
        }
    }

    private var runningView: some View {
        VStack(spacing: 6) {
            Text("\(max(0, targetSeconds - elapsed))s")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.qualityColor(currentQuality))

            Text(label(for: currentQuality))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.qualityColor(currentQuality))

            Spacer()

            Button("End") {
                finish()
            }
            .buttonStyle(.bordered)
            .tint(Theme.textSecondary)
        }
    }

    private var summaryView: some View {
        VStack(spacing: 8) {
            Text("\(finalScore)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(finalScore))
            Text("Score")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Button("Done") {
                StreakService(context: context).recordSessionCompleted()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandPrimary)
        }
    }

    private func label(for quality: PostureQuality) -> String {
        switch quality {
        case .good: return "GOOD"
        case .borderline: return "EASY"
        case .bad: return "SIT UP"
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return Theme.good
        case 50..<80: return Theme.borderline
        default: return Theme.bad
        }
    }

    private func begin() async {
        let calService = CalibrationService(context: context)
        let calibration = calService.current() ?? Calibration(
            basePitch: 0, baseYaw: 0, baseRoll: 0, slouchPitchDelta: .pi / 6
        )

        if let x = calibration.watchGravityX,
           let y = calibration.watchGravityY,
           let z = calibration.watchGravityZ {
            motion.setBaseline(x: x, y: y, z: z)
        }

        motion.onDeviation = { dev in
            let smoothed = PostureScoring.smoothed(previous: smoothedDeviation, sample: dev)
            smoothedDeviation = smoothed
            let quality = PostureScoring.quality(deviation: smoothed, slouchDelta: calibration.slouchPitchDelta, sensitivity: GoalSettings.shared.sensitivity)
            currentQuality = quality

            if quality == .bad {
                let now = Date()
                if lastBadHaptic == nil || now.timeIntervalSince(lastBadHaptic!) > 8 {
                    lastBadHaptic = now
                    motion.playSlouchHaptic()
                }
            }
        }
        motion.start()
        startTicker()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor in
            while !finished {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !finished else { return }
                elapsed += 1
                switch currentQuality {
                case .good: goodSeconds += 1
                case .borderline: borderlineSeconds += 1
                case .bad: badSeconds += 1
                }
                if elapsed >= targetSeconds {
                    finish()
                    return
                }
            }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        ticker?.cancel()
        motion.stop()
        let score = PostureScoring.sessionScore(
            goodSeconds: goodSeconds,
            borderlineSeconds: borderlineSeconds,
            badSeconds: badSeconds
        )
        finalScore = score
        let startedAt = Date().addingTimeInterval(TimeInterval(-elapsed))
        let session = PostureSession(
            startedAt: startedAt,
            durationSeconds: elapsed,
            score: score,
            goodSeconds: goodSeconds,
            borderlineSeconds: borderlineSeconds,
            badSeconds: badSeconds,
            source: .watch
        )
        context.insert(session)
        try? context.save()
    }
}
