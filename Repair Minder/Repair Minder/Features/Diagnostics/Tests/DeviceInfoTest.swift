// Features/Diagnostics/Tests/DeviceInfoTest.swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Auto, non-interactive: captures host-side identity/battery for the report + matching.
struct DeviceInfoTest: DiagnosticTest {
    let id = "device_info"
    let name = "Device Info"
    let category: TestCategory = .deviceInfo
    let requiresInteraction = false
    var isSupported: Bool { true }

    func run() async -> TestOutcome {
        #if canImport(UIKit)
        let details: [String: String] = await MainActor.run {
            var d2: [String: String] = [:]
            let dev = UIDevice.current
            dev.isBatteryMonitoringEnabled = true
            d2["model"] = dev.model
            d2["name"] = dev.systemName
            d2["os_version"] = dev.systemVersion
            let level = dev.batteryLevel
            if level >= 0 { d2["battery_level"] = String(Int(level * 100)) }
            d2["battery_state"] = batteryStateLabelLocal(dev.batteryState)
            return d2
        }
        #else
        let details: [String: String] = ["model": "Unknown", "os_version": "Unknown"]
        #endif
        return TestOutcome(id: id, name: name, status: .pass, details: details)
    }

    #if canImport(UIKit)
    private func batteryStateLabelLocal(_ s: UIDevice.BatteryState) -> String {
        switch s {
        case .charging: return "charging"
        case .full: return "full"
        case .unplugged: return "unplugged"
        default: return "unknown"
        }
    }
    #endif
}
