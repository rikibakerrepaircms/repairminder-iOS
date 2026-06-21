// Features/Diagnostics/Tests/ConnectivityTests.swift
// Connectivity: WiFi (auto), Bluetooth (auto), NFC (auto-detect), Call (manual).
import SwiftUI
@preconcurrency import Network
#if os(iOS)
import CoreBluetooth
import CoreNFC
import UIKit
#endif

// MARK: - WiFi (automatic)

struct WiFiTest: DiagnosticTest {
    let id = "wifi"; let name = "WiFi"; let category: TestCategory = .connectivity
    let requiresInteraction = false
    var isSupported: Bool { true }
    func run() async -> TestOutcome {
        await withCheckedContinuation { (cont: CheckedContinuation<TestOutcome, Never>) in
            let monitor = NWPathMonitor()
            let q = DispatchQueue(label: "diagnostics.wifi")
            nonisolated(unsafe) var done = false
            let finish: @Sendable (TestOutcome) -> Void = { o in
                if !done { done = true; monitor.cancel(); cont.resume(returning: o) }
            }
            monitor.pathUpdateHandler = { path in
                let wifi = path.usesInterfaceType(.wifi)
                if wifi && path.status == .satisfied {
                    finish(diagnosticOutcome("wifi", "WiFi", .pass, ["interface": "wifi"]))
                } else if path.status == .satisfied {
                    finish(diagnosticOutcome("wifi", "WiFi", .skip, ["reason": "not on Wi-Fi"]))
                }
            }
            monitor.start(queue: q)
            q.asyncAfter(deadline: .now() + 3) { finish(diagnosticOutcome("wifi", "WiFi", .skip, ["reason": "no Wi-Fi connection"])) }
        }
    }
}

// MARK: - Bluetooth (auto-detect powered on)

struct BluetoothTest: DiagnosticTest {
    let id = "bluetooth"; let name = "Bluetooth"; let category: TestCategory = .connectivity
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(BluetoothTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - NFC (scan a tag → auto-pass)

struct NFCTest: DiagnosticTest {
    let id = "nfc"; let name = "NFC"; let category: TestCategory = .connectivity
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { NFCTagReaderSession.readingAvailable }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(NFCTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

// MARK: - Call (manual)

struct CallTest: DiagnosticTest {
    let id = "call"; let name = "Call"; let category: TestCategory = .connectivity
    let requiresInteraction = true
    #if os(iOS)
    var isSupported: Bool { true }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { AnyView(CallTestView(complete: complete)) }
    #else
    var isSupported: Bool { false }
    #endif
}

#if os(iOS)

@MainActor private final class BTCoordinator: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var state: CBManagerState = .unknown
    private var manager: CBCentralManager?
    func start() { manager = CBCentralManager(delegate: self, queue: .main) }
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in self.state = central.state }
    }
}

private struct BluetoothTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var bt = BTCoordinator()
    var body: some View {
        TestScaffold(
            title: "Bluetooth",
            instruction: "Checking the Bluetooth radio. It passes automatically when Bluetooth reports powered-on.",
            hints: ["Turn Bluetooth on in Control Centre / Settings"],
            onPass: { complete(diagnosticOutcome("bluetooth", "Bluetooth", .pass)) },
            onFail: { complete(diagnosticOutcome("bluetooth", "Bluetooth", .fail)) },
            onSkip: { complete(diagnosticOutcome("bluetooth", "Bluetooth", .skip)) }
        ) {
            VStack(spacing: 8) {
                Image(systemName: bt.state == .poweredOn ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 44)).foregroundStyle(bt.state == .poweredOn ? .green : .secondary)
                Text(stateLabel).font(.subheadline)
            }
            .onAppear { bt.start() }
            .onChange(of: bt.state) { _, s in
                if s == .poweredOn { complete(diagnosticOutcome("bluetooth", "Bluetooth", .pass, ["state": "poweredOn"])) }
                else if s == .unsupported { complete(diagnosticOutcome("bluetooth", "Bluetooth", .skip, ["state": "unsupported"])) }
            }
        }
    }
    private var stateLabel: String {
        switch bt.state {
        case .poweredOn: return "Powered on"
        case .poweredOff: return "Turned off — enable Bluetooth"
        case .unauthorized: return "Permission denied"
        case .unsupported: return "Not supported"
        default: return "Checking…"
        }
    }
}

// Uses NFCTagReaderSession (TAG format) rather than NFCNDEFReaderSession: the iOS 18+/26 SDK
// disallows the `NDEF` value in com.apple.developer.nfc.readersession.formats at upload
// (App Store error 90778), so the entitlement is `[TAG]` only and the code must match.
// For a "does the reader detect a tag" diagnostic, detecting any tag is exactly what we want.
@MainActor private final class NFCReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    private var session: NFCTagReaderSession?
    var onDetect: (() -> Void)?
    func scan() {
        guard NFCTagReaderSession.readingAvailable else { return }
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        session?.alertMessage = "Hold an NFC tag near the top of the device"
        session?.begin()
    }
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        session.invalidate()
        Task { @MainActor in self.onDetect?() }
    }
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {}
}

private struct NFCTestView: View {
    let complete: (TestOutcome) -> Void
    @StateObject private var nfc = NFCReader()
    var body: some View {
        TestScaffold(
            title: "NFC",
            instruction: "Tap Scan, then hold an NFC tag/card to the top-back of the device. It passes automatically on detection.",
            hints: ["Make sure NFC is enabled"],
            onPass: { complete(diagnosticOutcome("nfc", "NFC", .pass)) },
            onFail: { complete(diagnosticOutcome("nfc", "NFC", .fail)) },
            onSkip: { complete(diagnosticOutcome("nfc", "NFC", .skip)) }
        ) {
            VStack(spacing: 12) {
                Image(systemName: "wave.3.right.circle").font(.system(size: 44)).foregroundStyle(Color.accentColor)
                Button("Scan for tag") { nfc.scan() }.buttonStyle(.borderedProminent)
            }
            .onAppear {
                nfc.onDetect = { complete(diagnosticOutcome("nfc", "NFC", .pass, ["detected": "1"])) }
                nfc.scan()
            }
        }
    }
}

private struct CallTestView: View {
    let complete: (TestOutcome) -> Void
    @State private var number = ""
    var body: some View {
        TestScaffold(
            title: "Call",
            instruction: "Enter a number and place a test call to check the cellular/calling capability (requires a SIM). Tap Pass if the call connects.",
            hints: ["Requires a working SIM card"],
            allowManualPass: true,
            onPass: { complete(diagnosticOutcome("call", "Call", .pass)) },
            onFail: { complete(diagnosticOutcome("call", "Call", .fail)) },
            onSkip: { complete(diagnosticOutcome("call", "Call", .skip)) }
        ) {
            VStack(spacing: 12) {
                TextField("Phone number", text: $number)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                Button("Call") {
                    let digits = number.filter { $0.isNumber || $0 == "+" }
                    if let url = URL(string: "tel://\(digits)") { UIApplication.shared.open(url) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(number.isEmpty)
            }
        }
    }
}
#endif
