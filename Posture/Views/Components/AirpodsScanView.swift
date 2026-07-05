import SwiftData
import SwiftUI

/// A 3-second AirPods posture scan. Reads head pitch from
/// `CMHeadphoneMotionManager` against the user's AirPods baseline. If
/// the AirPods aren't currently in-ear we show a waiting state with a
/// manual check-in fallback.
struct AirpodsScanView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let scheduledAt: Date
    let onComplete: (PostureQuality) -> Void
    let onFallback: () -> Void
    let onClose: () -> Void

    @State private var airpods = HeadphoneMotionService()
    @State private var samples: [Double] = []
    @State private var elapsedSeconds = 0
    @State private var phase: Phase = .waiting
    @State private var countdownTask: Task<Void, Never>?
    @State private var waitDeadlineTask: Task<Void, Never>?
    @State private var beginTask: Task<Void, Never>?

    enum Phase { case waiting, scanning, noConnection }

    /// If AirPods never start streaming, don't sit on "waiting" forever — fall
    /// to the no-connection view (which surfaces the prominent manual fallback).
    private let waitDeadlineSeconds: Double = 12

    var body: some View {
        Group {
            switch phase {
            case .waiting, .scanning: scanView
            case .noConnection: noConnectionView
            }
        }
        .task { begin() }
        .onDisappear {
            beginTask?.cancel()
            countdownTask?.cancel()
            waitDeadlineTask?.cancel()
            airpods.stop()
            AirpodsBackgroundMonitor.shared.resumeAfterForegroundRead()
        }
        .onChange(of: airpods.isConnected) { _, connected in
            if connected, phase == .waiting {
                runScan()
            }
        }
        // First sample = AirPods verifiably streaming. Covers the case where
        // `isConnected` flipped true before this view appeared (no onChange)
        // and the permission-dialog race where connect fires but samples only
        // start once the user grants Motion & Fitness.
        .onChange(of: airpods.lastPitch) { _, pitch in
            if pitch != nil, phase == .waiting {
                runScan()
            }
        }
    }

    // MARK: - Scan

    @SwiftUI.State private var heroPulse = false

    private var scanView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.top, 16)

            Spacer(minLength: 16)

            scanHero

            Text(phase == .scanning ? "Hold still, sit how you've been sitting."
                                    : "Pop your AirPods in to begin.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Spacer(minLength: 24)

            if phase == .waiting {
                Button { onFallback() } label: { Text("Check in by hand") }
                    .buttonStyle(.daylight(.ghost))
                    .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
    }

    private var scanHero: some View {
        ZStack {
            Circle()
                .fill(heroWash)
                .frame(width: 220, height: 220)
                .scaleEffect(heroPulse ? 1.05 : 0.96)
                .opacity(heroPulse ? 0.55 : 1.0)
            Circle()
                .fill(heroWash)
                .frame(width: 160, height: 160)
            if phase == .scanning {
                Text("\(max(0, 3 - elapsedSeconds))")
                    .font(.system(size: 84, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.2), value: elapsedSeconds)
            } else {
                Image(systemName: "airpodspro")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(heroAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: heroPulse)
        .onAppear { if !reduceMotion { heroPulse = true } }
    }

    private var heroAccent: Color {
        airpods.isConnected ? Theme.sage : Theme.sand
    }

    private var heroWash: Color {
        airpods.isConnected ? Theme.sageTint : Theme.sandTint
    }

    // MARK: - No-connection fallback view

    private var noConnectionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.top, 16)

            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .fill(Theme.sandTint)
                    .frame(width: 200, height: 200)
                Image(systemName: "airpodspro")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.sand)
            }
            .frame(maxWidth: .infinity)

            Text("Can't hear your AirPods.")
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Text("Pop them back in, or log this one by hand.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.top, 10)

            Spacer(minLength: 24)

            Button { onFallback() } label: { Text("Check in by hand") }
                .buttonStyle(.daylight(.secondary))
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
    }

    // MARK: - Lifecycle

    private func begin() {
        // Take exclusive ownership of the head-motion stream for the scan —
        // the shared background monitor would otherwise starve this view's own
        // CMHeadphoneMotionManager, leaving the scan stuck on "waiting".
        // Resumed in onDisappear.
        let monitor = AirpodsBackgroundMonitor.shared
        // If the always-on monitor was already streaming, the AirPods are
        // definitely in-ear — carry that so a slow stream handoff doesn't get
        // misread as "no AirPods".
        let airpodsKnownPresent = monitor.isMonitoring && monitor.isConnected
        monitor.suspendForForegroundRead()

        guard airpods.isAvailable else {
            phase = .noConnection
            return
        }

        beginTask?.cancel()
        beginTask = Task {
            // iOS doesn't reassign head-motion to a second manager instantly.
            // When AirPods were already streaming to the background monitor,
            // give it a beat to release before we claim the stream — otherwise
            // the first scan after foregrounding starves and falsely shows
            // "can't hear your AirPods".
            if airpodsKnownPresent {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled, phase == .waiting else { return }
            }
            airpods.start()
            if airpods.isConnected {
                runScan()
                return
            }
            // M6: don't wait on "pop your AirPods in" indefinitely. Known-present
            // AirPods earn a longer leash, since we know they're there.
            let deadline = airpodsKnownPresent ? waitDeadlineSeconds * 2 : waitDeadlineSeconds
            waitDeadlineTask?.cancel()
            waitDeadlineTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if phase == .waiting { phase = .noConnection }
            }
        }
    }

    private func runScan() {
        guard phase != .scanning else { return }
        phase = .scanning
        waitDeadlineTask?.cancel()
        countdownTask?.cancel()
        countdownTask = Task {
            for second in 0..<3 {
                guard !Task.isCancelled else { return }
                for _ in 0..<5 {
                    guard !Task.isCancelled else { return }
                    if let pitch = airpods.lastPitch {
                        samples.append(pitch)
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                elapsedSeconds = second + 1
            }
            guard !Task.isCancelled else { return }

            // M7: if we gathered readings, score them even if the AirPods
            // dropped at the very end — don't throw away the user's 3-second
            // hold. Only fall back when we truly never got a sample.
            guard !samples.isEmpty else {
                phase = .noConnection
                return
            }

            let calibration = CalibrationService(context: context).current()
            // No AirPods baseline → scoring against 0 is meaningless. Record the
            // check-in as manual rather than inventing a quality.
            guard let baseline = calibration?.airpodsPitch else {
                onFallback()
                return
            }
            let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)

            // Judge the whole hold, not the final instant: the median across
            // every sample means a single glance down at second three can't
            // flip an otherwise-upright check-in to "bad".
            guard let medianDeviation = PostureScoring.aggregateDeviation(
                samples: samples, baseline: 0
            ) else {
                onFallback()
                return
            }
            // Score against the nearer of the standing/sitting baselines so a
            // standing check-in isn't judged by the averaged (mostly sitting)
            // number. medianDeviation here is the raw median pitch.
            let referenceBaseline = PostureScoring.nearestBaseline(
                pitch: medianDeviation,
                standing: calibration?.airpodsStandingPitch,
                sitting: calibration?.airpodsSittingPitch,
                combined: baseline
            )
            let quality = PostureScoring.quality(
                deviation: medianDeviation - referenceBaseline,
                slouchDelta: slouchDelta,
                sensitivity: settings.sensitivity
            )

            airpods.stop()
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            onComplete(quality)
        }
    }

    // MARK: - Copy

    private var eyebrow: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · h:mm a"
        return f.string(from: scheduledAt)
    }
}
