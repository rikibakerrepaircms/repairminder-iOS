// Features/Diagnostics/Engine/Signals/CaptureButtonProbe.swift
import SwiftUI
#if os(iOS)
import AVFoundation
import AVKit
import UIKit

/// Detects a hardware capture-button press (Camera Control / shutter) via AVCaptureEventInteraction.
/// Hosts a minimal back-camera capture session (required for the events to be delivered) inside an
/// invisible view. Calls `onPress` once on the first press. No-op if camera isn't authorized or the
/// device has no capture button (the caller times out → records `na`).
struct CaptureButtonProbe: UIViewRepresentable {
    let onPress: () -> Void

    /// True only on devices with a hardware Camera Control button (iPhone 16 family, iOS 18+).
    /// Uses AVCaptureSession.supportsControls — the authoritative API — rather than guessing by model.
    static var isAvailable: Bool {
        guard #available(iOS 18.0, *) else { return false }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        let session = AVCaptureSession()
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        return session.supportsControls
    }

    func makeUIView(context: Context) -> UIView {
        // Stop any session from a prior makeUIView on the same coordinator so it isn't orphaned
        // running if SwiftUI recreates the view without an intervening dismantle.
        context.coordinator.session?.stopRunning()
        let view = UIView()
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return view }
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
            DispatchQueue.global(qos: .utility).async { session.startRunning() }
            context.coordinator.session = session
        }
        if #available(iOS 17.2, *) {
            let interaction = AVCaptureEventInteraction { event in
                if event.phase == .ended { DispatchQueue.main.async { onPress() } }
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var session: AVCaptureSession? }
}
#endif
