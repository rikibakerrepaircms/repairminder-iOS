//
//  BuybackInventory.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import Foundation

// MARK: - List Response

/// Response wrapper for GET /api/buyback
/// API returns: { success, data: { items, pagination, filters } }
struct BuybackListResponse: Decodable, Sendable {
    let items: [BuybackItem]
    let pagination: Pagination
    let filters: BuybackFilters
}

/// Filter options returned with the buyback list
struct BuybackFilters: Decodable, Equatable, Sendable {
    let statuses: [BuybackStatusCount]
    let engineers: [BuybackFilterEngineer]
}

struct BuybackStatusCount: Decodable, Equatable, Sendable, Identifiable {
    let status: String
    let count: Int

    var id: String { status }
}

struct BuybackFilterEngineer: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Buyback Status

enum BuybackStatus: String, CaseIterable, Sendable {
    case purchased
    case awaitingParts = "awaiting_parts"
    case readyToRepair = "ready_to_repair"
    case refurbishing
    case forSale = "for_sale"
    case sold
    case salvaged

    var displayName: String {
        switch self {
        case .purchased: return "Purchased"
        case .awaitingParts: return "Awaiting Parts"
        case .readyToRepair: return "Ready to Repair"
        case .refurbishing: return "Refurbishing"
        case .forSale: return "For Sale"
        case .sold: return "Sold"
        case .salvaged: return "Salvaged"
        }
    }
}

// MARK: - Buyback List Item

/// A single buyback item as returned in the list endpoint
struct BuybackItem: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: String

    // Device info
    let brand: String?
    let model: String?
    let serialNumber: String?
    let imei: String?
    let imei2: String?
    let storageCapacity: String?
    let colour: String?

    // Status
    let status: String
    let blacklistStatus: String?

    // Purchase info
    let purchaseDate: String?
    let purchaseAmount: Double?
    let purchasePaymentMethod: String?
    let purchaseOrderId: String?
    let purchaseOrderReference: String?
    let purchaseOrderNumber: Int?

    // Sale info
    let saleDate: String?
    let saleAmount: Double?

    // Refurbishment
    let totalRefurbishmentCost: Double?

    // Storefront/listing
    let sellPrice: Double?
    let specialOfferPrice: Double?
    let listingCondition: String?
    let listingGeneratedAt: String?
    let listingImageId: String?
    let listingImageCount: Int?
    let storefrontPublished: Int?

    // Location & assignment
    let locationId: String?
    let locationName: String?
    let subLocationId: String?
    let subLocationName: String?
    let assignedEngineerId: String?
    let engineerName: String?

    // VAT
    let vatReportLocked: Int?

    // Metadata
    let createdAt: String?

    // Nested
    let notes: [BuybackNote]?
    let notesCount: Int?

    // MARK: - Computed Properties

    /// e.g. "Apple iPhone 13 128GB"
    var deviceDisplayName: String {
        [brand, model, storageCapacity]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Primary identifier to display (IMEI preferred, then serial)
    var primaryIdentifier: String? {
        if let imei = imei, !imei.isEmpty { return "IMEI: \(imei)" }
        if let sn = serialNumber, !sn.isEmpty { return "SN: \(sn)" }
        return nil
    }

    var buybackStatus: BuybackStatus? {
        BuybackStatus(rawValue: status)
    }

    var isVatLocked: Bool {
        vatReportLocked == 1
    }

    var isBlacklisted: Bool {
        guard let bl = blacklistStatus else { return false }
        return bl.lowercased() != "clean" && !bl.isEmpty
    }

    var formattedPurchaseAmount: String? {
        guard let amount = purchaseAmount else { return nil }
        return CurrencyFormatter.format(amount)
    }

    var formattedSaleAmount: String? {
        guard let amount = saleAmount else { return nil }
        return CurrencyFormatter.format(amount)
    }

    var formattedSellPrice: String? {
        guard let price = sellPrice else { return nil }
        return CurrencyFormatter.format(price)
    }

    var formattedSpecialOfferPrice: String? {
        guard let price = specialOfferPrice else { return nil }
        return CurrencyFormatter.format(price)
    }

    var formattedRefurbishmentCost: String? {
        guard let cost = totalRefurbishmentCost, cost > 0 else { return nil }
        return CurrencyFormatter.format(cost)
    }

    var formattedPaymentMethod: String? {
        guard let method = purchasePaymentMethod else { return nil }
        return method.replacingOccurrences(of: "_", with: " ").capitalized
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BuybackItem, rhs: BuybackItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Buyback Detail

/// Full buyback detail as returned by GET /api/buyback/:id
/// Merges buyback_inventory + buyback_listing + nested collections
struct BuybackDetail: Decodable, Identifiable, Equatable, Sendable {
    let id: String

    // ── Device Info ──
    let brand: String?
    let model: String?
    let serialNumber: String?
    let imei: String?
    let imei2: String?
    let meid: String?
    let storageCapacity: String?
    let colour: String?
    let modelNumber: String?
    let manufacturer: String?
    let fullName: String?
    let description: String?

    // ── Device Status Checks ──
    let warrantyStatus: String?
    let warrantyUntil: String?
    let findMyStatus: String?
    let icloudStatus: String?
    let blacklistStatus: String?
    let mdmStatus: String?
    let simLockStatus: String?
    let lockedCarrier: String?
    let carrier: String?
    let purchaseCountry: String?
    let demoUnit: String?
    let loanerDevice: String?
    let replacedDevice: String?
    let replacementDevice: String?
    let refurbishedDevice: String?
    let productionDate: String?
    let estimatedPurchaseDate: String?

    // ── RMCheck ──
    let rmcheckLookupId: String?
    let rmcheckServiceUsed: String?
    let deviceDetailsJson: String?

    // ── Status ──
    let status: String
    let batteryHealth: String?
    let category: String?

    // ── Purchase Info ──
    let purchaseDate: String?
    let purchaseAmount: Double?
    let purchasePaymentMethod: String?
    let purchaseOrderReference: String?
    let purchaseOrderId: String?
    let purchaseOrderNumber: Int?
    let purchaseNotes: String?

    // ── Sale Info ──
    let saleDate: String?
    let saleAmount: Double?
    let saleOrderReference: String?
    let salePaymentMethod: String?
    let saleChannel: String?
    let linkedOrderId: String?
    let platformFee: Double?

    // ── Location & Assignment ──
    let locationId: String?
    let locationName: String?
    let subLocationId: String?
    let subLocationName: String?
    let assignedEngineerId: String?
    let engineerName: String?

    // ── Creator ──
    let createdBy: String?
    let createdByName: String?
    let createdAt: String?
    let updatedAt: String?

    // ── VAT ──
    let vatReportLocked: Int?
    let vatReportMonth: String?
    let vatLiability: Double?

    // ── Listing / Storefront (merged from buyback_listing) ──
    let sellPrice: Double?
    let specialOfferPrice: Double?
    let listingCondition: String?
    let listingTitle: String?
    let listingShortDescription: String?
    let listingDescription: String?
    let listingRefurbSummary: String?
    let listingSlug: String?
    let listingGeneratedAt: String?
    let storefrontPublished: Int?
    let vatTreatment: String?

    // ── Nested Collections ──
    let refurbishmentItems: [RefurbishmentItem]?
    let images: [BuybackImage]?
    let notes: [BuybackNote]?
    let totals: BuybackTotals?

    // MARK: - Computed Properties

    var deviceDisplayName: String {
        [brand, model, storageCapacity]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var buybackStatus: BuybackStatus? {
        BuybackStatus(rawValue: status)
    }

    var isVatLocked: Bool {
        vatReportLocked == 1
    }

    var formattedPurchaseAmount: String? {
        guard let amount = purchaseAmount else { return nil }
        return CurrencyFormatter.format(amount)
    }

    var formattedSaleAmount: String? {
        guard let amount = saleAmount else { return nil }
        return CurrencyFormatter.format(amount)
    }

    var formattedSellPrice: String? {
        guard let price = sellPrice else { return nil }
        return CurrencyFormatter.format(price)
    }

    var formattedPlatformFee: String? {
        guard let fee = platformFee else { return nil }
        return CurrencyFormatter.format(fee)
    }

    static func == (lhs: BuybackDetail, rhs: BuybackDetail) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
}

// MARK: - Nested Types

struct RefurbishmentItem: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let itemType: String?      // "part", "labor", "other"
    let description: String?
    let quantity: Int?
    let unitCost: Double?
    let totalCost: Double?
    let supplier: String?
    let partNumber: String?
    let addedByName: String?
    let addedAt: String?

    var formattedTotalCost: String? {
        guard let cost = totalCost else { return nil }
        return CurrencyFormatter.format(cost)
    }

    var formattedItemType: String? {
        itemType?.capitalized
    }
}

struct BuybackImage: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let imageType: String?     // "listing", "product"
    let caption: String?
    let uploadedByName: String?
    let uploadedAt: String?
}

struct BuybackNote: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: String?            // Detail endpoint includes id; list endpoint doesn't
    let body: String?
    let createdAt: String?
    let createdBy: String?

    // Use body+createdAt as fallback ID for list (where id is nil)
    var stableId: String {
        id ?? "\(body ?? "")-\(createdAt ?? "")"
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(stableId)
    }

    static func == (lhs: BuybackNote, rhs: BuybackNote) -> Bool {
        lhs.stableId == rhs.stableId
    }
}

struct BuybackTotals: Decodable, Equatable, Sendable {
    let refurbishmentCost: Double?
    let totalCost: Double?
    let profit: Double?
    let vatLiability: Double?

    var formattedRefurbishmentCost: String? {
        guard let cost = refurbishmentCost else { return nil }
        return CurrencyFormatter.format(cost)
    }

    var formattedTotalCost: String? {
        guard let cost = totalCost else { return nil }
        return CurrencyFormatter.format(cost)
    }

    var formattedProfit: String? {
        guard let p = profit else { return nil }
        return CurrencyFormatter.format(p)
    }

    var formattedVatLiability: String? {
        guard let vat = vatLiability else { return nil }
        return CurrencyFormatter.format(vat)
    }
}
