//
//  Order.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Order List Response

/// Response wrapper for order list endpoint
struct OrderListResponse: Decodable, Sendable {
    let orders: [Order]
    let pagination: Pagination
    let filters: OrderFilters

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Orders are at the root level as an array (data is the array itself)
        // The response structure is { success, data: [orders], pagination, filters }
        // But APIClient unwraps data for us, so we receive [Order] directly
        // However, the filters come separately in the response

        // Try to decode as if this is the full response envelope
        if let ordersArray = try? container.decode([Order].self, forKey: .data) {
            self.orders = ordersArray
        } else {
            // Fallback: we're receiving just the array
            self.orders = []
        }

        self.pagination = try container.decode(Pagination.self, forKey: .pagination)
        self.filters = try container.decode(OrderFilters.self, forKey: .filters)
    }

    private enum CodingKeys: String, CodingKey {
        case data, pagination, filters
    }
}

/// Filter options for order list
struct OrderFilters: Decodable, Equatable, Sendable {
    let locations: [OrderFilterLocation]
    let users: [OrderFilterUser]
    let statuses: [String]
    let paymentStatuses: [String]
    let deviceTypes: [OrderFilterDeviceType]
}

struct OrderFilterLocation: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

struct OrderFilterUser: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

struct OrderFilterDeviceType: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let slug: String
}

// MARK: - Order

/// Main order model - supports both list and detail responses
struct Order: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let ticketId: String?
    let orderNumber: Int
    let companyId: String?

    // Nested objects
    let client: OrderClient?
    let location: OrderLocation?
    let assignedUser: OrderAssignedUser?

    // Order settings
    let intakeMethod: IntakeMethod?
    let status: OrderStatus
    let storedStatus: OrderStatus?
    let authorisationType: AuthorisationType?
    let authorisationAmount: Double?
    let authorisationNotes: String?
    let trackingNumber: String?
    let carrier: String?
    let termsConditionsSnapshot: String?

    // Line items, payments, etc. (detail only)
    let items: [OrderItem]?
    let payments: [OrderPayment]?
    let signatures: [OrderSignature]?
    let deviceSignatures: [DeviceSignature]?
    let refunds: [OrderRefund]?
    let devices: [OrderDeviceSummary]?

    // Totals (detail only)
    let totals: OrderTotals?
    let paymentStatus: PaymentStatus?

    // Dates (detail only)
    let dates: OrderDates?

    // Portal access (detail only)
    let portalAccessDisabled: Int?
    let portalAccessExpiresAt: String?

    // Related data (detail only)
    let ticket: OrderTicket?
    let company: OrderCompany?

    // List view properties (denormalized)
    let orderTotal: Double?
    let amountPaid: Double?
    let balanceDue: Double?
    let createdAt: String?
    let updatedAt: String?
    let notes: [OrderNote]?

    // MARK: - Computed Properties

    /// Display name for client
    var clientDisplayName: String {
        if let client = client {
            let name = [client.firstName, client.lastName]
                .compactMap { $0 }
                .joined(separator: " ")
            return name.isEmpty ? (client.email ?? "Unknown") : name
        }
        return "Unknown"
    }

    /// Formatted order number
    var formattedOrderNumber: String {
        "#\(orderNumber)"
    }

    /// Balance due from list or calculated from totals
    var displayBalanceDue: Double {
        if let balanceDue = balanceDue {
            return balanceDue
        }
        return totals?.balanceDue ?? 0
    }

    /// Total from list or totals object
    var displayTotal: Double {
        if let orderTotal = orderTotal {
            return orderTotal
        }
        return totals?.grandTotal ?? 0
    }

    /// Effective payment status
    var effectivePaymentStatus: PaymentStatus {
        paymentStatus ?? .unpaid
    }

    /// Formatted created date
    var formattedCreatedDate: String? {
        guard let dateStr = createdAt ?? dates?.createdAt else { return nil }
        return DateFormatters.formatRelativeDate(dateStr)
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Nested Types

struct OrderClient: Equatable, Sendable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
    let notes: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?
    let emailSuppressed: Bool?
    let emailSuppressedAt: String?
    let suppressionStatus: String?
    let suppressionError: String?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    var displayName: String {
        let name = fullName
        return name.isEmpty ? (email ?? "Unknown") : name
    }

    var fullAddress: String? {
        let parts = [addressLine1, addressLine2, city, county, postcode, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

extension OrderClient: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, email, firstName, lastName, phone, notes
        case addressLine1, addressLine2, city, county, postcode, country
        case emailSuppressed, emailSuppressedAt, suppressionStatus, suppressionError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        addressLine1 = try container.decodeIfPresent(String.self, forKey: .addressLine1)
        addressLine2 = try container.decodeIfPresent(String.self, forKey: .addressLine2)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        county = try container.decodeIfPresent(String.self, forKey: .county)
        postcode = try container.decodeIfPresent(String.self, forKey: .postcode)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        emailSuppressedAt = try container.decodeIfPresent(String.self, forKey: .emailSuppressedAt)
        suppressionStatus = try container.decodeIfPresent(String.self, forKey: .suppressionStatus)
        suppressionError = try container.decodeIfPresent(String.self, forKey: .suppressionError)

        // Handle Int-as-Bool from SQLite
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .emailSuppressed) {
            emailSuppressed = boolValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .emailSuppressed) {
            emailSuppressed = intValue != 0
        } else {
            emailSuppressed = nil
        }
    }
}

struct OrderLocation: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let postcode: String?
    let phone: String?
}

struct OrderAssignedUser: Decodable, Equatable, Sendable {
    let id: String
    let name: String
}

struct OrderItem: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let itemType: OrderItemType?
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let lineTotal: Double
    let vatAmount: Double
    let lineTotalIncVat: Double
    let deviceId: String?
    let createdAt: String?
    let authorizationStatus: String?
    let authorizationRound: Int?

    private enum CodingKeys: String, CodingKey {
        case id, itemType, description, quantity, unitPrice, vatRate
        case lineTotal, vatAmount, lineTotalIncVat, deviceId, createdAt
        case authorizationStatus, authorizationRound
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // Gracefully handle unknown item types
        itemType = try? container.decode(OrderItemType.self, forKey: .itemType)
        description = try container.decode(String.self, forKey: .description)
        quantity = try container.decode(Int.self, forKey: .quantity)
        unitPrice = try container.decode(Double.self, forKey: .unitPrice)
        vatRate = try container.decode(Double.self, forKey: .vatRate)
        lineTotal = try container.decode(Double.self, forKey: .lineTotal)
        vatAmount = try container.decode(Double.self, forKey: .vatAmount)
        lineTotalIncVat = try container.decode(Double.self, forKey: .lineTotalIncVat)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        authorizationStatus = try container.decodeIfPresent(String.self, forKey: .authorizationStatus)
        authorizationRound = try container.decodeIfPresent(Int.self, forKey: .authorizationRound)
    }

    var formattedUnitPrice: String {
        CurrencyFormatter.format(unitPrice)
    }

    var formattedLineTotal: String {
        CurrencyFormatter.format(lineTotalIncVat)
    }
}

struct OrderPayment: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let amount: Double
    let paymentMethod: PaymentMethod?
    let paymentDate: String?
    let notes: String?
    let recordedByName: String?
    let createdAt: String?
    let isDeposit: Int?
    let deviceId: String?
    let posTransactionId: String?
    let posTransactionStatus: String?
    let cardBrand: String?
    let cardLastFour: String?
    let authCode: String?
    let isRefundable: Bool?
    let totalRefunded: Double?
    let refundableAmount: Double?

    var formattedAmount: String {
        CurrencyFormatter.format(amount)
    }

    var isDepositPayment: Bool {
        isDeposit == 1
    }

    var formattedDate: String? {
        guard let date = paymentDate else { return nil }
        return DateFormatters.formatRelativeDate(date)
    }
}

struct OrderSignature: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let signatureType: SignatureType?
    let hasSignature: Bool
    let typedName: String?
    let termsAgreed: Bool?
    let capturedAt: String?
}

struct DeviceSignature: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let deviceId: String
    let deviceName: String?
    let signatureType: String?
    let signatureData: String?
    let action: String?
    let ipAddress: String?
    let userAgent: String?
    let createdAt: String?
}

struct OrderRefund: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let orderPaymentId: String?
    let amount: Double
    let refundDate: String?
    let reason: String?
    let recordedByName: String?
    let createdAt: String?

    var formattedAmount: String {
        CurrencyFormatter.format(amount)
    }
}

struct OrderDeviceSummary: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let status: String
    let workflowType: String?
    let readyForCollectionAt: String?
    let authorizationStatus: String?
    let authorizationMethod: String?
    let authorizedAt: String?
    let deposits: Double?
    let finalPaid: Double?

    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: status) ?? .deviceReceived
    }
}

struct OrderTotals: Decodable, Equatable, Sendable {
    let subtotal: Double
    let vatTotal: Double
    let grandTotal: Double
    let depositsPaid: Double?
    let finalPaymentsPaid: Double?
    let amountPaid: Double
    let totalRefunded: Double?
    let netPaid: Double?
    let balanceDue: Double

    var formattedSubtotal: String { CurrencyFormatter.format(subtotal) }
    var formattedVatTotal: String { CurrencyFormatter.format(vatTotal) }
    var formattedGrandTotal: String { CurrencyFormatter.format(grandTotal) }
    var formattedAmountPaid: String { CurrencyFormatter.format(amountPaid) }
    var formattedBalanceDue: String { CurrencyFormatter.format(balanceDue) }
}

struct OrderDates: Decodable, Equatable, Sendable {
    let createdAt: String?
    let updatedAt: String?
    let quoteSentAt: String?
    let authorisedAt: String?
    let rejectedAt: String?
    let serviceCompletedAt: String?
    let collectedAt: String?
    let despatchedAt: String?
    let readyByDate: String?
}

struct OrderTicket: Decodable, Equatable, Sendable {
    let id: String
    let subject: String?
    let status: String?
    let messages: [OrderTicketMessage]?
    let messagesCount: Int?
}

struct OrderTicketMessage: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let type: String?
    let fromEmail: String?
    let fromName: String?
    let toEmail: String?
    let subject: String?
    let bodyText: String?
    let bodyHtml: String?
    let createdAt: String?
    let createdBy: OrderTicketMessageCreator?
}

struct OrderTicketMessageCreator: Decodable, Equatable, Sendable {
    let id: String
    let firstName: String?
    let lastName: String?

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct OrderCompany: Decodable, Equatable, Sendable {
    let name: String?
    let vatNumber: String?
    let termsConditions: String?
    let logoUrl: String?
    let vatRateRepair: Double?
    let vatRateDeviceSale: Double?
    let vatRateAccessory: Double?
    let vatRateDevicePurchase: Double?
    let portalAccessDaysAfterCollection: Int?
    let depositsEnabled: Int?
}

struct OrderNote: Decodable, Equatable, Sendable {
    let body: String
    let createdAt: String?
    let createdBy: String?
    let deviceId: String?
    let deviceName: String?
}

// MARK: - Currency Formatter

enum CurrencyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.currencySymbol = "£"
        return formatter
    }()

    static func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "£\(String(format: "%.2f", value))"
    }
}
