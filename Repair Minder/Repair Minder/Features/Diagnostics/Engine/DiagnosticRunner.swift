// Features/Diagnostics/Engine/DiagnosticRunner.swift
import Foundation

/// Owns selection + results for a diagnostic session. Automatic tests run via `runAuto()`;
/// interactive tests are driven by the runner UI which calls `record(_:)` per test.
/// Results are keyed by test id (latest wins) so retesting overwrites cleanly.
@MainActor
final class DiagnosticRunner: ObservableObject {
    let tests: [DiagnosticTest]
    @Published private(set) var selectedIds: Set<String> = []
    @Published private(set) var outcomes: [String: TestOutcome] = [:]
    @Published private(set) var autoRan = false

    init(tests: [DiagnosticTest]) { self.tests = tests }

    // MARK: Selection
    var selectedTests: [DiagnosticTest] { tests.filter { selectedIds.contains($0.id) } }
    var selectedInteractiveTests: [DiagnosticTest] {
        selectedTests.filter { $0.requiresInteraction && $0.isSupported }
    }
    func select(ids: [String]) { selectedIds = Set(ids) }
    func selectAll() { selectedIds = Set(tests.map(\.id)) }
    func toggle(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    func isSelected(_ id: String) -> Bool { selectedIds.contains(id) }

    // MARK: Results
    func record(_ outcome: TestOutcome) { outcomes[outcome.id] = outcome }
    func outcome(for id: String) -> TestOutcome? { outcomes[id] }

    /// Run all selected automatic tests; mark unsupported selected tests as skipped.
    func runAuto() async {
        for test in selectedTests {
            if !test.isSupported {
                record(TestOutcome(id: test.id, name: test.name, status: .skip, details: ["reason": "unsupported"]))
            } else if !test.requiresInteraction {
                record(await test.run())
            }
        }
        autoRan = true
    }

    /// Re-run a single automatic test (interactive retest is handled by the UI).
    func retestAuto(_ test: DiagnosticTest) async {
        guard test.isSupported, !test.requiresInteraction else { return }
        record(await test.run())
    }

    // MARK: Derived
    var orderedOutcomes: [TestOutcome] { selectedTests.compactMap { outcomes[$0.id] } }
    var passed: [TestOutcome] { orderedOutcomes.filter { $0.status == .pass } }
    var failedOrSkipped: [TestOutcome] {
        orderedOutcomes.filter { $0.status == .fail || $0.status == .skip || $0.status == .error }
    }
    var allSelectedHaveOutcome: Bool { selectedTests.allSatisfy { outcomes[$0.id] != nil } }

    // MARK: Derived grade
    var grade: DiagnosticGrade { DiagnosticGrade.grade(for: orderedOutcomes) }
    /// Wire/legacy string ("pass"/"partial"/"fail") kept for existing callers.
    var overallResult: String {
        switch grade { case .bad: return "fail"; case .good: return "partial"; case .excellent: return "pass" }
    }
}
