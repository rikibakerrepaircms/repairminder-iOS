//
//  CustomerOrderItem.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Customer Order Item

/// Line item on a customer order (repair/part/service)
struct CustomerOrderItem: Codable, Identifiable, Sendable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Decimal
    let vatRate: Decimal
    let lineTotal: Decimal
    let vatAmount: Decimal
    let lineTotalIncVat: Decimal
    let deviceId: String?
    let authorizationStatus: String
    let signatureId: String?
    let authorizedPrice: Decimal?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, description, quantity, unitPrice, vatRate, lineTotal
        case vatAmount, lineTotalIncVat, deviceId, authorizationStatus
        case signatureId, authorizedPrice
    }

    /// Custom decoding to handle numeric values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)

        // Handle quantity as Int
        if let intValue = try? container.decode(Int.self, forKey: .quantity) {
            quantity = intValue
        } else if let doubleValue = try? container.decode(Double.self, forKey: .quantity) {
            quantity = Int(doubleValue)
        } else {
            quantity = 1
        }

        // Handle decimal fields
        unitPrice = Self.decodeDecimal(from: container, forKey: .unitPrice) ?? 0
        vatRate = Self.decodeDecimal(from: container, forKey: .vatRate) ?? 0
        lineTotal = Self.decodeDecimal(from: container, forKey: .lineTotal) ?? 0
        vatAmount = Self.decodeDecimal(from: container, forKey: .vatAmount) ?? 0
        lineTotalIncVat = Self.decodeDecimal(from: container, forKey: .lineTotalIncVat) ?? 0

        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        authorizationStatus = try container.decodeIfPresent(String.self, forKey: .authorizationStatus) ?? "pending"
        signatureId = try container.decodeIfPresent(String.self, forKey: .signatureId)
        authorizedPrice = Self.decodeDecimal(from: container, forKey: .authorizedPrice)
    }

    private static func decodeDecimal(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Decimal? {
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return Decimal(intValue)
        }
        return nil
    }

    // MARK: - Computed Properties

    /// Whether this item is pending authorization
    var isPending: Bool {
        authorizationStatus == "pending"
    }

    /// Whether this item has been approved
    var isApproved: Bool {
        authorizationStatus == "approved"
    }

    /// Whether this item has been rejected
    var isRejected: Bool {
        authorizationStatus == "rejected"
    }

    /// VAT rate as percentage (e.g., 20 for 20%)
    var vatPercentage: Int {
        Int((vatRate as NSDecimalNumber).doubleValue * 100)
    }

    /// Formatted VAT rate display
    var vatRateDisplay: String {
        "\(vatPercentage)%"
    }
}

// MARK: - Array Extension

extension Array where Element == CustomerOrderItem {
    /// Total of all line items (ex VAT)
    var subtotal: Decimal {
        reduce(0) { $0 + $1.lineTotal }
    }

    /// Total VAT amount
    var totalVat: Decimal {
        reduce(0) { $0 + $1.vatAmount }
    }

    /// Grand total (inc VAT)
    var grandTotal: Decimal {
        reduce(0) { $0 + $1.lineTotalIncVat }
    }

    /// Items that are pending authorization
    var pendingItems: [CustomerOrderItem] {
        filter { $0.isPending }
    }

    /// Items that have been approved
    var approvedItems: [CustomerOrderItem] {
        filter { $0.isApproved }
    }
}
