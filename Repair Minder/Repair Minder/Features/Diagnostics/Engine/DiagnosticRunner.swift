// Features/Diagnostics/Engine/DiagnosticRunner.swift
import Foundation

@MainActor
final class DiagnosticRunner: ObservableObject {
    let tests: [DiagnosticTest]
    @Published private(set) var selectedIds: Set<String> = []
    @Published private(set) var outcomes: [TestOutcome] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isRunning = false

    init(tests: [DiagnosticTest]) { self.tests = tests }

    var selectedTests: [DiagnosticTest] { tests.filter { selectedIds.contains($0.id) } }

    func select(ids: [String]) { selectedIds = Set(ids) }
    func selectAll() { selectedIds = Set(tests.map(\.id)) }
    func toggle(_ id: String) { if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) } }

    func runSelected() async {
        isRunning = true
        outcomes = []
        for test in selectedTests {
            guard test.isSupported else {
                outcomes.append(TestOutcome(id: test.id, name: test.name, status: .skip, details: ["reason": "unsupported"]))
                continue
            }
            outcomes.append(await test.run())
        }
        isRunning = false
    }

    var overallResult: String {
        if outcomes.contains(where: { $0.status == .fail }) { return "fail" }
        if outcomes.contains(where: { $0.status == .partial || $0.status == .error }) { return "partial" }
        return "pass"
    }
}
