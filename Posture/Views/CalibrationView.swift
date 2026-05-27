import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct CalibrationView: View {
    enum Mode {
        case onboarding
        case quickRecalibrate
    }

    let mode: Mode

    init(mode: Mode = .onboarding) {
        self.mode = mode
    }

    @Environment(GoalSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var step: Step = .captureBaseline
    @State private var hasAirpods: Bool?
    @State private var face = FaceTrackingService()
    @State private var airpods = HeadphoneMotionService()
    @State private var capturedBasePitch: Double?
    @State private var capturedAirpodsBasePitch: Double?
    @State private var capturedAirpodsBaseYaw: Double?
    @State private var capturedAirpodsBaseRoll: Double?
    @State private var countdown: Int = 0
    @State private var capturing: Bool = false
    @State private var countdownTask: Task<Void, Never>?
    @State private var captureError: String?
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    enum Step { case captureBaseline, done }

    var body: some View {
        Group {
            switch step {
            case .captureBaseline:
                switch cameraStatus {
                case .authorized: captureStep
                case .denied, .restricted: permissionDeniedStep
                default: requestingPermissionStep
                }
            case .done: doneStep
            }
        }
        .dawnBackground()
        .task {
            // Calibration always runs through the camera: face detection is a
            // reliable gate, whereas CMHeadphoneMotionManager.isDeviceMotionAvailable
            // reads false on cold launch even with supported AirPods connected,
            // which used to leave the AirPods-only capture button permanently
            // disabled. When the user has AirPods we also start the motion
            // service so its samples ride along and seed the AirPods baseline.
            if mode == .quickRecalibrate {
                let last = CalibrationService(context: context).current()
                hasAirpods = (last?.airpodsPitch != nil)
            } else if hasAirpods == nil {
                hasAirpods = settings.hasAirpods ?? false
            }
            await ensureCameraAndStart()
        }
        .onChange(of: scenePhase) { _, phase in
            // If the user opened Settings to flip the camera switch, pick up
            // the new permission state as soon as they come back.
            guard phase == .active, step == .captureBaseline else { return }
            let latest = AVCaptureDevice.authorizationStatus(for: .video)
            if latest != cameraStatus {
                cameraStatus = latest
                Task { await ensureCameraAndStart() }
            }
        }
        .onDisappear {
            countdownTask?.cancel()
            face.stop()
            airpods.stop()
        }
    }

    /// Drives the camera permission state machine and starts the capture
    /// session once we're allowed. Idempotent — safe to call on every
    /// foreground transition.
    private func ensureCameraAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : .denied
        case .authorized:
            cameraStatus = .authorized
        case .denied:
            cameraStatus = .denied
            return
        case .restricted:
            cameraStatus = .restricted
            return
        @unknown default:
            cameraStatus = .denied
            return
        }
        guard cameraStatus == .authorized, step == .captureBaseline else { return }
        if hasAirpods == true { airpods.start() }
        await face.start()
    }

    // MARK: - Camera capture

    private var captureStep: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: face.session).ignoresSafeArea()

            GeometryReader { geo in
                Ellipse()
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: geo.size.width * 0.56, height: geo.size.width * 0.56 / 0.72)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            }
            .ignoresSafeArea()

            VStack {
                Text("Sit upright")
                    .font(Theme.displaySerif(28))
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                Text(hasAirpods == true
                     ? "AirPods in, phone at eye level, look straight ahead. Hold still while we set your baseline."
                     : "Phone at eye level, look straight ahead. Hold still while we set your baseline.")
                    .font(.system(.callout, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if capturing {
                    Spacer()
                    Text("\(countdown)")
                        .font(Theme.displaySerif(72))
                        .foregroundStyle(.white.opacity(0.95))
                }

                Spacer()

                if let captureError {
                    Text(captureError)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 6)
                } else if !face.faceDetected && !capturing {
                    Text("Align your face inside the guide to begin.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 6)
                }

                Button {
                    guard face.faceDetected else { return }
                    runCountdown()
                } label: {
                    Text(capturing ? "Hold still…" : "Capture")
                }
                .buttonStyle(.plain)
                .daylightCTA(face.faceDetected && !capturing ? .primary : .secondary)
                .disabled(capturing || !face.faceDetected)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Permission states

    private var requestingPermissionStep: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Theme.sage)
            Text("Asking for camera permission…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var permissionDeniedStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.sandTint)
                    .frame(width: 96, height: 96)
                Image(systemName: "camera.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(Theme.sand)
            }
            .frame(maxWidth: .infinity)

            Text("Camera access is off.")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)

            Text("Posture needs the front camera to set your alignment baseline. Frames never leave your device.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            Spacer()

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: { Text("Open Settings") }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

            if mode == .quickRecalibrate {
                Button { dismiss() } label: { Text("Cancel") }
                    .buttonStyle(.plain)
                    .daylightCTA(.ghost)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 180, height: 180)
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Theme.sage)
            }
            .frame(maxWidth: .infinity)

            Text("All set.")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding(.top, 28)

            Text("We've learned your aligned posture. From here on, every check-in is just three quiet seconds.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer()

            Button {
                if mode == .quickRecalibrate { dismiss() } else { settings.hasCalibrated = true }
            } label: {
                Text(mode == .quickRecalibrate ? "Done" : "Let's go")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Capture logic

    private func runCountdown() {
        capturing = true
        captureError = nil
        countdown = 5
        AnalyticsService.calibrateStarted(mode: mode == .quickRecalibrate ? "quick" : "full")
        countdownTask?.cancel()
        countdownTask = Task {
            defer { capturing = false; countdown = 0 }
            for i in stride(from: 5, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                // P1-5: abort if the face leaves the frame mid-countdown.
                guard face.faceDetected else {
                    captureError = "Lost your face. Let's try that again."
                    return
                }
                countdown = i
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
            }

            var faceSamples: [Double] = []
            var airpodsPitch: [Double] = []
            var airpodsYaw: [Double] = []
            var airpodsRoll: [Double] = []
            for _ in 0..<10 {
                if face.faceDetected, let p = face.lastPitch { faceSamples.append(p) }
                if let p = airpods.lastPitch { airpodsPitch.append(p) }
                if let y = airpods.lastYaw { airpodsYaw.append(y) }
                if let r = airpods.lastRoll { airpodsRoll.append(r) }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            // P1-5: require enough valid samples — never persist a 0 baseline.
            guard faceSamples.count >= 5 else {
                captureError = "Couldn't get a steady read. Please try again."
                return
            }

            let faceAvg = faceSamples.reduce(0, +) / Double(faceSamples.count)
            if hasAirpods == true, !airpodsPitch.isEmpty {
                capturedAirpodsBasePitch = airpodsPitch.reduce(0, +) / Double(airpodsPitch.count)
                capturedAirpodsBaseYaw = airpodsYaw.isEmpty ? nil : airpodsYaw.reduce(0, +) / Double(airpodsYaw.count)
                capturedAirpodsBaseRoll = airpodsRoll.isEmpty ? nil : airpodsRoll.reduce(0, +) / Double(airpodsRoll.count)
            }
            guard !Task.isCancelled else { return }
            capturedBasePitch = faceAvg
            save()
            step = .done
        }
    }

    private func save() {
        guard let base = capturedBasePitch else { return }
        let cal = Calibration(
            basePitch: base,
            baseYaw: face.lastYaw ?? 0,
            baseRoll: face.lastRoll ?? 0,
            slouchPitchDelta: .pi / 24,
            airpodsPitch: capturedAirpodsBasePitch,
            airpodsRoll: capturedAirpodsBaseRoll,
            airpodsYaw: capturedAirpodsBaseYaw
        )
        CalibrationService(context: context).save(cal)
        AnalyticsService.calibrateCompleted()
        face.stop()
        airpods.stop()
    }
}
