import Foundation
@preconcurrency import AVFoundation
import CoreMedia

@MainActor
final class CameraProbe: NSObject, LuminanceProbe, QRProbe {
    private let device: AVCaptureDevice
    private let session = AVCaptureSession()
    private let videoOut = AVCaptureVideoDataOutput()
    private let metaOut = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "rm.diag.camera")
    private var onSample: ((Double) -> Void)?
    private var onCode: ((String) -> Void)?

    init(device: AVCaptureDevice) { self.device = device; super.init() }

    /// Exposes the underlying AVCaptureSession for live preview (read-only; session itself stays private).
    var previewSession: AVCaptureSession { session }

    static func rearLenses() -> [(type: String, device: AVCaptureDevice)] {
        let types: [(String, AVCaptureDevice.DeviceType)] = [
            ("ultrawide", .builtInUltraWideCamera),
            ("wide", .builtInWideAngleCamera),
            ("tele", .builtInTelephotoCamera),
        ]
        return types.compactMap { label, t in
            AVCaptureDevice.DiscoverySession(deviceTypes: [t], mediaType: .video, position: .back)
                .devices.first.map { (label, $0) }
        }
    }
    static func front() -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first
    }

    func start(onSample: @escaping (Double) -> Void) { self.onSample = onSample; configureAndRun() }
    func start(onCode: @escaping (String) -> Void) { self.onCode = onCode; configureAndRun() }

    private func configureAndRun() {
        #if targetEnvironment(simulator)
        return
        #else
        guard !session.isRunning else { return }
        session.beginConfiguration()
        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(videoOut) {
            videoOut.setSampleBufferDelegate(self, queue: queue); session.addOutput(videoOut)
        }
        if session.canAddOutput(metaOut) {
            session.addOutput(metaOut)
            metaOut.setMetadataObjectsDelegate(self, queue: queue)
            metaOut.metadataObjectTypes = [.qr, .ean13, .code128]
        }
        session.commitConfiguration()
        queue.async { [session] in session.startRunning() }
        #endif
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
        // Detach delegates + drop callbacks so no buffered frame/metadata fires after stop.
        videoOut.setSampleBufferDelegate(nil, queue: nil)
        metaOut.setMetadataObjectsDelegate(nil, queue: nil)
        onSample = nil
        onCode = nil
    }

    func setTorch(_ on: Bool) {
        #if targetEnvironment(simulator)
        return
        #else
        guard device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        #endif
    }
}

extension CameraProbe: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ o: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from c: AVCaptureConnection) {
        guard let px = CMSampleBufferGetImageBuffer(buffer) else { return }
        CVPixelBufferLockBaseAddress(px, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(px, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(px, 0) else { return }
        let h = CVPixelBufferGetHeightOfPlane(px, 0), bpr = CVPixelBufferGetBytesPerRowOfPlane(px, 0)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        var total = 0, n = 0
        for y in stride(from: 0, to: h, by: max(1, h / 20)) {
            for x in stride(from: 0, to: bpr, by: max(1, bpr / 20)) { total += Int(ptr[y * bpr + x]); n += 1 }
        }
        let avg = n > 0 ? Double(total) / Double(n) : 0
        Task { @MainActor in self.onSample?(avg) }
    }
}

extension CameraProbe: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ o: AVCaptureMetadataOutput, didOutput objs: [AVMetadataObject], from c: AVCaptureConnection) {
        guard let s = (objs.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        Task { @MainActor in self.onCode?(s) }
    }
}
