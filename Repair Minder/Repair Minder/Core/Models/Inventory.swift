import Foundation

/// A single inventory asset. One struct serves both the list and detail endpoints;
/// list rows and the detail record share the assets-table columns, so every field
/// beyond the identity trio is optional.
struct Asset: Decodable, Identifiable, Equatable, Sendable, Hashable {
    let id: String
    let assetTag: String
    let name: String
    let status: AssetStatus

    // Core columns
    var companyId: String?
    var productTypeId: String?
    var serialNumber: String?
    var sku: String?
    var category: String?
    var manufacturer: String?
    var modelNumber: String?
    var supplierName: String?
    var supplierOrderReference: String?
    var purchaseDate: String?
    var cost: Double?
    var costIncVat: Double?
    var warrantyMonths: Int?
    var warrantyExpires: String?
    var conditionGrade: String?
    var isOem: Int?
    var isRefurbished: Int?
    var locationId: String?
    var subLocationId: String?
    var checkedOutToOrderId: String?
    var checkedOutToDeviceId: String?
    var checkedOutAt: String?
    var checkedOutBy: String?
    var deployedAt: String?
    var returnedAt: String?
    var returnReason: String?
    var returnCondition: String?
    var supplierReturnReason: String?
    var supplierReturnNotes: String?
    var supplierReturnInitiatedAt: String?
    var supplierReturnResolvedAt: String?
    var supplierReturnResolution: String?
    var replacementAssetId: String?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?

    // Recovery / salvage origin
    var sourceType: String?
    var recoveredFromAssetId: String?
    var recoveredFromBuybackId: String?
    var recoveredFromOrderId: String?
    var recoveredFromDeviceId: String?
    var recoveredBy: String?
    var recoveredAt: String?
    var lcdWorking: Int?
    var glassCracked: Int?
    var checkedOutToBuybackId: String?

    // Joined / computed by the API
    var productTypeName: String?
    var productTypeSku: String?
    var enablePartRecovery: Int?
    var locationName: String?
    var subLocationCode: String?
    var subLocationDescription: String?
    var checkedOutOrderNumber: Int?   // API returns the linked order's ticket_number as an Int, not a String
    var checkedOutDeviceName: String?
    var createdByEmail: String?
    var updatedByEmail: String?
    var checkedOutByEmail: String?
    var groupNames: String?   // comma-joined, NOT an array
    var groupIds: String?     // comma-joined, NOT an array

    // MARK: Computed helpers
    var isOemBool: Bool { isOem == 1 }
    var isRefurbishedBool: Bool { isRefurbished == 1 }
    var enablePartRecoveryBool: Bool { enablePartRecovery == 1 }
    var lcdWorkingBool: Bool? { lcdWorking.map { $0 == 1 } }
    var glassCrackedBool: Bool? { glassCracked.map { $0 == 1 } }

    var groupNamesList: [String] {
        (groupNames ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    var groupIdsList: [String] {
        (groupIds ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var locationDisplay: String? {
        switch (locationName, subLocationCode) {
        case let (loc?, sub?): return "\(loc) / \(sub)"
        case let (loc?, nil):  return loc
        default:               return subLocationCode
        }
    }

    var formattedCost: String? { cost.map { CurrencyFormatter.format($0) } }
}

// MARK: - Activity

struct AssetActivity: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetId: String?
    var activityType: String?
    var description: String?
    var fromStatus: String?
    var toStatus: String?
    var performedBy: String?
    var performedByEmail: String?
    var performedByName: String?
    var performedAt: String?
}

// MARK: - Asset group summary (GET /api/assets/:id/groups)

struct AssetGroupSummary: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var category: String?
    var membershipId: String?
    var minCost: Double?
    var avgCost: Double?
    var maxCost: Double?
    var inStockCount: Int?
}

// MARK: - External deployment (GET /api/assets/:id/external-deployment?include_history=true)

struct ExternalDeployment: Decodable, Equatable, Sendable {
    var active: ExternalDeploymentRecord?
    var history: [ExternalDeploymentRecord]?
}

struct ExternalDeploymentRecord: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetId: String?
    var customerName: String?
    var externalReference: String?
    var notes: String?
    var deploymentDate: String?
    var status: String?
    var returnedAt: String?
    var deployedBy: String?
    var createdAt: String?
}

// MARK: - Categories (GET /api/product-types/categories)
// data: { categories: [{category, count}], suggested: [String] }
struct CategoriesResponse: Decodable, Equatable, Sendable {
    let categories: [CategoryCount]
    var suggested: [String]?
}
struct CategoryCount: Decodable, Equatable, Sendable, Identifiable {
    let category: String
    var count: Int?
    var id: String { category }
}

// MARK: - Asset group list item (GET /api/asset-groups) — for the group filter picker

struct AssetGroupListItem: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var category: String?
    var inStockCount: Int?
}
