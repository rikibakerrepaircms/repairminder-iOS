// Features/Diagnostics/Engine/DiagnosticTest.swift
import Foundation

/// Matches M360's five diagnostic categories, plus a host-side Device Info group.
enum TestCategory: String, CaseIterable, Sendable {
    case screen = "Screen"
    case hardware = "Hardware"
    case audio = "Audio"
    case connectivity = "Connectivity"
    case sensors = "Sensors"
    case deviceInfo = "Device Info"
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
