//
//  ScannerViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import AVFoundation
import UIKit

@MainActor
@Observable
final class ScannerViewModel: NSObject {
    var scannedCode: String?
    var scanResult: ScanResult?
    var isScanning: Bool = false
    var error: String?
    var permissionDenied: Bool = false
    var isLoading: Bool = false

    let captureSession = AVCaptureSession()
    private var isConfigured = false

    enum ScanResult: Equatable {
        case device(Device)
        case order(Order)
        case unknown(String)

        static func == (lhs: ScanResult, rhs: ScanResult) -> Bool {
            switch (lhs, rhs) {
            case (.device(let d1), .device(let d2)):
                return d1.id == d2.id
            case (.order(let o1), .order(let o2)):
                return o1.id == o2.id
            case (.unknown(let s1), .unknown(let s2)):
                return s1 == s2
            default:
                return false
            }
        }
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                if granted {
                    self?.configureSession()
                } else {
                    self?.permissionDenied = true
                }
            }
        }
    }

    private func configureSession() {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(for: .video) else {
            error = "Camera not available"
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()

            captureSession.beginConfiguration()

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [
                    .qr,
                    .ean8,
                    .ean13,
                    .code128,
                    .code39
                ]
            }

            captureSession.commitConfiguration()
            isConfigured = true
        } catch {
            self.error = "Failed to configure camera: \(error.localizedDescription)"
        }
    }

    func startScanning() {
        guard isConfigured else {
            checkPermission()
            return
        }

        guard !captureSession.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            Task { @MainActor in
                self?.isScanning = true
            }
        }
    }

    func stopScanning() {
        guard captureSession.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            Task { @MainActor in
                self?.isScanning = false
            }
        }
    }

    func lookupCode(_ code: String) async {
        scannedCode = code
        stopScanning()
        isLoading = true

        defer { isLoading = false }

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Try device lookup by QR code
        do {
            let device: Device = try await APIClient.shared.request(
                .lookupByQR(code: code),
                responseType: Device.self
            )
            scanResult = .device(device)
            return
        } catch {
            // Continue to try other lookups
        }

        // Try barcode lookup (could be a device serial or asset tag)
        do {
            let device: Device = try await APIClient.shared.request(
                .lookupByBarcode(barcode: code),
                responseType: Device.self
            )
            scanResult = .device(device)
            return
        } catch {
            // Continue to try other lookups
        }

        // Try order lookup by order number (if code looks like an order number)
        if let orderNumber = Int(code), orderNumber > 0 {
            do {
                let order: Order = try await APIClient.shared.request(
                    .order(id: code),
                    responseType: Order.self
                )
                scanResult = .order(order)
                return
            } catch {
                // Not found
            }
        }

        // Unknown code - no matching record found
        scanResult = .unknown(code)
    }

    func resetScan() {
        scannedCode = nil
        scanResult = nil
        error = nil
        startScanning()
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension ScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else {
            return
        }

        Task { @MainActor in
            await lookupCode(code)
        }
    }
}
