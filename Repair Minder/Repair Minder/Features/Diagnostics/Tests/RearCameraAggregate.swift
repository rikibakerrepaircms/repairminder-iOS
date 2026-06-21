// Features/Diagnostics/Tests/RearCameraAggregate.swift
// Pure aggregator: no OS guards so it compiles on simulator and is unit-testable.
import Foundation

enum RearCameraAggregate {
    /// Compute an overall rear-camera result from individual per-lens pass/fail results.
    /// - Returns `.skip` when no lenses were tested (simulator / no rear camera).
    /// - Returns `.pass` only when ALL lenses passed.
    /// - Returns `.fail` if any lens failed; per-lens status is recorded in `details`.
    static func result(perLens: [String: Bool]) -> (status: TestStatus, details: [String: String]) {
        guard !perLens.isEmpty else { return (.skip, ["reason": "no_rear_camera"]) }
        var details = perLens.mapValues { $0 ? "pass" : "fail" }
        let status: TestStatus = perLens.values.allSatisfy { $0 } ? .pass : .fail
        details["lenses_tested"] = String(perLens.count)
        return (status, details)
    }
}
