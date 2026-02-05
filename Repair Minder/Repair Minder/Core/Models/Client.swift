//
//  Client.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Client List Response

/// Response wrapper for client list endpoint
/// Backend returns { success, data: { clients, pagination } }
struct ClientListResponse: Decodable, Sendable {
    let clients: [Client]
    let pagination: Pagination
}

// MARK: - Client

/// Client model - supports both list and detail responses
struct Client: Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let name: String?
    let phone: String?
    let notes: String?
    let countryCode: String?

    // Address (detail only)
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?

    // Social media (detail only)
    let socialFacebook: String?
    let socialInstagram: String?
    let socialTwitter: String?
    let socialLinkedin: String?
    let socialTiktok: String?
    let socialYoutube: String?
    let socialPinterest: String?
    let socialWhatsapp: String?
    let socialSnapchat: String?
    let socialThreads: String?

    // Groups
    let clientGroupId: String?
    let clientGroup: ClientGroup?
    let groups: [ClientGroupMembership]?

    // Email status (backend returns these as Int 0/1)
    let emailSuppressed: Bool?
    let emailSuppressedAt: String?
    let isGeneratedEmail: Bool?
    let marketingConsent: Bool?
    let marketingConsentAt: String?
    let marketingConsentSource: String?
    let suppressionStatus: String?
    let suppressionError: String?

    // Timestamps
    let createdAt: String?
    let updatedAt: String?
    let deletedAt: String?

    // Detail view arrays (detail only)
    let tickets: [ClientTicket]?
    let orders: [ClientOrder]?
    let devices: [ClientDevice]?

    // Stats (detail has full stats, list has denormalized)
    let stats: ClientStats?

    // List view stats (denormalized from list endpoint)
    let ticketCount: Int?
    let orderCount: Int?
    let deviceCount: Int?
    let totalSpend: Double?
    let averageSpend: Double?
    let lastContactReceived: String?
    let lastContactSent: String?

    // For list items, use clientGroupName if available
    let clientGroupName: String?

    // MARK: - Computed Properties

    /// Display name for the client
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        let fullName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return fullName.isEmpty ? email : fullName
    }

    /// Full name from first and last name
    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    /// Initials for avatar
    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        let result = first + last
        return result.isEmpty ? String(email.prefix(2)).uppercased() : result.uppercased()
    }

    /// Full formatted address
    var fullAddress: String? {
        let parts = [addressLine1, addressLine2, city, county, postcode, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Whether email is suppressed/bounced
    var isEmailSuppressed: Bool {
        emailSuppressed == true
    }

    /// Effective ticket count (from stats or list)
    var effectiveTicketCount: Int {
        stats?.ticketCount ?? ticketCount ?? 0
    }

    /// Effective order count (from stats or list)
    var effectiveOrderCount: Int {
        stats?.orderCount ?? orderCount ?? 0
    }

    /// Effective device count (from stats or list)
    var effectiveDeviceCount: Int {
        stats?.deviceCount ?? deviceCount ?? 0
    }

    /// Effective total spend (from stats or list)
    var effectiveTotalSpend: Double {
        stats?.totalSpend ?? totalSpend ?? 0
    }

    /// Effective average spend (from stats or list)
    var effectiveAverageSpend: Double {
        stats?.averageSpend ?? averageSpend ?? 0
    }

    /// Formatted total spend
    var formattedTotalSpend: String {
        CurrencyFormatter.format(effectiveTotalSpend)
    }

    /// Formatted average spend
    var formattedAverageSpend: String {
        CurrencyFormatter.format(effectiveAverageSpend)
    }

    /// Group display name
    var groupDisplayName: String? {
        clientGroup?.name ?? clientGroupName
    }

    /// Whether client has social media links
    var hasSocialMedia: Bool {
        [socialFacebook, socialInstagram, socialTwitter, socialLinkedin,
         socialTiktok, socialYoutube, socialPinterest, socialWhatsapp,
         socialSnapchat, socialThreads].contains { $0 != nil && !($0?.isEmpty ?? true) }
    }
}

// MARK: - Decodable

extension Client: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, email, firstName, lastName, name, phone, notes, countryCode
        case addressLine1, addressLine2, city, county, postcode, country
        case socialFacebook, socialInstagram, socialTwitter, socialLinkedin
        case socialTiktok, socialYoutube, socialPinterest, socialWhatsapp
        case socialSnapchat, socialThreads
        case clientGroupId, clientGroup, groups
        case emailSuppressed, emailSuppressedAt, isGeneratedEmail
        case marketingConsent, marketingConsentAt, marketingConsentSource
        case suppressionStatus, suppressionError
        case createdAt, updatedAt, deletedAt
        case tickets, orders, devices, stats
        case ticketCount, orderCount, deviceCount
        case totalSpend, averageSpend, lastContactReceived, lastContactSent
        case clientGroupName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)

        addressLine1 = try container.decodeIfPresent(String.self, forKey: .addressLine1)
        addressLine2 = try container.decodeIfPresent(String.self, forKey: .addressLine2)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        county = try container.decodeIfPresent(String.self, forKey: .county)
        postcode = try container.decodeIfPresent(String.self, forKey: .postcode)
        country = try container.decodeIfPresent(String.self, forKey: .country)

        socialFacebook = try container.decodeIfPresent(String.self, forKey: .socialFacebook)
        socialInstagram = try container.decodeIfPresent(String.self, forKey: .socialInstagram)
        socialTwitter = try container.decodeIfPresent(String.self, forKey: .socialTwitter)
        socialLinkedin = try container.decodeIfPresent(String.self, forKey: .socialLinkedin)
        socialTiktok = try container.decodeIfPresent(String.self, forKey: .socialTiktok)
        socialYoutube = try container.decodeIfPresent(String.self, forKey: .socialYoutube)
        socialPinterest = try container.decodeIfPresent(String.self, forKey: .socialPinterest)
        socialWhatsapp = try container.decodeIfPresent(String.self, forKey: .socialWhatsapp)
        socialSnapchat = try container.decodeIfPresent(String.self, forKey: .socialSnapchat)
        socialThreads = try container.decodeIfPresent(String.self, forKey: .socialThreads)

        clientGroupId = try container.decodeIfPresent(String.self, forKey: .clientGroupId)
        clientGroup = try container.decodeIfPresent(ClientGroup.self, forKey: .clientGroup)
        groups = try container.decodeIfPresent([ClientGroupMembership].self, forKey: .groups)

        // Handle Int-as-Bool fields from SQLite backend
        emailSuppressed = Self.decodeBoolFromIntOrBool(container: container, key: .emailSuppressed)
        emailSuppressedAt = try container.decodeIfPresent(String.self, forKey: .emailSuppressedAt)
        isGeneratedEmail = Self.decodeBoolFromIntOrBool(container: container, key: .isGeneratedEmail)
        marketingConsent = Self.decodeBoolFromIntOrBool(container: container, key: .marketingConsent)
        marketingConsentAt = try container.decodeIfPresent(String.self, forKey: .marketingConsentAt)
        marketingConsentSource = try container.decodeIfPresent(String.self, forKey: .marketingConsentSource)
        suppressionStatus = try container.decodeIfPresent(String.self, forKey: .suppressionStatus)
        suppressionError = try container.decodeIfPresent(String.self, forKey: .suppressionError)

        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)

        tickets = try container.decodeIfPresent([ClientTicket].self, forKey: .tickets)
        orders = try container.decodeIfPresent([ClientOrder].self, forKey: .orders)
        devices = try container.decodeIfPresent([ClientDevice].self, forKey: .devices)
        stats = try container.decodeIfPresent(ClientStats.self, forKey: .stats)

        ticketCount = try container.decodeIfPresent(Int.self, forKey: .ticketCount)
        orderCount = try container.decodeIfPresent(Int.self, forKey: .orderCount)
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount)
        totalSpend = try container.decodeIfPresent(Double.self, forKey: .totalSpend)
        averageSpend = try container.decodeIfPresent(Double.self, forKey: .averageSpend)
        lastContactReceived = try container.decodeIfPresent(String.self, forKey: .lastContactReceived)
        lastContactSent = try container.decodeIfPresent(String.self, forKey: .lastContactSent)
        clientGroupName = try container.decodeIfPresent(String.self, forKey: .clientGroupName)
    }

    /// Helper to decode Bool from either Bool or Int (0/1)
    private static func decodeBoolFromIntOrBool(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Bool? {
        // Try Bool first
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }
        // Try Int (SQLite returns 0/1)
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }
        return nil
    }
}

// MARK: - Nested Types

struct ClientGroup: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

struct ClientGroupMembership: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let groupType: String?
    let locationId: String?
    let addedAt: String?
    let addedSource: String?
}

struct ClientTicket: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let ticketNumber: Int?
    let subject: String?
    let status: String?
    let createdAt: String?

    var formattedNumber: String {
        if let num = ticketNumber {
            return "#\(num)"
        }
        return "#-"
    }
}

struct ClientOrder: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let orderNumber: Int?
    let status: String?
    let total: Double?
    let createdAt: String?

    var formattedNumber: String {
        if let num = orderNumber {
            return "#\(num)"
        }
        return "#-"
    }

    var formattedTotal: String {
        CurrencyFormatter.format(total ?? 0)
    }

    var orderStatus: OrderStatus? {
        guard let status = status else { return nil }
        return OrderStatus(rawValue: status)
    }
}

struct ClientDevice: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let orderId: String?
    let orderNumber: Int?
    let brandName: String?
    let modelName: String?
    let customBrand: String?
    let customModel: String?
    let serialNumber: String?
    let status: String?

    var displayName: String {
        let brand = customBrand ?? brandName ?? ""
        let model = customModel ?? modelName ?? ""
        let name = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Unknown Device" : name
    }

    var formattedOrderNumber: String {
        if let num = orderNumber {
            return "#\(num)"
        }
        return "#-"
    }

    var deviceStatus: DeviceStatus? {
        guard let status = status else { return nil }
        return DeviceStatus(rawValue: status)
    }
}

struct ClientStats: Decodable, Equatable, Sendable {
    let ticketCount: Int
    let orderCount: Int
    let deviceCount: Int
    let totalSpend: Double
    let averageSpend: Double
    let spendBreakdown: SpendBreakdown?
    let lastContactReceived: String?
    let lastContactSent: String?
    let avgAuthorizationHours: Double?
    let authorizationCount: Int?
    let avgRejectionHours: Double?
    let rejectionCount: Int?
    let avgCollectionHours: Double?
    let collectionCount: Int?

    var formattedTotalSpend: String {
        CurrencyFormatter.format(totalSpend)
    }

    var formattedAverageSpend: String {
        CurrencyFormatter.format(averageSpend)
    }
}

struct SpendBreakdown: Decodable, Equatable, Sendable {
    let repair: SpendCategory?
    let buyback: SpendCategory?
    let accessory: SpendCategory?
    let deviceSale: SpendCategory?
}

struct SpendCategory: Decodable, Equatable, Sendable {
    let count: Int
    let total: Double
    let average: Double

    var formattedTotal: String {
        CurrencyFormatter.format(total)
    }

    var formattedAverage: String {
        CurrencyFormatter.format(average)
    }
}
