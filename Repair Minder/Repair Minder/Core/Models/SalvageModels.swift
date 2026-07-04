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
///
/// `assets` is optional (NTH-12): `SalvageViewModel.book()` only reads `salvagedAssets`,
/// so a full `Asset` decode isn't load-bearing here. Keeping it required meant a field
/// drift on that heavier struct would throw a *false* failure client-side after the
/// worker had already created the salvage assets.
struct SalvageResponse: Decodable, Equatable, Sendable {
    // contract mirror; decoded for API fidelity, not yet rendered
    var assets: [Asset]?
    var salvagedAssets: [SalvagedAssetSummary]
    // contract mirror; decoded for API fidelity, not yet rendered
    var newStatus: String
    var salvageBudget: SalvageBudget
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

// Note: salvage budget shape reuses `SalvageBudget` (Core/Models/BuybackInventory.swift) —
// previously a near-identical duplicate (`SalvageBudgetInfo`) lived here; collapsed since
// both had the exact same shape (cap/booked/remaining: Double?) and decoding semantics.

/// 200 response for DELETE .../salvage/:assetId.
struct DeleteSalvageResult: Decodable, Equatable, Sendable {
    var salvagedAssets: [SalvagedAssetSummary]
    // contract mirror; decoded for API fidelity, not yet rendered
    var booked: Double?
    // contract mirror; decoded for API fidelity, not yet rendered
    var revertedTo: String?
}
