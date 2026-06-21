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
        var details: [String: String] = [:]
        #if canImport(UIKit)
        await MainActor.run {
            let d = UIDevice.current
            d.isBatteryMonitoringEnabled = true
            details["model"] = d.model
            details["name"] = d.systemName
            details["os_version"] = d.systemVersion
            let level = d.batteryLevel
            if level >= 0 { details["battery_level"] = String(Int(level * 100)) }
            details["battery_state"] = batteryStateLabelLocal(d.batteryState)
        }
        #else
        details["model"] = "Unknown"; details["os_version"] = "Unknown"
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
