//
//  BuybackWriteModels.swift
//  Repair Minder
//
//  Request/response models for the buyback lifecycle write endpoints
//  (Phase 3). All fields are snake_case on the wire — encoded/decoded via
//  `.convertToSnakeCase` / `.convertFromSnakeCase`; do not add CodingKeys.
//

import Foundation

// MARK: - Status

struct BuybackStatusRequest: Encodable {
    var status: String
}

struct BuybackStatusResponse: Decodable {
    let previousStatus: String
    let newStatus: String
    let message: String?
}

// MARK: - Notes

struct AddBuybackNoteRequest: Encodable {
    var body: String
}

// MARK: - Sell

struct SellBuybackRequest: Encodable {
    var salePrice: Double?
    var locationId: String?
    var saleChannel: String?     // "direct" | "ebay" | "shopify"
    var clientId: String?
    var firstName: String?
    var lastName: String?
    var clientEmail: String?
    var clientPhone: String?
    var noEmail: Bool?
}

struct SellBuybackResponse: Decodable {
    let orderId: String
    let orderTicketId: String?
    let salePrice: Double?
    let vatLiability: Double?
}

// MARK: - Bulk Sell

struct BulkSellItemRequest: Encodable {
    var id: String
    var salePrice: Double
    var platformFee: Double?
}

struct BulkSellRequest: Encodable {
    var items: [BulkSellItemRequest]
    var clientId: String?
    var firstName: String?
    var lastName: String?
    var clientEmail: String?
    var clientPhone: String?
    var noEmail: Bool?
    var saleChannel: String?     // "direct" | "ebay" | "shopify" — default "direct"
}

struct BulkSellResponse: Decodable {
    let orderId: String
    let orderTicketId: String?
    let ticketNumber: String?
    let itemsSold: Int?
    let totalSaleAmount: Double?
}

// MARK: - Add device to buyback

struct AddToBuybackResponse: Decodable {
    let buybackId: String
    let serialNumber: String?
    let imei: String?
    let rmcheckRan: Bool?
    let redirectUrl: String?
}

// MARK: - Refurbishment Items

struct AddRefurbishmentRequest: Encodable {
    var itemType: String        // "part" | "labor" | "other"
    var description: String
    var unitCost: Double
    var quantity: Int
    var partNumber: String?
    var supplier: String?
}

struct UpdateRefurbishmentRequest: Encodable {
    var description: String?
    var quantity: Int?
    var unitCost: Double?
    var partNumber: String?
    var supplier: String?
}

struct RefurbishmentMutationResponse: Decodable {
    let id: String?
    let totalCost: Double?
    let newTotalRefurbishmentCost: Double?
}
