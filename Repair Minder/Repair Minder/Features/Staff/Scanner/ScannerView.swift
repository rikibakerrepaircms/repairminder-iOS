//
//  ScannerView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI
import AVFoundation

// MARK: - Scanner View

/// Barcode/QR code scanner for device lookup
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannerViewModel = ScannerViewModel()
    @State private var manualEntryText = ""
    @State private var showingManualEntry = false
    @State private var navigateToDevice = false

    var viewModel: DevicesViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                if scannerViewModel.cameraPermissionDenied {
                    permissionDeniedView
                } else {
                    cameraPreview
                }

                // Overlay
                VStack {
                    Spacer()

                    // Scanner frame
                    if scannerViewModel.isScanning {
                        scannerFrame
                    }

                    Spacer()

                    // Results or controls
                    bottomPanel
                }
            }
            .navigationTitle("Scan Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Image(systemName: "keyboard")
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                manualEntrySheet
            }
            .navigationDestination(isPresented: $navigateToDevice) {
                if let device = scannerViewModel.searchResult,
                   let orderId = device.orderId {
                    DeviceDetailView(orderId: orderId, deviceId: device.id)
                } else {
                    ContentUnavailableView(
                        "No Order",
                        systemImage: "doc.questionmark",
                        description: Text("This device is not associated with an order")
                    )
                }
            }
            .onAppear {
                scannerViewModel.setupCamera()
            }
            .onDisappear {
                scannerViewModel.cleanup()
            }
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        CameraPreviewView(session: scannerViewModel.captureSession)
            .ignoresSafeArea()
    }

    // MARK: - Scanner Frame

    private var scannerFrame: some View {
        ZStack {
            // Dimmed overlay with cutout
            Color.black.opacity(0.5)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: 280, height: 280)
                                .blendMode(.destinationOut)
                        )
                )

            // Frame corners
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 280, height: 280)

            // Instructions
            VStack {
                Text("Point camera at barcode")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 180)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 16) {
            if scannerViewModel.isSearching {
                // Searching indicator
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching...")
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            } else if let result = scannerViewModel.searchResult {
                // Search result
                searchResultView(result)

            } else if let error = scannerViewModel.error {
                // Error
                errorView(error)

            } else if let code = scannerViewModel.scannedCode {
                // Scanned code (searching)
                scannedCodeView(code)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Search Result View

    private func searchResultView(_ device: DeviceListItem) -> some View {
        VStack(spacing: 12) {
            // Device info
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                    if let orderNumber = device.orderNumber {
                        Text(orderNumber)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                DeviceStatusBadge(status: device.deviceStatus)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    scannerViewModel.reset()
                } label: {
                    Text("Scan Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    navigateToDevice = true
                } label: {
                    Text("View Device")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Not Found")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                scannerViewModel.reset()
            } label: {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Scanned Code View

    private func scannedCodeView(_ code: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "barcode")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Scanned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.headline)
                Text("Please enable camera access in Settings to scan barcodes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Manual Entry Sheet

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Serial number or IMEI", text: $manualEntryText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Enter the device serial number or IMEI to search")
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingManualEntry = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        showingManualEntry = false
                        Task {
                            await scannerViewModel.manualSearch(manualEntryText)
                        }
                    }
                    .disabled(manualEntryText.isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - Camera Preview View

/// UIKit wrapper for camera preview layer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        if let session = session {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            context.coordinator.previewLayer = previewLayer
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Preview

#Preview {
    ScannerView()
}
