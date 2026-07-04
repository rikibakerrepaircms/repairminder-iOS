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

// MARK: - Add device to buyback

struct AddToBuybackResponse: Decodable {
    let buybackId: String
    let serialNumber: String?
    let imei: String?
    let rmcheckRan: Bool?
    let redirectUrl: String?
}
