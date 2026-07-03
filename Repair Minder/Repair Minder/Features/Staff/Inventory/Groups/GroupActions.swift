import SwiftUI

/// Pure, testable gating + presentation rules for Inventory Groups (mirrors web).
enum GroupActions {
    /// Only in-stock assets can be added to a group (web filters add-search to status=in_stock).
    static func isAssetAddable(_ asset: Asset) -> Bool { asset.status == .inStock }

    /// Group is already linked to at least one product (drives the amber warning; promote still allowed).
    static func alreadyLinked(_ group: InventoryGroup) -> Bool { (group.linkedProductCount ?? 0) > 0 }

    enum StockLevel: Equatable { case out, low, ok }
    static func stockLevel(_ group: InventoryGroup) -> StockLevel {
        let inStock = group.inStockCount ?? 0
        let reorder = group.reorderLevel ?? 0
        if inStock == 0 { return .out }
        if reorder > 0 && inStock <= reorder { return .low }
        return .ok
    }
    static func stockColor(_ group: InventoryGroup) -> Color {
        switch stockLevel(group) { case .out: return .red; case .low: return .orange; case .ok: return .green }
    }
}
