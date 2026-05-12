import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SessionEngine {
    enum State: Equatable {
        case idle
        case running
        case finished(score: Int)
    }

    private(set) var state: State = .idle
    private(set) var elapsedSeconds: Int = 0
    private(set) var currentQuality: PostureQuality = .good
    private(set) var liveDeviation: Double = 0

    private var goodSeconds: Int = 0
    private var borderlineSeconds: Int = 0
    private var badSeconds: Int = 0

    private var startedAt: Date = .now
    private var targetSeconds: Int = 60
    private var smoothedDeviation: Double?
    private var ticker: Task<Void, Never>?

    private let context: ModelContext
    private let calibration: Calibration
    private let source: PostureSource
    private let sensitivity: Int

    init(context: ModelContext, calibration: Calibration, source: PostureSource, sensitivity: Int = 1) {
        self.context = context
        self.calibration = calibration
        self.source = source
        self.sensitivity = sensitivity
    }

    func start(targetSeconds: Int) {
        guard case .idle = state else { return }
        self.targetSeconds = targetSeconds
        self.startedAt = .now
        self.elapsedSeconds = 0
        self.goodSeconds = 0
        self.borderlineSeconds = 0
        self.badSeconds = 0
        self.smoothedDeviation = nil
        self.state = .running
        startTicker()
    }

    /// Push a new pose sample (radians of pitch deviation from baseline). Called by the
    /// upstream sensor service at whatever rate it produces samples.
    func ingestPitchDeviation(_ deviation: Double) {
        guard case .running = state else { return }
        let smoothed = PostureScoring.smoothed(previous: smoothedDeviation, sample: deviation)
        smoothedDeviation = smoothed
        liveDeviation = smoothed
        currentQuality = PostureScoring.quality(deviation: smoothed, slouchDelta: calibration.slouchPitchDelta, sensitivity: sensitivity)
    }

    func cancel() {
        ticker?.cancel()
        ticker = nil
        state = .idle
        elapsedSeconds = 0
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while let self, case .running = self.state {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard case .running = self.state else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        elapsedSeconds += 1
        switch currentQuality {
        case .good: goodSeconds += 1
        case .borderline: borderlineSeconds += 1
        case .bad: badSeconds += 1
        }
        if elapsedSeconds >= targetSeconds {
            finish()
        }
    }

    private func finish() {
        ticker?.cancel()
        ticker = nil
        let score = PostureScoring.sessionScore(
            goodSeconds: goodSeconds,
            borderlineSeconds: borderlineSeconds,
            badSeconds: badSeconds
        )
        let session = PostureSession(
            startedAt: startedAt,
            durationSeconds: elapsedSeconds,
            score: score,
            goodSeconds: goodSeconds,
            borderlineSeconds: borderlineSeconds,
            badSeconds: badSeconds,
            source: source
        )
        context.insert(session)
        try? context.save()
        state = .finished(score: score)
    }
}
