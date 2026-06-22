import Foundation
@preconcurrency import AVFoundation
import ARKit
import CoreMedia
import CoreImage

// MARK: - Depth image rendering helper

private let depthCIContext = CIContext(options: nil)

/// Render a depth/disparity CVPixelBuffer to a grayscale CGImage for display. Depth is in metres
/// (~0–4 m) or disparity; scale into 0–1 so it's visible, then let the render clamp. Tunable.
private func renderDepthImage(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
    let ci = CIImage(cvPixelBuffer: pixelBuffer)
    let scaled = ci.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0.25, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0.25, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0.25, y: 0, z: 0, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
    ])
    return depthCIContext.createCGImage(scaled, from: scaled.extent)
}

// MARK: - TrueDepthProbe

@MainActor
final class TrueDepthProbe: NSObject, DepthProbe, AVCaptureDepthDataOutputDelegate {
    private let session = AVCaptureSession()
    private let depthOut = AVCaptureDepthDataOutput()
    private let queue = DispatchQueue(label: "rm.diag.truedepth")
    private var onFrame: (() -> Void)?
    private var onImage: ((CGImage) -> Void)?
    // Access only from `queue` (serial delegate queue), so no lock needed.
    nonisolated(unsafe) private var frameCount = 0

    func start(onDepthFrame: @escaping () -> Void, onDepthImage: @escaping (CGImage) -> Void) {
        #if targetEnvironment(simulator)
        return
        #else
        onFrame = onDepthFrame
        onImage = onDepthImage
        guard let dev = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: dev) else { return }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(depthOut) { session.addOutput(depthOut); depthOut.setDelegate(self, callbackQueue: queue) }
        session.commitConfiguration()
        queue.async { [session] in session.startRunning() }
        #endif
    }

    nonisolated func depthDataOutput(_ o: AVCaptureDepthDataOutput, didOutput d: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        Task { @MainActor in self.onFrame?() }
        // Throttle image rendering to ~10fps (delegate fires at ~60fps).
        // `frameCount` is only mutated on the serial `queue`, so this is race-free.
        frameCount += 1
        if frameCount % 6 == 0, let img = renderDepthImage(d.depthDataMap) {
            Task { @MainActor in self.onImage?(img) }
        }
    }

    func stop() { if session.isRunning { session.stopRunning() } }
}

// MARK: - LiDARProbe

@MainActor
final class LiDARProbe: NSObject, DepthProbe, ARSessionDelegate {
    private let arSession = ARSession()
    private var onFrame: (() -> Void)?
    private var onImage: ((CGImage) -> Void)?
    // Access only from the ARSession delegate queue (consistent serial queue), so no lock needed.
    nonisolated(unsafe) private var frameCount = 0

    func start(onDepthFrame: @escaping () -> Void, onDepthImage: @escaping (CGImage) -> Void) {
        #if targetEnvironment(simulator)
        return
        #else
        onFrame = onDepthFrame
        onImage = onDepthImage
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else { return }
        let cfg = ARWorldTrackingConfiguration()
        cfg.frameSemantics = .sceneDepth
        arSession.delegate = self
        arSession.run(cfg)
        #endif
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard frame.sceneDepth != nil else { return }
        Task { @MainActor in self.onFrame?() }
        // Throttle image rendering to ~10fps.
        frameCount += 1
        if frameCount % 6 == 0, let depthMap = frame.sceneDepth?.depthMap,
           let img = renderDepthImage(depthMap) {
            Task { @MainActor in self.onImage?(img) }
        }
    }

    func stop() { arSession.pause() }
}
