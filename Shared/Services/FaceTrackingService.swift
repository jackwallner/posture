#if os(iOS)
@preconcurrency import AVFoundation
import Combine
import CoreImage
import Foundation
import Observation
import Vision

/// Wraps an AVCaptureSession + Vision face landmarks to emit head-pitch samples.
/// Pitch is derived from `VNFaceObservation.pitch` (radians, 0 = looking forward,
/// negative = looking down).
@MainActor
@Observable
final class FaceTrackingService: NSObject {
    private(set) var isRunning = false
    private(set) var lastPitch: Double?
    private(set) var lastYaw: Double?
    private(set) var lastRoll: Double?
    private(set) var faceDetected: Bool = false

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "posture.face-tracking")
    private var configured = false

    var onSample: ((_ pitch: Double, _ yaw: Double, _ roll: Double) -> Void)?

    func start() async {
        let granted = await requestCameraAccess()
        guard granted else { return }
        if !configured {
            configureSession()
        }
        guard !session.isRunning else { return }
        let session = self.session
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                session.startRunning()
                continuation.resume()
            }
        }
        isRunning = true
    }

    func stop() {
        guard session.isRunning else { return }
        let session = self.session
        queue.async {
            session.stopRunning()
        }
        isRunning = false
    }

    private func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
        configured = true
    }
}

@available(iOS 13.0, *)
extension FaceTrackingService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform([request])
            guard let face = (request.results)?.first else {
                Task { @MainActor in self.faceDetected = false }
                return
            }
            let pitch = face.pitch?.doubleValue ?? 0
            let yaw = face.yaw?.doubleValue ?? 0
            let roll = face.roll?.doubleValue ?? 0
            Task { @MainActor in
                self.faceDetected = true
                self.lastPitch = pitch
                self.lastYaw = yaw
                self.lastRoll = roll
                self.onSample?(pitch, yaw, roll)
            }
        } catch {
            // Ignore individual frame failures
        }
    }
}
#endif
