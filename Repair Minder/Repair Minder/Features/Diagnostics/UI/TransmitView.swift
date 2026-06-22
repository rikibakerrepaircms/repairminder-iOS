// Features/Diagnostics/UI/TransmitView.swift
import SwiftUI

/// Final step: enter the shop's 6-digit code and send results to the Worker.
/// Hybrid C: POST when online; on failure the results are buffered on-device for the
/// Bridge to pull later. (iOS apps cannot read IMEI/serial, so the self-service path
/// sends device_description only; device matching happens server-side when possible.)
struct TransmitView: View {
    @ObservedObject private var runner: DiagnosticRunner
    private let service: DiagnosticsService
    @State private var shopCode: String
    @State private var remember: Bool
    @State private var phase: Phase = .idle
    @State private var isGeneratingPDF = false

    enum Phase: Equatable { case idle, sending, success, failed, unlinked }

    init(runner: DiagnosticRunner) {
        _runner = ObservedObject(wrappedValue: runner)
        // Prefill (and keep "remember" on) for a device already paired to a shop.
        _shopCode = State(initialValue: DiagnosticsShopPairing.shopCode ?? "")
        _remember = State(initialValue: DiagnosticsShopPairing.isPaired)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestStubTransmit") {
            service = DiagnosticsService(api: StubDiagnosticsAPI())
        } else {
            service = DiagnosticsService()
        }
        #else
        service = DiagnosticsService()
        #endif
    }

    private var deviceDescription: String? {
        // Prefer the precise marketing name (e.g. "iPhone 15 Pro"), matching the PDF banner,
        // rather than UIDevice's generic "iPhone". os_version comes from the device_info test.
        let os = runner.outcome(for: "device_info")?.details?["os_version"]
        let parts = [DeviceModelName.marketingName, os].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var codeIsValid: Bool { shopCode.count == 6 && shopCode.allSatisfy(\.isNumber) }

    var body: some View {
        Form {
            Section("Send to your shop") {
                TextField("6-digit shop code", text: $shopCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityIdentifier("shop-code-field")

                Toggle("Remember this shop on this device", isOn: $remember)
                    .accessibilityIdentifier("remember-shop")

                if DiagnosticsShopPairing.isPaired {
                    Button("Forget shop on this device", role: .destructive) {
                        DiagnosticsShopPairing.unpair()
                        remember = false
                        shopCode = ""
                    }
                    .accessibilityIdentifier("forget-shop")
                }
            }

            if remember {
                Section {
                    Label("This device will send future results to this shop automatically.",
                          systemImage: "checkmark.seal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            switch phase {
            case .idle, .sending:
                EmptyView()
            case .success:
                Label("Results sent. Thank you!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("transmit-success")
            case .failed:
                Label("Couldn't send — saved on this device and will sync when connected.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("transmit-buffered")
            case .unlinked:
                Label("This device is no longer linked to a shop. Enter a shop code to send.",
                      systemImage: "link.badge.minus")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("transmit-unlinked")
            }
        }
        .navigationTitle("Send Results")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: sharePDF) {
                    if isGeneratingPDF {
                        ProgressView()
                    } else {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isGeneratingPDF || runner.orderedOutcomes.isEmpty)
                .accessibilityIdentifier("share-pdf-transmit")
            }
        }
        #endif
        .safeAreaInset(edge: .bottom) {
            Button(action: submit) {
                Group {
                    if phase == .sending {
                        ProgressView()
                    } else {
                        Text("Submit")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.rmGlassProminent(tint: codeIsValid ? .accentColor : .gray))
            .disabled(!codeIsValid || phase == .sending || phase == .success)
            .padding()
            .accessibilityIdentifier("submit-results")
        }
    }

    private func submit() {
        phase = .sending
        Task {
            do {
                let companyName = try await service.transmit(
                    shopCode: shopCode, platform: "ios", imei: nil, serial: nil,
                    deviceDescription: deviceDescription, reportID: runner.reportID,
                    overallResult: runner.overallResult, outcomes: runner.orderedOutcomes)
                // Pair this device to the shop (or forget) per the toggle, so future runs auto-send.
                // The company name (for "Welcome back …") comes from the server response.
                if remember { DiagnosticsShopPairing.pair(shopCode, name: companyName) } else { DiagnosticsShopPairing.unpair() }
                phase = .success
            } catch {
                let wasToken = DiagnosticsShopPairing.token != nil && shopCode.isEmpty
                switch DiagnosticsTransmitOutcome.classify(error, wasTokenPairing: wasToken) {
                case .revokedPairing:
                    DiagnosticsShopPairing.unpair()
                    remember = false
                    phase = .unlinked
                case .transient:
                    DiagnosticsBuffer.save(shopCode: shopCode, deviceDescription: deviceDescription,
                                           imei: nil, serial: nil, reportID: runner.reportID,
                                           outcomes: runner.orderedOutcomes)
                    phase = .failed
                }
            }
        }
    }

    #if os(iOS)
    /// Build the branded PDF report and present a share sheet (see DiagnosticReportShare).
    private func sharePDF() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        DiagnosticReportShare.presentShareSheet(for: runner) { _ in
            isGeneratingPDF = false
        }
    }
    #endif
}
