import Foundation

/// Overall session grade, shown as a chip on the results screen.
enum DiagnosticGrade: String, Sendable {
    case bad, good, excellent

    /// Bad if any fail/error/partial. Excellent if every outcome passed. Good otherwise
    /// (passes plus skips — skips are NOT counted as pass).
    static func grade(for outcomes: [TestOutcome]) -> DiagnosticGrade {
        if outcomes.contains(where: { $0.status == .fail || $0.status == .error || $0.status == .partial }) {
            return .bad
        }
        if !outcomes.isEmpty && outcomes.allSatisfy({ $0.status == .pass }) {
            return .excellent
        }
        return .good
    }
}
