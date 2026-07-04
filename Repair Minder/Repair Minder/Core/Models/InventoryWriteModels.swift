import Foundation

extension Notification.Name {
    /// Posted after any single-asset mutation so the inventory list refreshes.
    static let inventoryAssetDidChange = Notification.Name("inventoryAssetDidChange")
}

// MARK: - Request bodies (encoded with .convertToSnakeCase)

/// PUT /api/assets/:id — send only the fields being edited (all optional).
struct UpdateAssetRequest: Encodable {
    var serialNumber: String? = nil
    var name: String? = nil
    var sku: String? = nil
    var category: String? = nil
    var manufacturer: String? = nil
    var modelNumber: String? = nil
    var supplierName: String? = nil
    var supplierOrderReference: String? = nil
    var purchaseDate: String? = nil
    var cost: Double? = nil
    var costIncVat: Double? = nil
    var conditionGrade: String? = nil
    var isOem: Int? = nil
    var isRefurbished: Int? = nil
    var warrantyMonths: Int? = nil
    var warrantyExpires: String? = nil
    var locationId: String? = nil
    var subLocationId: String? = nil
    var notes: String? = nil
}

/// POST /api/assets/:id/move
struct MoveAssetRequest: Encodable {
    var locationId: String
    var subLocationId: String? = nil
}

/// POST /api/assets/:id/allocate
struct AllocateRequest: Encodable {
    var orderId: String? = nil
    var deviceId: String? = nil
    var orderItemId: String? = nil
    var deploy: Bool
    var recovery: RecoveryInput? = nil
}

struct RecoveryInput: Encodable {
    var conditionGrade: String
    var locationId: String
    var subLocationId: String? = nil
    var notes: String? = nil
    var lcdWorking: Int? = nil
    var glassCracked: Int? = nil
}

/// POST /api/assets/:id/deploy-external
struct DeployExternalRequest: Encodable {
    var customerName: String? = nil
    var externalReference: String? = nil
    var notes: String? = nil
    var deploymentDate: String? = nil

    /// Formats a `Date` as the "yyyy-MM-dd" string the API expects for `deploymentDate`.
    /// Shared by the single-asset and bulk deploy-external flows so both encode identically.
    static func isoDateString(from date: Date) -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}

/// POST /api/assets/:id/return-external
struct ReturnExternalRequest: Encodable {
    var deploymentId: String
    var returnToStock: Bool? = nil
    var notes: String? = nil
}

/// POST /api/assets/:id/return-to-supplier
struct ReturnToSupplierRequest: Encodable {
    var supplierReturnReason: String
    var supplierReturnNotes: String? = nil
}

/// POST /api/assets/:id/resolve-supplier-return
struct ResolveReturnRequest: Encodable {
    var resolution: String   // "credit_received" | "replacement_received"
    var replacementAssetId: String? = nil
    var notes: String? = nil
}

// MARK: - Custom response shapes (envelope-level siblings of `data`, or nested)

/// PUT /api/assets/:id — full body (sku_updated_count sits beside `data`).
struct EditAssetResponse: Decodable {
    let success: Bool
    let data: Asset
    let skuUpdatedCount: Int?
}

/// POST /api/assets/:id/allocate — full body.
struct AllocateResponse: Decodable {
    let success: Bool
    let data: Asset
    let promptReadyToRepair: Bool?
    let allocatedParts: [AllocatedPart]?
    let device: AllocateDevice?
    let recoveredAsset: Asset?   // Asset already carries productTypeName/locationName/subLocationCode
}

struct AllocatedPart: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetName: String?
    var assetTag: String?
    var sourceStatus: String?
}

struct AllocateDevice: Decodable, Equatable, Sendable {
    let id: String
    var status: String?
    var displayName: String?
}

/// POST /api/assets/:id/deploy-external — this shape sits UNDER `data`.
struct DeployExternalData: Decodable, Equatable, Sendable {
    let asset: Asset
    // contract mirror; decoded for API fidelity, not yet rendered
    let deployment: ExternalDeploymentRecord   // reused from Phase 1 (Core/Models/Inventory.swift)
}
