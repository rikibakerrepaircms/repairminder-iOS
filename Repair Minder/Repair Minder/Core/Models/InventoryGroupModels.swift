import Foundation

// MARK: - Inventory Group (GET /api/asset-groups list + /:id detail)
// List rows carry min/avg/max_cost + is_active; detail rows omit those but add linked_products.
// So aggregate + linkedProducts fields are all optional.
struct InventoryGroup: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var category: String?
    var subcategory: String?
    var manufacturer: String?
    var modelNumber: String?
    var reorderLevel: Int?
    var reorderQuantity: Int?
    var preferredSupplierName: String?
    var defaultCost: Double?
    var defaultSellPrice: Double?
    var isOem: Int?
    var isRefurbished: Int?
    var isActive: Int?
    var createdAt: String?
    var updatedAt: String?
    var inStockCount: Int?
    var totalAssetCount: Int?
    var linkedProductCount: Int?
    var minCost: Double?
    var avgCost: Double?
    var maxCost: Double?
    var linkedProducts: [LinkedProduct]?

    var isOemBool: Bool { (isOem ?? 0) == 1 }
    var isRefurbishedBool: Bool { (isRefurbished ?? 0) == 1 }
}

// MARK: - Linked product (detail linked_products[] + /:id/products superset)
struct LinkedProduct: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var productKind: String?
    var category: String?
    var defaultSellPrice: Double?
    var vatRate: Double?
    var qualityTier: String?
    var quantityRequired: Int?
    var isRequired: Int?

    var isRequiredBool: Bool { (isRequired ?? 0) == 1 }
}

// MARK: - Membership (POST /api/asset-groups/memberships → 201)
struct GroupMembership: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetId: String?
    var groupId: String?
    var companyId: String?
    var createdBy: String?
}

// MARK: - Bulk assign result (POST /api/assets/:id/groups → data:{...})
struct BulkAssignGroupsResult: Decodable, Equatable, Sendable {
    var assetId: String?
    var groupsAdded: Int
    var groupsRemoved: Int
    var assetsAffected: Int
    var siblingMatch: String?
    var skuValue: String?
    var supplierMappingsUpdated: Int?
}

// MARK: - Promote result (POST /api/asset-groups/promote → 201 data:{product,component})
struct PromoteResult: Decodable, Equatable, Sendable {
    let product: PromotedProduct
    let component: PromotedComponent
}
struct PromotedProduct: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String?
    var sku: String?
    var category: String?
    var productKind: String?
    var defaultSellPrice: Double?
    var vatRate: Double?
}
struct PromotedComponent: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var serviceProductId: String?
    var inventoryProductId: String?
    var quantityRequired: Int?
    var isRequired: Int?
}

// MARK: - Request bodies (encoded with .convertToSnakeCase)

/// POST /api/asset-groups/memberships
struct AddMembershipRequest: Encodable {
    var assetId: String
    var groupId: String
}

/// POST /api/assets/:id/groups — empty array clears all groups
struct BulkAssignGroupsRequest: Encodable {
    var groupIds: [String]
}

/// POST /api/asset-groups/promote
struct PromoteGroupRequest: Encodable {
    var groupId: String
    var productName: String
    var productSku: String? = nil
    var productCategory: String? = nil
    var defaultSellPrice: Double? = nil
    var sellPriceIncVat: Double? = nil
    var vatRate: Double? = nil
}

/// POST /api/product-types (create) + PUT /api/product-types/:id (edit).
/// Backend REQUIRES a non-empty `category`; inline create passes "General".
struct GroupFormRequest: Encodable {
    var name: String
    var category: String
    var sku: String? = nil
    var subcategory: String? = nil
    var manufacturer: String? = nil
    var modelNumber: String? = nil
    var reorderLevel: Int? = nil
    var reorderQuantity: Int? = nil
    var defaultCost: Double? = nil
    var defaultSellPrice: Double? = nil
    var preferredSupplierName: String? = nil
    var isOem: Int? = nil
    var isRefurbished: Int? = nil
    var productKind: String = "inventory_item"
}
