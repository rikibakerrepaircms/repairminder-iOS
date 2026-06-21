// Features/Diagnostics/Tests/MicSourceAggregate.swift
// Pure aggregator: no OS guard so it compiles on simulator and is unit-testable.
import Foundation

enum MicSourceAggregate {
    /// Compute an overall microphone result from per-source pass/fail results.
    /// - Returns `.skip` when no sources were tested.
    /// - Returns `.pass` only when ALL sources passed.
    /// - Returns `.fail` if any source failed; per-source status is recorded in `details`.
    static func result(perSource: [String: Bool]) -> (status: TestStatus, details: [String: String]) {
        guard !perSource.isEmpty else { return (.skip, ["reason": "no_input"]) }
        var details = perSource.mapValues { $0 ? "pass" : "fail" }
        let status: TestStatus = perSource.values.allSatisfy { $0 } ? .pass : .fail
        details["sources_tested"] = String(perSource.count)
        return (status, details)
    }
}
