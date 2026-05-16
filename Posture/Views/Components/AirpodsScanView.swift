import SwiftData
import SwiftUI

/// A 3-second AirPods posture scan. No camera. Reads head pitch from
/// `CMHeadphoneMotionManager` against the user's AirPods baseline. If
/// the AirPods aren't currently in-ear we show a waiting state with
/// fallbacks (camera scan, or manual check-in).
struct AirpodsScanView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings

    let scheduledAt: Date
    let onComplete: (PostureQuality) -> Void
    let onUseCamera: () -> Void
    let onFallback: () -> Void
    let onClose: () -> Void

    @State private var airpods = HeadphoneMotionService()
    @State private var samples: [Double] = []
    @State private var elapsedSeconds = 0
    @State private var phase: Phase = .waiting
    @State private var countdownTask: Task<Void, Never>?

    enum Phase { case waiting, scanning, noConnection }

    var body: some View {
        Group {
            switch phase {
            case .waiting, .scanning: scanView
            case .noConnection: noConnectionView
            }
        }
        .task { begin() }
        .onDisappear {
            countdownTask?.cancel()
            airpods.stop()
        }
        .onChange(of: airpods.isConnected) { _, connected in
            if connected, phase == .waiting {
                runScan()
            }
        }
    }

    // MARK: - Scan

    private var scanView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .tracking(2)
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
            .padding(.top, 12)

            Spacer()

            Text(phase == .scanning ? "\(max(0, 3 - elapsedSeconds))" : "·")
                .font(Theme.displaySerif(96))
                .foregroundStyle(phase == .scanning ? Theme.ink : Theme.ink3)
                .contentTransition(.numericText())
                .animation(.default, value: elapsedSeconds)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(phase == .scanning ? "hold still. look straight ahead."
                                    : "put your airpods in.")
                .font(.system(.callout, design: .serif).italic())
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)

            Spacer()

            airpodsChip
                .padding(.bottom, 12)

            if phase == .waiting {
                Button { onUseCamera() } label: { Text("use camera instead") }
                    .buttonStyle(.plain)
                    .daylightCTA(.secondary)
                Button { onFallback() } label: { Text("check in by hand →") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }

    private var airpodsChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(airpods.isConnected ? Theme.sage : Theme.sand)
                .frame(width: 6, height: 6)
            Text(airpods.isConnected ? "airpods linked" : "waiting for airpods")
                .font(.caption.weight(.semibold))
                .foregroundStyle(airpods.isConnected ? Theme.sage : Theme.ink2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(airpods.isConnected ? Theme.sageTint : Theme.sandTint, in: .capsule)
        .frame(maxWidth: .infinity)
    }

    // MARK: - No-connection fallback view

    private var noConnectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            Spacer()
            PostureBanner(
                tone: .warn,
                title: "AirPods aren't reporting motion.",
                message: "Put them in, or fall back to the camera for this one."
            )
            Button { onUseCamera() } label: { Text("use camera") }
                .buttonStyle(.plain)
                .daylightCTA(.primary)
            Button { onFallback() } label: { Text("check in by hand →") }
                .buttonStyle(.plain)
                .daylightCTA(.ghost)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }

    // MARK: - Lifecycle

    private func begin() {
        guard airpods.isAvailable else {
            phase = .noConnection
            return
        }
        airpods.start()
        if airpods.isConnected {
            runScan()
        }
    }

    private func runScan() {
        guard phase != .scanning else { return }
        phase = .scanning
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

            // Lost connection mid-scan, or never got a reading.
            guard !samples.isEmpty, airpods.isConnected else {
                phase = .noConnection
                return
            }

            let calibration = CalibrationService(context: context).current()
            let baseline = calibration?.airpodsPitch ?? calibration?.basePitch ?? 0
            let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)

            let recent = samples.suffix(5)
            let deviation = (recent.reduce(0, +) / Double(recent.count)) - baseline
            let quality = PostureScoring.quality(
                deviation: deviation,
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
        return f.string(from: scheduledAt).lowercased()
    }
}
