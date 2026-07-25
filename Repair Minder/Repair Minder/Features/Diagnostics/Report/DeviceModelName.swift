// Features/Diagnostics/Report/DeviceModelName.swift
// Maps the hardware identifier (sysctl hw.machine, e.g. "iPhone16,1") to a human marketing
// name for the report banner. iOS gives third-party apps only a generic "iPhone" via
// UIDevice.model; this recovers the precise model name without any private API.
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceModelName {
    /// The raw hardware identifier, e.g. "iPhone16,1". On the simulator, reads the
    /// SIMULATOR_MODEL_IDENTIFIER env var (hw.machine there is the host architecture).
    static var identifier: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !sim.isEmpty {
            return sim
        }
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    /// Pure identifier → marketing-name lookup (testable, no device dependency).
    /// Returns nil for unknown/empty identifiers.
    static func name(for identifier: String) -> String? {
        guard !identifier.isEmpty else { return nil }
        return map[identifier]
    }

    /// Best-effort marketing name (e.g. "iPhone 15 Pro"). Falls back to the generic
    /// UIDevice model ("iPhone") when the identifier is unknown.
    static var marketingName: String {
        let id = identifier
        if let name = name(for: id) { return name }
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return id.isEmpty ? "Device" : id
        #endif
    }

    /// Builds the diagnostics `device_description` sent to the Worker: the marketing
    /// name plus OS version (e.g. "iPhone 15 Pro Max 17.5") — NEVER the raw
    /// `hw.machine` identifier ("iPhone16,2"). Used by both the live-session `begin`
    /// path (`DiagnosticRunner.currentDeviceDescription`) and the batch
    /// `transmit`/buffered-replay path (`TransmitView.deviceDescription`) so every
    /// device_description the app ever sends is composed the same way (A4).
    static func diagnosticsDescription(osVersion: String?) -> String? {
        let parts = [marketingName, osVersion].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Identifier → marketing name. Covers current iPhone lines (and a few iPads); unknown
    /// identifiers fall back to the generic model, so the map need not be exhaustive.
    private static let map: [String: String] = [
        // iPhone SE
        "iPhone8,4": "iPhone SE", "iPhone12,8": "iPhone SE (2nd gen)", "iPhone14,6": "iPhone SE (3rd gen)",
        // iPhone 11
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        // iPhone 12
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        // iPhone 13
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
        // iPhone 14
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
        // iPhone 15
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        // iPhone 16
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,5": "iPhone 16e",
        // iPhone 17 — only iPhone18,3 is verified here (iOS 26 simulator). The Pro/Pro Max/Air
        // identifiers (iPhone18,x) are intentionally NOT guessed: a wrong model name on a
        // customer's certificate is worse than the generic "iPhone" fallback. Add them once
        // confirmed on real hardware.
        "iPhone18,3": "iPhone 17",
        // A few iPads (diagnostics is iPhone-led, but iPad may run it)
        "iPad13,18": "iPad (10th gen)", "iPad14,3": "iPad Pro 11-inch (4th gen)",
        "iPad14,5": "iPad Pro 12.9-inch (6th gen)", "iPad13,16": "iPad Air (5th gen)",
    ]
}
