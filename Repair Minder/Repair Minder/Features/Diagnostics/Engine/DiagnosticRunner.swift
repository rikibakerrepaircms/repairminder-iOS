// Features/Diagnostics/Engine/DiagnosticRunner.swift
import Foundation

/// Owns selection + results for a diagnostic session. Automatic tests run via `runAuto()`;
/// interactive tests are driven by the runner UI which calls `record(_:)` per test.
/// Results are keyed by test id (latest wins) so retesting overwrites cleanly.
@MainActor
final class DiagnosticRunner: ObservableObject {
    /// Where a session is in its lifecycle. Lives on the runner (not the runner *view*) so backing
    /// out of a test and re-entering resumes where the user left off instead of restarting.
    enum RunPhase { case runningAuto, interactive, finished }

    let tests: [DiagnosticTest]
    @Published private(set) var selectedIds: Set<String> = []
    @Published private(set) var outcomes: [String: TestOutcome] = [:]
    @Published private(set) var autoRan = false
    @Published var phase: RunPhase = .runningAuto
    @Published var interactiveIndex = 0

    init(tests: [DiagnosticTest]) { self.tests = tests }

    // MARK: Report identity
    /// Unique reference for this run, generated lazily on first use (when the report is shared
    /// or results transmitted) and stable thereafter. Shared by the PDF report and the transmit
    /// payload so the customer's report and the results we log carry the same id. Cleared by reset().
    private var _reportID: String?
    private var _reportDate: Date?
    private func reportIdentity() -> (id: String, date: Date) {
        if let id = _reportID, let date = _reportDate { return (id, date) }
        let date = Date()
        let id = DiagnosticReportID.generate(date: date)
        _reportID = id; _reportDate = date
        return (id, date)
    }
    var reportID: String { reportIdentity().id }
    var reportDate: Date { reportIdentity().date }

    /// True once a run is underway but not yet finished — drives the "Resume" affordance.
    var isInProgress: Bool { phase != .finished && (autoRan || interactiveIndex > 0) }

    /// Clear results and rewind to the start so the next Start is a fresh run (e.g. after the user
    /// completed a session and came back to change their selection).
    func reset() {
        outcomes = [:]
        autoRan = false
        interactiveIndex = 0
        phase = .runningAuto
        _reportID = nil          // a fresh run gets a fresh report reference
        _reportDate = nil
    }

    // MARK: Selection
    var selectedTests: [DiagnosticTest] { tests.filter { selectedIds.contains($0.id) } }
    var selectedInteractiveTests: [DiagnosticTest] {
        selectedTests.filter { $0.requiresInteraction && $0.isSupported }
    }
    /// Tests resolved during the automatic phase: background auto tests + any unsupported selections
    /// (recorded as skips). Shown as a live checklist so their results aren't invisible.
    var autoChecklistTests: [DiagnosticTest] {
        selectedTests.filter { !$0.requiresInteraction || !$0.isSupported }
    }
    var currentInteractiveTest: DiagnosticTest? {
        let list = selectedInteractiveTests
        return interactiveIndex < list.count ? list[interactiveIndex] : nil
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
