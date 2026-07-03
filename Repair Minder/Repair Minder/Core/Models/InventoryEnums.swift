import SwiftUI

/// Asset lifecycle status. Mirrors the backend ASSET_STATUSES set.
enum AssetStatus: String, CaseIterable, Sendable, Decodable, UnknownDefaultable {
    case inStock = "in_stock"
    case allocated
    case reserved
    case deployed
    case used
    case returned
    case damaged
    case sold
    case pendingReturn = "pending_return"
    case unknown = "__unknown__"

    static var unknownFallback: AssetStatus { .unknown }

    static var allCases: [AssetStatus] {
        [.inStock, .allocated, .reserved, .deployed, .used, .returned, .damaged, .sold, .pendingReturn]
    }

    var displayName: String {
        switch self {
        case .inStock: return "In Stock"
        case .allocated: return "Allocated"
        case .reserved: return "Reserved"
        case .deployed: return "Deployed"
        case .used: return "Used"
        case .returned: return "Returned"
        case .damaged: return "Damaged"
        case .sold: return "Sold"
        case .pendingReturn: return "Pending Return"
        case .unknown: return "Unknown"
        }
    }

    /// Query-param value for the list endpoint (nil for `.unknown`).
    var apiValue: String? { self == .unknown ? nil : rawValue }
}
