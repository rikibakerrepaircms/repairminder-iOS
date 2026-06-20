// Features/Diagnostics/Engine/TestRegistry.swift
import Foundation

/// Single source of truth for the available test battery.
/// Hardware tests are appended in later tasks. DeviceInfoTest is the host-side seed.
enum TestRegistry {
    @MainActor static func allTests() -> [DiagnosticTest] {
        var t: [DiagnosticTest] = []
        t.append(DeviceInfoTest())
        // Later tasks append: TouchTest(), DisplayTest(), CameraTest(.rear), ... etc.
        return t
    }
}
