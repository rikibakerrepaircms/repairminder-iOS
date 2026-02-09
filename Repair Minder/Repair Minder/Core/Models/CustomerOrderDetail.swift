//
//  CustomerOrderDetail.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Customer Order Detail

/// Full order detail returned from GET /api/customer/orders/:orderId
struct CustomerOrderDetail: Codable, Identifiable, Sendable {
    let id: String
    let ticketNumber: Int
    let status: String
    let createdAt: Date
    let collectedAt: Date?
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let quoteApprovedMethod: String?
    let rejectedAt: Date?
    let preAuthorization: PreAuthorization?
    let reviewLinks: ReviewLinks?
    let devices: [CustomerDevice]
    let items: [CustomerOrderItem]
    let totals: CustomerOrderTotals
    let messages: [CustomerMessage]
    let company: CustomerCompanyInfo?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, ticketNumber, status, createdAt, collectedAt
        case quoteSentAt, quoteApprovedAt, quoteApprovedMethod
        case rejectedAt, preAuthorization, reviewLinks
        case devices, items, totals, messages, company
    }

    /// Custom decoding to handle flexible date formats from API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ticketNumber = try container.decode(Int.self, forKey: .ticketNumber)
        status = try container.decode(String.self, forKey: .status)
        quoteApprovedMethod = try container.decodeIfPresent(String.self, forKey: .quoteApprovedMethod)
        preAuthorization = try container.decodeIfPresent(PreAuthorization.self, forKey: .preAuthorization)
        reviewLinks = try container.decodeIfPresent(ReviewLinks.self, forKey: .reviewLinks)
        devices = try container.decode([CustomerDevice].self, forKey: .devices)
        items = try container.decode([CustomerOrderItem].self, forKey: .items)
        totals = try container.decode(CustomerOrderTotals.self, forKey: .totals)
        messages = try container.decodeIfPresent([CustomerMessage].self, forKey: .messages) ?? []
        company = try container.decodeIfPresent(CustomerCompanyInfo.self, forKey: .company)

        // Decode dates with flexible format handling
        createdAt = Self.decodeDate(from: container, forKey: .createdAt) ?? Date()
        collectedAt = Self.decodeDate(from: container, forKey: .collectedAt)
        quoteSentAt = Self.decodeDate(from: container, forKey: .quoteSentAt)
        quoteApprovedAt = Self.decodeDate(from: container, forKey: .quoteApprovedAt)
        rejectedAt = Self.decodeDate(from: container, forKey: .rejectedAt)
    }

    /// Decode date from string with multiple format support
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key), !dateString.isEmpty else {
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

    // MARK: - Computed Properties

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

    /// Whether the order is complete (collected or despatched)
    var isComplete: Bool {
        status == "collected" || status == "despatched" || status == "collected_despatched"
    }

    /// Whether a quote has been sent
    var hasQuote: Bool {
        quoteSentAt != nil
    }

    /// Whether review links should be shown
    var shouldShowReviewLinks: Bool {
        isComplete && reviewLinks != nil
    }

    /// Formatted order reference
    var orderReference: String {
        "#\(ticketNumber)"
    }

    /// Currency code from company or default
    var currencyCode: String {
        company?.currencyCode ?? "GBP"
    }

    /// Items grouped by device ID
    func items(for deviceId: String) -> [CustomerOrderItem] {
        items.filter { $0.deviceId == deviceId }
    }

    /// Items not associated with any device
    var generalItems: [CustomerOrderItem] {
        items.filter { $0.deviceId == nil }
    }
}

// MARK: - Pre-Authorization

/// Pre-authorization details for an order (e.g., up to £200 pre-approved)
struct PreAuthorization: Codable, Sendable {
    let amount: Decimal
    let notes: String?
    let authorisedAt: Date
    let authorisedBy: AuthorisedBy?
    let signature: PreAuthSignature?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case amount, notes, authorisedAt, authorisedBy, signature
    }

    /// Custom decoding to handle numeric values and dates
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle amount as Double or Int
        if let doubleValue = try? container.decode(Double.self, forKey: .amount) {
            amount = Decimal(doubleValue)
        } else if let intValue = try? container.decode(Int.self, forKey: .amount) {
            amount = Decimal(intValue)
        } else {
            amount = 0
        }

        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        authorisedAt = Self.decodeDate(from: container, forKey: .authorisedAt) ?? Date()
        authorisedBy = try container.decodeIfPresent(AuthorisedBy.self, forKey: .authorisedBy)
        signature = try container.decodeIfPresent(PreAuthSignature.self, forKey: .signature)
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        guard let dateString = try? container.decode(String.self, forKey: key) else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateString) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: dateString)
    }
}

/// Staff member who authorised the pre-authorization
struct AuthorisedBy: Codable, Sendable {
    let firstName: String
    let lastName: String

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case firstName, lastName
    }

    var displayName: String {
        "\(firstName) \(lastName)"
    }
}

/// Pre-authorization signature (captured at drop-off)
struct PreAuthSignature: Codable, Sendable {
    let id: String
    let type: String  // "typed" or "drawn"
    let data: String?
    let typedName: String?
    let capturedAt: Date

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, type, data, typedName, capturedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        data = try container.decodeIfPresent(String.self, forKey: .data)
        typedName = try container.decodeIfPresent(String.self, forKey: .typedName)

        // Decode date from string
        if let dateString = try? container.decode(String.self, forKey: .capturedAt) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            capturedAt = iso.date(from: dateString) ?? Date()
        } else {
            capturedAt = Date()
        }
    }

    /// Whether this is a typed signature
    var isTyped: Bool {
        type == "typed" || typedName != nil
    }

    /// The signature display value (typed name or indication of drawn signature)
    var displayValue: String {
        if let typedName = typedName, !typedName.isEmpty {
            return typedName
        }
        return isTyped ? "Typed signature" : "Drawn signature"
    }
}

// MARK: - Review Links

/// Links to leave reviews after order completion
struct ReviewLinks: Codable, Sendable {
    let google: String?
    let facebook: String?
    let trustpilot: String?
    let yelp: String?
    let apple: String?

    /// Whether any review links are available
    var hasAnyLinks: Bool {
        google != nil || facebook != nil || trustpilot != nil || yelp != nil || apple != nil
    }

    /// All available review links as array
    var availableLinks: [(name: String, url: String, icon: String)] {
        var links: [(name: String, url: String, icon: String)] = []
        if let google = google { links.append(("Google", google, "star.fill")) }
        if let facebook = facebook { links.append(("Facebook", facebook, "hand.thumbsup.fill")) }
        if let trustpilot = trustpilot { links.append(("Trustpilot", trustpilot, "star.fill")) }
        if let yelp = yelp { links.append(("Yelp", yelp, "star.fill")) }
        if let apple = apple { links.append(("Apple Maps", apple, "map.fill")) }
        return links
    }
}

// MARK: - Customer Company Info

/// Company information shown in customer portal
struct CustomerCompanyInfo: Codable, Sendable {
    let name: String
    let phone: String?
    let email: String?
    let locationName: String?
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let postcode: String?
    let logoUrl: String?
    let currencyCode: String?
    let termsConditions: String?
    let collectionStorageFeeEnabled: Bool?
    let collectionRecyclingEnabled: Bool?
    let collectionStorageFeeDaily: Decimal?
    let collectionStorageFeeCap: Decimal?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case name, phone, email, locationName, addressLine1, addressLine2, city, postcode
        case logoUrl, currencyCode, termsConditions
        case collectionStorageFeeEnabled, collectionRecyclingEnabled
        case collectionStorageFeeDaily, collectionStorageFeeCap
    }

    /// Custom decoding to handle boolean and numeric fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        addressLine1 = try container.decodeIfPresent(String.self, forKey: .addressLine1)
        addressLine2 = try container.decodeIfPresent(String.self, forKey: .addressLine2)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        postcode = try container.decodeIfPresent(String.self, forKey: .postcode)
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
        termsConditions = try container.decodeIfPresent(String.self, forKey: .termsConditions)

        // Handle booleans that may come as Int
        if let boolValue = try? container.decode(Bool.self, forKey: .collectionStorageFeeEnabled) {
            collectionStorageFeeEnabled = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .collectionStorageFeeEnabled) {
            collectionStorageFeeEnabled = intValue != 0
        } else {
            collectionStorageFeeEnabled = nil
        }

        if let boolValue = try? container.decode(Bool.self, forKey: .collectionRecyclingEnabled) {
            collectionRecyclingEnabled = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .collectionRecyclingEnabled) {
            collectionRecyclingEnabled = intValue != 0
        } else {
            collectionRecyclingEnabled = nil
        }

        // Handle decimal fields
        if let doubleValue = try? container.decode(Double.self, forKey: .collectionStorageFeeDaily) {
            collectionStorageFeeDaily = Decimal(doubleValue)
        } else if let intValue = try? container.decode(Int.self, forKey: .collectionStorageFeeDaily) {
            collectionStorageFeeDaily = Decimal(intValue)
        } else {
            collectionStorageFeeDaily = nil
        }

        if let doubleValue = try? container.decode(Double.self, forKey: .collectionStorageFeeCap) {
            collectionStorageFeeCap = Decimal(doubleValue)
        } else if let intValue = try? container.decode(Int.self, forKey: .collectionStorageFeeCap) {
            collectionStorageFeeCap = Decimal(intValue)
        } else {
            collectionStorageFeeCap = nil
        }
    }

    /// Formatted address string from location fields
    var formattedAddress: String? {
        let parts = [addressLine1, addressLine2, city, postcode].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
