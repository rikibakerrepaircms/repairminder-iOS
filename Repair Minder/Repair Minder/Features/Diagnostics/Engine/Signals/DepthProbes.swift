import Foundation
import AVFoundation
import ARKit
import CoreMedia

@MainActor
final class TrueDepthProbe: NSObject, DepthProbe, AVCaptureDepthDataOutputDelegate {
    private let session = AVCaptureSession()
    private let depthOut = AVCaptureDepthDataOutput()
    private let queue = DispatchQueue(label: "rm.diag.truedepth")
    private var onFrame: (() -> Void)?

    func start(onDepthFrame: @escaping () -> Void) {
        #if targetEnvironment(simulator)
        return
        #else
        onFrame = onDepthFrame
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
    }
    func stop() { if session.isRunning { session.stopRunning() } }
}

@MainActor
final class LiDARProbe: NSObject, DepthProbe, ARSessionDelegate {
    private let arSession = ARSession()
    private var onFrame: (() -> Void)?

    func start(onDepthFrame: @escaping () -> Void) {
        #if targetEnvironment(simulator)
        return
        #else
        onFrame = onDepthFrame
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else { return }
        let cfg = ARWorldTrackingConfiguration()
        cfg.frameSemantics = .sceneDepth
        arSession.delegate = self
        arSession.run(cfg)
        #endif
    }
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if frame.sceneDepth != nil { Task { @MainActor in self.onFrame?() } }
    }
    func stop() { arSession.pause() }
}
