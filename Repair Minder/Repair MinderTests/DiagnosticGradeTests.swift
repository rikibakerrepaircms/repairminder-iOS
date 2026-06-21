import Testing
@testable import Repair_Minder

struct DiagnosticGradeTests {
    private func outcome(_ id: String, _ s: TestStatus) -> TestOutcome {
        TestOutcome(id: id, name: id, status: s, details: nil)
    }
    @Test func anyFailIsBad() {
        #expect(DiagnosticGrade.grade(for: [outcome("a", .pass), outcome("b", .fail)]) == .bad)
    }
    @Test func skipsAreNotPass_yieldGoodNotExcellent() {
        #expect(DiagnosticGrade.grade(for: [outcome("a", .pass), outcome("b", .skip)]) == .good)
    }
    @Test func allPassIsExcellent() {
        #expect(DiagnosticGrade.grade(for: [outcome("a", .pass), outcome("b", .pass)]) == .excellent)
    }
    @Test func errorIsBad() {
        #expect(DiagnosticGrade.grade(for: [outcome("a", .error)]) == .bad)
    }
    @Test func emptyIsGood() {
        #expect(DiagnosticGrade.grade(for: []) == .good)
    }
}
