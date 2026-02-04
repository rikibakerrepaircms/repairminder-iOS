# Stage 09: QR Scanner

## Objective

Implement camera-based QR code and barcode scanning to quickly look up devices, orders, and assets.

---

## Dependencies

**Requires:** [See: Stage 08] complete - Device detail view exists

---

## Complexity

**Medium** - AVFoundation camera integration, code parsing

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Scanner/ScannerView.swift` | Main scanner screen |
| `Features/Scanner/ScannerViewModel.swift` | Scanner logic |
| `Features/Scanner/CameraPreviewView.swift` | Camera preview (UIViewRepresentable) |
| `Features/Scanner/ScanResultView.swift` | Display scan result |
| `Features/Scanner/ManualEntryView.swift` | Manual code entry fallback |

---

## Implementation Details

### 1. Camera Preview (UIKit Bridge)

```swift
// Features/Scanner/CameraPreviewView.swift
import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

### 2. Scanner View Model

```swift
// Features/Scanner/ScannerViewModel.swift
import AVFoundation
import Combine

@MainActor
final class ScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var scanResult: ScanResult?
    @Published var isScanning: Bool = false
    @Published var error: String?
    @Published var permissionDenied: Bool = false

    let captureSession = AVCaptureSession()
    private var isConfigured = false

    enum ScanResult {
        case device(Device)
        case order(Order)
        case asset(String) // Asset ID
        case unknown(String)
    }

    func setupCamera() {
        guard !isConfigured else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Camera not available"
            return
        }

        let output = AVCaptureMetadataOutput()

        captureSession.beginConfiguration()

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr, .ean8, .ean13, .code128, .code39]
        }

        captureSession.commitConfiguration()
        isConfigured = true
    }

    func startScanning() {
        guard isConfigured else {
            setupCamera()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            Task { @MainActor in
                self?.isScanning = true
            }
        }
    }

    func stopScanning() {
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

        // Try device lookup
        do {
            let device: Device = try await APIClient.shared.request(
                .lookupByQR(code: code),
                responseType: Device.self
            )
            scanResult = .device(device)
            return
        } catch {}

        // Try order lookup (if code is order number)
        if let orderNumber = Int(code) {
            do {
                let order: Order = try await APIClient.shared.request(
                    .order(id: code),
                    responseType: Order.self
                )
                scanResult = .order(order)
                return
            } catch {}
        }

        // Unknown code
        scanResult = .unknown(code)
    }

    func resetScan() {
        scannedCode = nil
        scanResult = nil
        startScanning()
    }
}

extension ScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }

        Task { @MainActor in
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            await lookupCode(code)
        }
    }
}
```

### 3. Scanner View

```swift
// Features/Scanner/ScannerView.swift
import SwiftUI

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @EnvironmentObject var router: AppRouter
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.permissionDenied {
                    PermissionDeniedView()
                } else if let result = viewModel.scanResult {
                    ScanResultView(
                        result: result,
                        onNavigate: handleNavigation,
                        onRescan: viewModel.resetScan
                    )
                } else {
                    // Camera Preview
                    CameraPreviewView(session: viewModel.captureSession)
                        .ignoresSafeArea()

                    // Overlay
                    ScannerOverlay(isScanning: viewModel.isScanning)

                    // Manual Entry Button
                    VStack {
                        Spacer()
                        Button("Enter Code Manually") {
                            showManualEntry = true
                        }
                        .buttonStyle(.bordered)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.isScanning {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.stopScanning()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.startScanning()
            }
            .onDisappear {
                viewModel.stopScanning()
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView { code in
                    Task { await viewModel.lookupCode(code) }
                }
            }
        }
    }

    private func handleNavigation(_ result: ScannerViewModel.ScanResult) {
        switch result {
        case .device(let device):
            router.navigate(to: .deviceDetail(id: device.id))
        case .order(let order):
            router.navigate(to: .orderDetail(id: order.id))
        case .asset(let id):
            // Navigate to asset
            break
        case .unknown:
            break
        }
    }
}

struct ScannerOverlay: View {
    let isScanning: Bool

    var body: some View {
        ZStack {
            // Dimmed overlay with cutout
            Color.black.opacity(0.5)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: 280, height: 280)
                                .blendMode(.destinationOut)
                        )
                )
                .ignoresSafeArea()

            // Scan frame
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 280, height: 280)

            // Instructions
            VStack {
                Spacer()
                    .frame(height: 400)

                Text(isScanning ? "Point camera at QR code" : "Setting up camera...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.headline)

            Text("Please enable camera access in Settings to scan QR codes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

### 4. Scan Result View

```swift
// Features/Scanner/ScanResultView.swift
import SwiftUI

struct ScanResultView: View {
    let result: ScannerViewModel.ScanResult
    let onNavigate: (ScannerViewModel.ScanResult) -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            // Result Info
            resultContent

            // Actions
            VStack(spacing: 12) {
                Button {
                    onNavigate(result)
                } label: {
                    Text(navigateButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Scan Another") {
                    onRescan()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding()
    }

    @ViewBuilder
    var resultContent: some View {
        switch result {
        case .device(let device):
            VStack(spacing: 8) {
                Text("Device Found")
                    .font(.headline)
                Text(device.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                DeviceStatusBadge(status: device.status)
            }

        case .order(let order):
            VStack(spacing: 8) {
                Text("Order Found")
                    .font(.headline)
                Text(order.displayRef)
                    .font(.title2)
                    .fontWeight(.bold)
                OrderStatusBadge(status: order.status, size: .large)
            }

        case .asset(let id):
            VStack(spacing: 8) {
                Text("Asset Found")
                    .font(.headline)
                Text(id)
                    .font(.title2)
                    .fontWeight(.bold)
            }

        case .unknown(let code):
            VStack(spacing: 8) {
                Text("Code Scanned")
                    .font(.headline)
                Text(code)
                    .font(.title3)
                    .fontWeight(.medium)
                Text("No matching record found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var navigateButtonTitle: String {
        switch result {
        case .device: return "View Device"
        case .order: return "View Order"
        case .asset: return "View Asset"
        case .unknown: return "Search"
        }
    }
}
```

### 5. Manual Entry View

```swift
// Features/Scanner/ManualEntryView.swift
import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    let onSubmit: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter code", text: $code)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Enter the QR code, order number, or device serial")
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        onSubmit(code)
                        dismiss()
                    }
                    .disabled(code.isEmpty)
                }
            }
        }
    }
}
```

---

## Info.plist Additions

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan QR codes and barcodes for quick device lookup.</string>
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Camera permission prompt | Shows on first launch |
| QR scan | Detects and looks up code |
| Barcode scan | Detects EAN/Code128 |
| Device found | Shows device info, navigate works |
| Order found | Shows order info, navigate works |
| Unknown code | Shows code, allows rescan |
| Manual entry | Opens sheet, searches code |
| Permission denied | Shows settings prompt |

---

## Acceptance Checklist

- [ ] Camera preview displays
- [ ] QR codes detected and parsed
- [ ] Barcodes detected (EAN, Code128)
- [ ] Haptic feedback on scan
- [ ] Device lookup works
- [ ] Order lookup works
- [ ] Navigation to detail views works
- [ ] Manual entry fallback works
- [ ] Permission handling correct
- [ ] Camera stops when leaving view

---

## Handoff Notes

**For Stage 10:**
- Scanner pattern established
- Could add client lookup by scanning client QR
