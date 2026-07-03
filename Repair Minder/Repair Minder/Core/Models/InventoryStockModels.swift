import Foundation

// MARK: - Stock summary (GET /api/assets/stock-summary — `data` is an ARRAY)

/// A product-type stock rollup. Parent rows carry `aggregate_*` (parent + children)
/// and a `children` array; child rows omit those (all optional). `is_low_stock` is a
/// true JSON boolean (computed server-side), not an Int.
struct StockSummaryItem: Decodable, Identifiable, Equatable, Sendable {
    let productTypeId: String
    let name: String
    var sku: String?
    var parentId: String?
    var inStockCount: Int
    var allocatedCount: Int
    var totalCount: Int
    var reorderLevel: Int
    var isLowStock: Bool
    var aggregateInStock: Int?
    var aggregateAllocated: Int?
    var children: [StockSummaryItem]?

    var id: String { productTypeId }

    /// Prefer the aggregate (parent+children) when present, else the row's own count.
    var displayInStock: Int { aggregateInStock ?? inStockCount }
    var displayAllocated: Int { aggregateAllocated ?? allocatedCount }
    var isOutOfStock: Bool { inStockCount == 0 && reorderLevel > 0 }
}

// MARK: - Asset hierarchy (GET /api/assets/hierarchy)

struct AssetHierarchyResponse: Decodable, Equatable, Sendable {
    var grouped: [HierarchyGroup]
    var unlinked: [HierarchyAsset]
}

struct HierarchyGroup: Decodable, Equatable, Sendable, Identifiable {
    var productType: HierarchyProductType
    var assets: [HierarchyAsset]
    var children: [HierarchyGroup]?   // top-level only; nested child groups omit `children`
    var id: String { productType.id }

    /// Recursive count of assets under this node.
    var totalAssetCount: Int {
        assets.count + (children?.reduce(0) { $0 + $1.totalAssetCount } ?? 0)
    }
}

struct HierarchyProductType: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    var parentId: String?
}

struct HierarchyAsset: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let assetTag: String
    let name: String
    var status: AssetStatus
    var locationName: String?
}

// MARK: - Low stock (GET /api/assets/low-stock)

struct LowStockResponse: Decodable, Equatable, Sendable {
    var alerts: LowStockBuckets
    var all: [LowStockAlert]
    var summary: LowStockSummary
}

struct LowStockBuckets: Decodable, Equatable, Sendable {
    var parts: [LowStockAlert]
    var masters: [LowStockAlert]
    var services: [LowStockAlert]
}

struct LowStockAlert: Decodable, Equatable, Sendable, Identifiable {
    let productTypeId: String
    let name: String
    var sku: String?
    var category: String?
    var productCategory: String        // "parts" | "masters" | "services"
    var inStockCount: Int
    var reorderLevel: Int
    var deficit: Int
    var preferredSupplier: String?
    var parentName: String?
    var isChildService: Bool           // true JSON boolean
    var parentId: String?
    var id: String { productTypeId }

    var isCritical: Bool { inStockCount == 0 }
}

struct LowStockSummary: Decodable, Equatable, Sendable {
    var total: Int
    var byCategory: LowStockByCategory
}

struct LowStockByCategory: Decodable, Equatable, Sendable {
    var parts: Int
    var masters: Int
    var services: Int
}
