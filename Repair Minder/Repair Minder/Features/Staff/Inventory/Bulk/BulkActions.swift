import Foundation

/// Pure, testable gating rules for the bulk-actions toolbar. Mirrors the web
/// `BulkDeployModal` (in-stock only) and `BulkSupplierReturnModal` (status +
/// supplier) validity rules.
enum BulkActions {
    /// Assets deployable in bulk = only those `in_stock` (web filters the same).
    static func deployableCount(_ assets: [Asset]) -> Int {
        assets.filter { $0.status == .inStock }.count
    }

    static func deployableAssets(_ assets: [Asset]) -> [Asset] {
        assets.filter { $0.status == .inStock }
    }

    /// Return-to-supplier valid = status in {in_stock, allocated, deployed} AND a
    /// non-empty supplier name. Everything else is skipped server-side.
    static func returnableAssets(_ assets: [Asset]) -> [Asset] {
        assets.filter { isReturnable($0) }
    }

    static func isReturnable(_ asset: Asset) -> Bool {
        let okStatus: Set<AssetStatus> = [.inStock, .allocated, .deployed]
        let hasSupplier = !(asset.supplierName ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        return okStatus.contains(asset.status) && hasSupplier
    }

    static func invalidReturnCount(_ assets: [Asset]) -> Int {
        assets.count - returnableAssets(assets).count
    }

    /// Group returnable assets by supplier name for the collapsible per-supplier UI.
    struct SupplierGroup: Identifiable {
        let supplier: String
        let assets: [Asset]
        var id: String { supplier }
    }

    static func groupedBySupplier(_ assets: [Asset]) -> [SupplierGroup] {
        let returnable = returnableAssets(assets)
        let byName = Dictionary(grouping: returnable) { ($0.supplierName ?? "").trimmingCharacters(in: .whitespaces) }
        return byName
            .map { SupplierGroup(supplier: $0.key, assets: $0.value) }
            .sorted { $0.supplier < $1.supplier }
    }
}
