import Foundation

struct KioskProduct: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let sku: String?
    let category: String?
    let defaultSellPrice: Double?
    let vatRate: Double?
    let primaryImageId: String?
    let stockTrackingMode: String?
    let inStockCount: Int?
    let reorderLevel: Int?
    let stockStatus: String?

    // Stock helpers mirroring the web KioskProductCard/Row logic.
    var stockCount: Int { inStockCount ?? 0 }
    var isTracked: Bool { (stockTrackingMode ?? "none") != "none" }
    var isLowStock: Bool { isTracked && stockCount <= (reorderLevel ?? 0) && stockCount > 0 }
    var isOutOfStock: Bool { isTracked && stockCount == 0 }

    /// Inc-VAT price shown on catalog cards/rows (ex-VAT price stored on the cart item).
    var priceIncVat: Double { (defaultSellPrice ?? 0) * (1 + (vatRate ?? 20) / 100) }
    var priceIncVatText: String { String(format: "£%.2f", priceIncVat) }
}

struct KioskProductListResponse: Decodable, Sendable {
    let success: Bool
    let data: [KioskProduct]
    let meta: KioskProductListMeta
}

struct KioskProductListMeta: Decodable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct KioskCategory: Decodable, Identifiable, Sendable {
    let category: String
    let count: Int
    var id: String { category }
}

struct KioskCategoriesResponse: Decodable, Sendable {
    let success: Bool
    let data: KioskCategoriesData
}

struct KioskCategoriesData: Decodable, Sendable {
    let categories: [KioskCategory]
    let suggested: [String]?
}
