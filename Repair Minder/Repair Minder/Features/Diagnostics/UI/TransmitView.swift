// Features/Diagnostics/UI/TransmitView.swift
import SwiftUI

/// Final step: enter the shop's 6-digit code and send results to the Worker.
/// Hybrid C: POST when online; on failure the results are buffered on-device for the
/// Bridge to pull later. (iOS apps cannot read IMEI/serial, so the self-service path
/// sends device_description only; device matching happens server-side when possible.)
/// Submit is allowed when the user typed a valid shop code OR the device already holds a
/// server-issued pairing token (a token-paired device needs no code). Extracted for testing.
enum TransmitGate {
    static func canSubmit(codeIsValid: Bool, hasToken: Bool) -> Bool { codeIsValid || hasToken }
}

struct TransmitView: View {
    @ObservedObject private var runner: DiagnosticRunner
    private let service: DiagnosticsService
    @State private var shopCode: String
    @State private var remember: Bool
    @State private var phase: Phase = .idle
    @State private var isGeneratingPDF = false
    @State private var reportError: String?

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

    private var hasToken: Bool { DiagnosticsShopPairing.token != nil }
    private var canSubmit: Bool { TransmitGate.canSubmit(codeIsValid: codeIsValid, hasToken: hasToken) }

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
                        Text("Save and Sync")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.rmGlassProminent(tint: canSubmit ? .accentColor : .gray))
            .disabled(!canSubmit || phase == .sending || phase == .success)
            .padding()
            .accessibilityIdentifier("submit-results")
        }
        .alert("Couldn't Generate Report", isPresented: Binding(
            get: { reportError != nil },
            set: { if !$0 { reportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportError ?? "Please check your connection and try again.")
        }
    }

    private func submit() {
        phase = .sending
        let token = DiagnosticsShopPairing.token
        let code = shopCode
        let overall = runner.overallResult
        let outcomes = runner.orderedOutcomes
        let reportID = runner.reportID
        let desc = deviceDescription
        let liveSession = runner.liveSession
        Task {
            do {
                // A live session (paired device, opened at run start) is already `in_progress`
                // with most/all checks posted — `finish` submits anything not yet confirmed live,
                // refreshes the final verdict, then completes. Otherwise (never paired until
                // now, or the live session never opened) fall back to the batch path, unchanged.
                let companyName: String?
                if let liveSession {
                    companyName = try await service.finish(
                        session: liveSession, shopCode: codeIsValid ? code : nil, pairingToken: token,
                        platform: "ios", reportID: reportID, overallResult: overall, outcomes: outcomes)
                } else {
                    companyName = try await service.transmit(
                        shopCode: codeIsValid ? code : nil, pairingToken: token, platform: "ios",
                        imei: nil, serial: nil, deviceDescription: desc,
                        reportID: reportID, overallResult: overall, outcomes: outcomes)
                }
                // Persist pairing per the toggle. Only a freshly-typed valid code re-pairs by code;
                // a token pairing is preserved (do NOT downgrade it to a shop code). If the user
                // turned "remember" off, forget entirely.
                if remember {
                    if codeIsValid { DiagnosticsShopPairing.pair(code, name: companyName) }
                    else { DiagnosticsShopPairing.setName(companyName) }   // keep existing token pairing
                } else {
                    DiagnosticsShopPairing.unpair()
                }
                DiagnosticsResumeStore.clear()   // session genuinely completed — nothing left to resume
                phase = .success
            } catch {
                let wasToken = token != nil && !codeIsValid
                switch DiagnosticsTransmitOutcome.classify(error, wasTokenPairing: wasToken) {
                case .revokedPairing:
                    DiagnosticsShopPairing.unpair(); remember = false; phase = .unlinked
                case .transient:
                    DiagnosticsBuffer.save(shopCode: codeIsValid ? code : nil, pairingToken: token,
                                           deviceDescription: deviceDescription, imei: nil, serial: nil,
                                           reportID: runner.reportID, overallResult: overall,
                                           outcomes: runner.orderedOutcomes)
                    phase = .failed
                }
            }
        }
    }

    #if os(iOS)
    /// Ensure a server session exists (anon if this device was never paired — see
    /// `DiagnosticRunner.ensureSession()`), fetch the server-rendered report, and present a share
    /// sheet (see DiagnosticReportShare). Online-only: a fetch failure surfaces an alert, no local
    /// HTML fallback.
    private func sharePDF() {
        guard !isGeneratingPDF else { return }
        isGeneratingPDF = true
        Task {
            do {
                let session = try await runner.ensureSession()
                DiagnosticReportShare.presentShareSheet(
                    sessionId: session.sessionId, token: session.sessionToken,
                    reportID: runner.reportID, service: service.api
                ) { _ in
                    isGeneratingPDF = false
                }
            } catch {
                isGeneratingPDF = false
                reportError = error.localizedDescription
            }
        }
    }
    #endif
}
