import Foundation

/// Pure, testable gating rules for the per-asset write actions.
/// Mirrors the web `AssetDetailPage` enable/disable conditions exactly.
enum AssetActions {
    /// Deploy/allocate is offered only for in-stock assets.
    static func canDeploy(_ a: Asset) -> Bool { a.status == .inStock }

    /// Delete is blocked while the asset is allocated or deployed.
    static func canDelete(_ a: Asset) -> Bool {
        a.status != .allocated && a.status != .deployed
    }

    /// Return-to-supplier requires a supplier, an eligible status, and no return in progress.
    static func canReturnToSupplier(_ a: Asset) -> Bool {
        returnToSupplierDisabledReason(a) == nil
    }

    /// Priority-ordered disabled reason (mirrors the web tooltip), or nil when enabled.
    static func returnToSupplierDisabledReason(_ a: Asset) -> String? {
        if a.status == .pendingReturn { return "Return already in progress" }
        if a.supplierName == nil || (a.supplierName ?? "").isEmpty { return "No supplier assigned" }
        if ![.inStock, .allocated, .deployed].contains(a.status) { return "Cannot return asset with this status" }
        return nil
    }

    /// Resolve is available only while a supplier return is pending.
    static func canResolveReturn(_ a: Asset) -> Bool { a.status == .pendingReturn }

    /// Return-to-stock (from external) requires a deployed asset with an active deployment.
    static func canReturnToStock(_ a: Asset, hasActiveExternalDeployment: Bool) -> Bool {
        a.status == .deployed && hasActiveExternalDeployment
    }
}
