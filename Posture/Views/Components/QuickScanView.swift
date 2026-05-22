import AVFoundation
import SwiftUI
import SwiftData
import UIKit

/// A 3-second posture scan. Full-bleed camera with an oval head guide.
/// Routes to Daylight error states (permission denied / no face) instead
/// of fabricating a "good" reading when the camera can't produce data.
struct QuickScanView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings

    let scheduledAt: Date
    let onComplete: (PostureQuality) -> Void
    let onFallback: () -> Void
    let onClose: () -> Void

    @State private var face = FaceTrackingService()
    @State private var samples: [Double] = []
    @State private var scanComplete = false
    @State private var elapsedSeconds = 0
    @State private var countdownTask: Task<Void, Never>?
    @State private var faceEverDetected = false
    @State private var phase: Phase = .checkingPermission

    enum Phase {
        case checkingPermission
        case permissionDenied
        case scanning
        case noFaceDetected
    }

    var body: some View {
        Group {
            switch phase {
            case .checkingPermission, .scanning:
                scanView
            case .permissionDenied:
                messageView(
                    title: "Camera access denied.",
                    message: "Posture needs the front camera for a quick scan. Manual check-ins still work.",
                    primaryLabel: "open settings",
                    primary: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            case .noFaceDetected:
                messageView(
                    title: "Couldn't see your face.",
                    message: "Make sure your face is inside the oval and try again, or just check in by hand.",
                    primaryLabel: "try again",
                    primary: { resetAndScan() }
                )
            }
        }
        .task { await begin() }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
        }
    }

    // MARK: - Scan

    private var scanView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: face.session)
                .ignoresSafeArea()

            GeometryReader { geo in
                Ellipse()
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: geo.size.width * 0.56,
                           height: geo.size.width * 0.56 / 0.72)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                Text("\(max(0, 3 - elapsedSeconds))")
                    .font(Theme.displaySerif(72))
                    .foregroundStyle(.white.opacity(0.95))
                    .contentTransition(.numericText())
                    .animation(.default, value: elapsedSeconds)

                Spacer()

                facePill
                    .padding(.bottom, 8)
                Text("hold still. look straight ahead.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 28)
            }
        }
    }

    private var facePill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(face.faceDetected ? Theme.sage : Theme.sand)
                .frame(width: 6, height: 6)
            Text(face.faceDetected ? "head centered" : "bring your face back into the frame")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: .capsule)
    }

    private func messageView(
        title: String,
        message: String,
        primaryLabel: String,
        primary: @escaping () -> Void
    ) -> some View {
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
            PostureBanner(tone: .error, title: title, message: message)
            Button { primary() } label: { Text(primaryLabel) }
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

    private func begin() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .denied, .restricted:
            phase = .permissionDenied
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                phase = .permissionDenied
                return
            }
        default:
            break
        }
        phase = .scanning
        await face.start()
        runScan()
    }

    private func resetAndScan() {
        countdownTask?.cancel()
        samples = []
        scanComplete = false
        elapsedSeconds = 0
        faceEverDetected = false
        phase = .scanning
        Task {
            await face.start()
            runScan()
        }
    }

    private func runScan() {
        countdownTask?.cancel()
        countdownTask = Task {
            // Count only the ticks where a face is actually in frame: the
            // countdown pauses while the user is out of view and resumes
            // when centered, so "hold still" means literally three seconds
            // of held posture. A wall-clock cap prevents an endless wait.
            let ticksPerSecond = 5
            let neededTicks = 3 * ticksPerSecond
            let maxTicks = neededTicks * 4
            var detectedTicks = 0
            var totalTicks = 0
            while detectedTicks < neededTicks {
                guard !Task.isCancelled else { return }
                if face.faceDetected {
                    faceEverDetected = true
                    if let pitch = face.lastPitch { samples.append(pitch) }
                    detectedTicks += 1
                    elapsedSeconds = detectedTicks / ticksPerSecond
                }
                totalTicks += 1
                if totalTicks >= maxTicks { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            guard !Task.isCancelled else { return }

            // No face ever seen, or no samples — bail to error state. Do
            // NOT call onComplete with a fabricated "good" reading.
            guard faceEverDetected, !samples.isEmpty else {
                face.stop()
                phase = .noFaceDetected
                return
            }

            let calibration = CalibrationService(context: context).current()
            let baseline = calibration?.basePitch ?? 0
            let slouchDelta = calibration?.slouchPitchDelta ?? (.pi / 24)

            let recentSamples = samples.suffix(5)
            let finalDeviation = (recentSamples.reduce(0, +) / Double(recentSamples.count)) - baseline

            let finalQuality = PostureScoring.quality(
                deviation: finalDeviation,
                slouchDelta: slouchDelta,
                sensitivity: settings.sensitivity
            )

            scanComplete = true
            face.stop()

            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            onComplete(finalQuality)
        }
    }
}
