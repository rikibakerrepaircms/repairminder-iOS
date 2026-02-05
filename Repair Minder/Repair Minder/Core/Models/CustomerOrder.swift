//
//  CustomerOrder.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Customer Order Summary (List View)

/// Order summary returned from GET /api/customer/orders
/// Used for order list display
struct CustomerOrderSummary: Codable, Identifiable, Sendable {
    let id: String
    let ticketNumber: Int
    let status: String
    let createdAt: Date
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let rejectedAt: Date?
    let updatedAt: Date?
    let devices: [CustomerDeviceSummary]
    let totals: CustomerOrderTotals

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, ticketNumber, status, createdAt, quoteSentAt
        case quoteApprovedAt, rejectedAt, updatedAt, devices, totals
    }

    /// Custom decoding to handle flexible date formats from API
    /// API sends dates as "2025-12-20 11:36:29" or ISO8601 format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ticketNumber = try container.decode(Int.self, forKey: .ticketNumber)
        status = try container.decode(String.self, forKey: .status)
        devices = try container.decode([CustomerDeviceSummary].self, forKey: .devices)
        totals = try container.decode(CustomerOrderTotals.self, forKey: .totals)

        // Decode dates with flexible format handling
        createdAt = try Self.decodeDate(from: container, forKey: .createdAt) ?? Date()
        quoteSentAt = try Self.decodeDate(from: container, forKey: .quoteSentAt)
        quoteApprovedAt = try Self.decodeDate(from: container, forKey: .quoteApprovedAt)
        rejectedAt = try Self.decodeDate(from: container, forKey: .rejectedAt)
        updatedAt = try Self.decodeDate(from: container, forKey: .updatedAt)
    }

    /// Decode date from string with multiple format support
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
        guard let dateString = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }

        // Try ISO8601 with fractional seconds first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try ISO8601 without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try MySQL-style format "2025-12-20 11:36:29"
        let mysqlFormatter = DateFormatter()
        mysqlFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        mysqlFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = mysqlFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    /// Whether the order is awaiting customer action (approval/rejection)
    var isAwaitingAction: Bool {
        quoteSentAt != nil && quoteApprovedAt == nil && rejectedAt == nil
    }

    /// Whether the order has been approved
    var isApproved: Bool {
        quoteApprovedAt != nil
    }

    /// Whether the order has been rejected
    var isRejected: Bool {
        rejectedAt != nil
    }

    /// Primary status display text for customer
    var customerStatusLabel: String {
        if isRejected {
            return "Declined"
        }
        if isApproved {
            return "Approved"
        }
        if isAwaitingAction {
            return "Action Required"
        }
        if devices.first?.status == "device_received" {
            return "Received"
        }
        if devices.first?.status == "diagnosing" {
            return "Being Assessed"
        }
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Formatted order reference
    var orderReference: String {
        "#\(ticketNumber)"
    }
}

// MARK: - Customer Device Summary (List View)

/// Minimal device info for order list display
struct CustomerDeviceSummary: Codable, Identifiable, Sendable {
    let id: String
    let status: String
    let displayName: String

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, status, displayName
    }

    /// Parsed device status enum
    var deviceStatus: DeviceStatus? {
        DeviceStatus(rawValue: status)
    }
}

// MARK: - Customer Order Totals

/// Pricing totals for an order
struct CustomerOrderTotals: Codable, Sendable {
    let subtotal: Decimal
    let vatTotal: Decimal
    let grandTotal: Decimal
    let depositsPaid: Decimal?
    let finalPaymentsPaid: Decimal?
    let amountPaid: Decimal?
    let balanceDue: Decimal?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case subtotal, vatTotal, grandTotal, depositsPaid
        case finalPaymentsPaid, amountPaid, balanceDue
    }

    /// Custom decoding to handle numeric values that may come as Int or Double
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        subtotal = Self.decodeDecimal(from: container, forKey: .subtotal) ?? 0
        vatTotal = Self.decodeDecimal(from: container, forKey: .vatTotal) ?? 0
        grandTotal = Self.decodeDecimal(from: container, forKey: .grandTotal) ?? 0
        depositsPaid = Self.decodeDecimal(from: container, forKey: .depositsPaid)
        finalPaymentsPaid = Self.decodeDecimal(from: container, forKey: .finalPaymentsPaid)
        amountPaid = Self.decodeDecimal(from: container, forKey: .amountPaid)
        balanceDue = Self.decodeDecimal(from: container, forKey: .balanceDue)
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

    init(subtotal: Decimal, vatTotal: Decimal, grandTotal: Decimal, depositsPaid: Decimal? = nil, finalPaymentsPaid: Decimal? = nil, amountPaid: Decimal? = nil, balanceDue: Decimal? = nil) {
        self.subtotal = subtotal
        self.vatTotal = vatTotal
        self.grandTotal = grandTotal
        self.depositsPaid = depositsPaid
        self.finalPaymentsPaid = finalPaymentsPaid
        self.amountPaid = amountPaid
        self.balanceDue = balanceDue
    }
}

// MARK: - Customer Order List Response

/// Response wrapper for GET /api/customer/orders
struct CustomerOrderListResponse: Decodable {
    let orders: [CustomerOrderSummary]
    let currencyCode: String

    init(from decoder: Decoder) throws {
        // The data is the array directly, currency_code is at root level
        let container = try decoder.singleValueContainer()
        orders = try container.decode([CustomerOrderSummary].self)
        currencyCode = "GBP" // Default, will be set from APIResponse
    }

    init(orders: [CustomerOrderSummary], currencyCode: String) {
        self.orders = orders
        self.currencyCode = currencyCode
    }
}
