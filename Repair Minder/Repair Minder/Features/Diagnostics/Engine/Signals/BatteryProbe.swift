import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class BatteryProbeUIKit: BatteryProbing {
    func snapshot() -> BatterySnapshot {
        #if canImport(UIKit) && !os(macOS)
        let d = UIDevice.current
        d.isBatteryMonitoringEnabled = true
        let pct = d.batteryLevel >= 0 ? Int((d.batteryLevel * 100).rounded()) : -1
        let state: String
        switch d.batteryState {
        case .charging: state = "charging"
        case .full: state = "full"
        case .unplugged: state = "unplugged"
        default: state = "unknown"
        }
        #else
        let pct = -1; let state = "unknown"
        #endif
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        return BatterySnapshot(levelPct: pct, state: state, thermalState: thermal,
                               lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
}
