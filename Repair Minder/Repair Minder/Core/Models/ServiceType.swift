//
//  ServiceType.swift
//  Repair Minder
//

import SwiftUI

/// Service types available for booking — values match backend workflow conventions.
/// Available types are filtered at runtime based on company settings (buyback_enabled, etc.)
/// and `isAvailable` (backend support).
enum ServiceType: String, CaseIterable, Identifiable {
    case repair = "repair"
    case buyback = "buyback"
    case accessories = "accessories"
    case deviceSale = "device_sale"

    var id: String { rawValue }

    /// Whether the backend POST /api/orders supports a full booking flow for this type.
    /// `.accessories` and `.deviceSale` have backend item types but no dedicated booking flow yet.
    var isAvailable: Bool {
        switch self {
        case .repair, .buyback: return true
        case .accessories, .deviceSale: return false
        }
    }

    var title: String {
        switch self {
        case .repair: return "Repair"
        case .buyback: return "Buyback"
        case .accessories: return "Accessories"
        case .deviceSale: return "Device Sale"
        }
    }

    var subtitle: String {
        switch self {
        case .repair: return "Book in a device for repair"
        case .buyback: return "Purchase a customer device"
        case .accessories: return "Sell accessories or parts"
        case .deviceSale: return "Sell a buyback device"
        }
    }

    var icon: String {
        switch self {
        case .repair: return "wrench.and.screwdriver.fill"
        case .buyback: return "arrow.triangle.2.circlepath.circle.fill"
        case .accessories: return "bag.fill"
        case .deviceSale: return "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .repair: return .blue
        case .buyback: return .green
        case .accessories: return .purple
        case .deviceSale: return .orange
        }
    }
}
