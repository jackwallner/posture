import AVFoundation
import SwiftUI
import SwiftData
import UIKit

/// A 3-second posture scan using the front camera. Routes to error states
/// (permission denied / no face seen) instead of silently recording a
/// fake "good" reading when the camera can't produce data.
struct QuickScanView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings

    let scheduledAt: Date
    let onComplete: (PostureQuality) -> Void
    let onFallback: () -> Void

    @State private var face = FaceTrackingService()
    @State private var samples: [Double] = []
    @State private var currentQuality: PostureQuality = .good
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
                permissionDeniedView
            case .noFaceDetected:
                noFaceView
            }
        }
        .task { await begin() }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
        }
    }

    // MARK: - Scan UI

    private var scanView: some View {
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
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("Camera access needed")
                .font(.title3.bold())
            Text("To check your posture with a camera scan, Posture needs permission to use the front camera. Enable it in Settings, or use a manual check-in instead.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
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

            Button { onFallback() } label: {
                Text("Use manual check-in instead")
                    .font(.subheadline)
                    .foregroundStyle(Theme.brandPrimary)
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
    }

    private var noFaceView: some View {
        VStack(spacing: 16) {
            Image(systemName: "face.dashed")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textSecondary)
            Text("Couldn't see your face")
                .font(.title3.bold())
            Text("Make sure your face is visible in the camera and try again, or use a manual check-in.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button { resetAndScan() } label: {
                Text("Try again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)

            Button { onFallback() } label: {
                Text("Use manual check-in instead")
                    .font(.subheadline)
                    .foregroundStyle(Theme.brandPrimary)
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 12)
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
        currentQuality = .good
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
            for second in 0..<3 {
                guard !Task.isCancelled else { return }
                for _ in 0..<5 {
                    guard !Task.isCancelled else { return }
                    if let pitch = face.lastPitch {
                        samples.append(pitch)
                    }
                    if face.faceDetected {
                        faceEverDetected = true
                    }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
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

#Preview {
    QuickScanView(scheduledAt: .now, onComplete: { _ in }, onFallback: {})
        .padding()
        .background(Theme.background)
}
