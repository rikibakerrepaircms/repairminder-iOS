import Foundation

// MARK: - Bulk return-to-supplier (POST /api/assets/bulk-return-to-supplier)

/// Request body. `asset_ids` + reason are required; notes optional.
struct BulkReturnToSupplierRequest: Encodable {
    var assetIds: [String]
    var supplierReturnReason: String
    var supplierReturnNotes: String? = nil
}

/// Result nested under `data`. Assets are grouped into per-supplier batches;
/// `errors` collects assets the server skipped (not found / invalid status / no supplier).
struct BulkReturnToSupplierResult: Decodable, Equatable, Sendable {
    var batches: [SupplierReturnBatch]
    var totalReturned: Int
    var errors: [BulkAssetError]
}

struct SupplierReturnBatch: Decodable, Equatable, Sendable, Identifiable {
    var supplierName: String?
    var assets: [Asset]
    var count: Int
    var id: String { supplierName ?? "—" }
}

struct BulkAssetError: Decodable, Equatable, Sendable, Identifiable {
    var assetId: String
    var error: String
    var id: String { assetId }
}

// MARK: - Client-side bulk-operation progress (per-item loop outcomes; NOT decoded)

/// Records the result of one asset in a client-side bulk loop (move / deploy),
/// where each asset is a separate API call and partial success is tolerated.
struct BulkOperationOutcome: Equatable, Sendable, Identifiable {
    let assetId: String
    let assetTag: String
    var success: Bool
    var message: String?
    var id: String { assetId }
}

/// Supplier-return reason codes (mirrors the web `BulkSupplierReturnModal` select).
enum SupplierReturnReason: String, CaseIterable, Identifiable, Sendable {
    case defective
    case wrongPart = "wrong_part"
    case damagedInTransit = "damaged_in_transit"
    case qualityIssue = "quality_issue"
    case warrantyClaim = "warranty_claim"
    case orderError = "order_error"
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .defective: return "Defective"
        case .wrongPart: return "Wrong part"
        case .damagedInTransit: return "Damaged in transit"
        case .qualityIssue: return "Quality issue"
        case .warrantyClaim: return "Warranty claim"
        case .orderError: return "Order error"
        case .other: return "Other"
        }
    }
}
