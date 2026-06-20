// Features/Diagnostics/Engine/DiagnosticTest.swift
import Foundation

enum TestCategory: String, CaseIterable, Sendable {
    case displayTouch = "Display & Touch"
    case cameras = "Cameras"
    case audio = "Audio"
    case biometrics = "Biometrics"
    case sensors = "Sensors"
    case connectivity = "Connectivity"
    case buttonsHaptics = "Buttons & Haptics"
    case power = "Power"
    case hostInfo = "Device Info"
}

/// One diagnostic test. Implementations live in Features/Diagnostics/Tests/.
protocol DiagnosticTest: Sendable {
    var id: String { get }
    var name: String { get }
    var category: TestCategory { get }
    /// True if the test needs the operator/customer to do/confirm something.
    var requiresInteraction: Bool { get }
    /// False when the hardware/capability is absent on this device → engine records `.skip`.
    var isSupported: Bool { get }
    /// Run and return an outcome. For interactive tests the UI supplies confirmation via the runner.
    func run() async -> TestOutcome
}
