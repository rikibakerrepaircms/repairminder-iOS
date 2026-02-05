//
//  ScannerViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Scanner View Model

/// View model for barcode/QR scanner
@MainActor
@Observable
final class ScannerViewModel: NSObject {

    // MARK: - State

    var isScanning = false
    var scannedCode: String?
    var searchResult: DeviceListItem?
    var isSearching = false
    var error: String?
    var cameraPermissionDenied = false

    // MARK: - Camera

    var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Camera Setup

    /// Setup camera for scanning
    func setupCamera() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.configureCaptureSession()
                    } else {
                        self?.cameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private func configureCaptureSession() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            error = "No camera available"
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            self.error = "Could not create video input: \(error.localizedDescription)"
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            error = "Could not add video input"
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .code128,
                .code39,
                .code93,
                .ean8,
                .ean13,
                .upce,
                .qr,
                .dataMatrix,
                .interleaved2of5
            ]
        } else {
            error = "Could not add metadata output"
            return
        }

        captureSession = session
        isScanning = true

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    // MARK: - Scanning Control

    /// Start scanning
    func startScanning() {
        guard let session = captureSession, !session.isRunning else { return }
        isScanning = true
        scannedCode = nil
        searchResult = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    /// Stop scanning
    func stopScanning() {
        guard let session = captureSession, session.isRunning else { return }
        isScanning = false

        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.stopRunning()
        }
    }

    /// Reset scanner state
    func reset() {
        scannedCode = nil
        searchResult = nil
        error = nil
        startScanning()
    }

    // MARK: - Device Search

    /// Search for device by scanned code
    func searchDevice(code: String) async {
        isSearching = true
        error = nil

        do {
            var searchFilter = DeviceListFilter()
            searchFilter.search = code
            searchFilter.limit = 1

            let response: DeviceListResponse = try await APIClient.shared.request(
                .devices(filter: searchFilter)
            )

            if let device = response.data.first {
                searchResult = device
            } else {
                error = "No device found for: \(code)"
            }
        } catch {
            self.error = "Search failed: \(error.localizedDescription)"
        }

        isSearching = false
    }

    /// Manual search with text input
    func manualSearch(_ text: String) async {
        guard !text.isEmpty else { return }
        stopScanning()
        scannedCode = text
        await searchDevice(code: text)
    }

    // MARK: - Cleanup

    func cleanup() {
        stopScanning()
        captureSession = nil
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        // Haptic feedback
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        Task { @MainActor in
            // Stop scanning and process result
            self.stopScanning()
            self.scannedCode = stringValue
            await self.searchDevice(code: stringValue)
        }
    }
}
