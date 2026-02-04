//
//  Quote.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

/// Quote model for customer approval
struct Quote: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let orderId: String
    let items: [QuoteItem]
    let subtotal: Decimal
    let vat: Decimal
    let total: Decimal
    let depositPaid: Decimal
    let balanceDue: Decimal
    let validUntil: Date?
    let notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, orderId, items, subtotal, vat, total
        case depositPaid, balanceDue, validUntil, notes, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderId = try container.decode(String.self, forKey: .orderId)
        items = try container.decodeIfPresent([QuoteItem].self, forKey: .items) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Parse date
        if let validUntilString = try? container.decode(String.self, forKey: .validUntil) {
            let formatter = ISO8601DateFormatter()
            validUntil = formatter.date(from: validUntilString)
        } else {
            validUntil = try container.decodeIfPresent(Date.self, forKey: .validUntil)
        }

        // Parse decimals
        subtotal = try Self.decodeDecimal(from: container, forKey: .subtotal) ?? 0
        vat = try Self.decodeDecimal(from: container, forKey: .vat) ?? 0
        total = try Self.decodeDecimal(from: container, forKey: .total) ?? 0
        depositPaid = try Self.decodeDecimal(from: container, forKey: .depositPaid) ?? 0
        balanceDue = try Self.decodeDecimal(from: container, forKey: .balanceDue) ?? 0
    }

    private static func decodeDecimal(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Decimal? {
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return Decimal(string: stringValue)
        } else if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }
        return nil
    }

    var isExpired: Bool {
        guard let validUntil = validUntil else { return false }
        return validUntil < Date()
    }
}

/// Individual item on a quote
struct QuoteItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let description: String
    let deviceId: String?
    let deviceName: String?
    let price: Decimal
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case id, description, deviceId, deviceName, price, quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity) ?? 1

        // Parse price
        if let priceString = try? container.decode(String.self, forKey: .price) {
            price = Decimal(string: priceString) ?? 0
        } else if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = Decimal(priceDouble)
        } else {
            price = 0
        }
    }

    var lineTotal: Decimal {
        price * Decimal(quantity)
    }
}
