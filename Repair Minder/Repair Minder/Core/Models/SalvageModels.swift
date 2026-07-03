import Foundation

// MARK: - Salvage (POST /api/buyback/:id/salvage, DELETE .../salvage/:assetId)

/// One staged salvage item. `condition_grade` must be "A"|"B"|"C". Screen fields
/// (`lcd_working`/`glass_cracked`) are only sent for screen-category groups.
struct SalvageItemRequest: Encodable, Equatable {
    var productTypeId: String
    var conditionGrade: String
    var locationId: String
    var subLocationId: String? = nil
    var lcdWorking: Int? = nil
    var glassCracked: Int? = nil
    var value: Double? = nil
    var notes: String? = nil
}

struct SalvageRequest: Encodable {
    var items: [SalvageItemRequest]
}

/// 201 response. `assets` = the newly created salvaged asset rows (full `Asset`);
/// `salvaged_assets` = the lighter projection of ALL non-deleted salvage rows.
struct SalvageResponse: Decodable, Equatable, Sendable {
    var assets: [Asset]
    var salvagedAssets: [SalvagedAssetSummary]
    var newStatus: String
    var salvageBudget: SalvageBudgetInfo
}

/// Lighter salvage-asset projection (detail endpoint + salvage/delete responses).
struct SalvagedAssetSummary: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let assetTag: String
    let name: String
    var conditionGrade: String?
    var cost: Double?
    var locationId: String?
    var lcdWorking: Int?
    var glassCracked: Int?
    var createdAt: String?
    var locationName: String?
}

struct SalvageBudgetInfo: Decodable, Equatable, Sendable {
    var cap: Double?
    var booked: Double?
    var remaining: Double?
}

/// 200 response for DELETE .../salvage/:assetId.
struct DeleteSalvageResult: Decodable, Equatable, Sendable {
    var salvagedAssets: [SalvagedAssetSummary]
    var booked: Double?
    var revertedTo: String?
}
