// Features/Diagnostics/Engine/DiagnosticTest.swift
import Foundation
import SwiftUI

/// The five diagnostic categories, plus a host-side Device Info group.
enum TestCategory: String, CaseIterable, Sendable {
    case deviceInfo = "Device Info"
    case screen = "Screen"
    case hardware = "Hardware"
    case audio = "Audio"
    case connectivity = "Connectivity"
    case sensors = "Sensors"
}

/// One diagnostic test. Implementations live in Features/Diagnostics/Tests/.
///
/// - **Automatic** tests (`requiresInteraction == false`) implement `run()`; the runner executes
///   them in the background.
/// - **Interactive** tests (`requiresInteraction == true`) return a SwiftUI view from `makeView`
///   that drives the user through the test and calls `complete(outcome)` when done.
protocol DiagnosticTest: Sendable {
    var id: String { get }
    var name: String { get }
    var category: TestCategory { get }
    var requiresInteraction: Bool { get }
    /// False when the hardware/capability is absent on this device → engine records `.skip`.
    var isSupported: Bool { get }
    /// Permissions this test needs, requested up front at Start. Default: none.
    var requiredPermissions: [DiagnosticPermission] { get }
    /// Automatic tests: run and return an outcome. (Interactive tests can rely on the default.)
    func run() async -> TestOutcome
    /// Interactive tests: a view that runs the test and calls `complete` with the outcome.
    /// Automatic tests return nil (the default).
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView?
}

extension DiagnosticTest {
    var requiredPermissions: [DiagnosticPermission] { [] }
    func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: .skip, details: nil) }
    @MainActor func makeView(complete: @escaping (TestOutcome) -> Void) -> AnyView? { nil }
}
