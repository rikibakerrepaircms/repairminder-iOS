import Foundation

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
