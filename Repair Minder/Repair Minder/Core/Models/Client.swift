//
//  Client.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct Client: Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let countryCode: String?
    let clientGroupId: String?
    let clientGroupName: String?
    let groups: [ClientGroup]?
    let emailSuppressed: Bool?
    let emailSuppressedAt: Date?
    let isGeneratedEmail: Bool?
    let marketingConsent: Bool?
    let ticketCount: Int
    let orderCount: Int
    let deviceCount: Int
    let totalSpend: Double
    let averageSpend: Double?
    let lastContactReceived: Date?
    let lastContactSent: Date?
    let createdAt: Date

    // Nested type for client groups
    struct ClientGroup: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let groupType: String?
    }

    var fullName: String {
        [firstName, lastName].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " ")
    }

    var displayName: String {
        if !fullName.isEmpty {
            return fullName
        }
        return email
    }

    var initials: String {
        if let first = firstName?.first, let last = lastName?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }

    // Backwards compatibility computed property
    var totalSpent: Decimal {
        Decimal(totalSpend)
    }
}

// MARK: - Codable
extension Client: Codable {
    enum CodingKeys: String, CodingKey {
        case id, email, phone
        case firstName, lastName
        case countryCode
        case clientGroupId, clientGroupName
        case groups
        case emailSuppressed, emailSuppressedAt
        case isGeneratedEmail
        case marketingConsent
        case ticketCount, orderCount, deviceCount
        case totalSpend, averageSpend
        case lastContactReceived, lastContactSent
        case createdAt
    }

    // Date formatters for various backend formats
    private static let sqliteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseDate(from string: String) -> Date? {
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        if let date = iso8601FormatterNoFraction.date(from: string) {
            return date
        }
        if let date = sqliteDateFormatter.date(from: string) {
            return date
        }
        return nil
    }

    private static func decodeOptionalDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let dateString = try? container.decode(String.self, forKey: key) {
            return parseDate(from: dateString)
        }
        return nil
    }

    // SQLite returns booleans as integers (0/1)
    private static func decodeOptionalBool(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Bool? {
        if let boolValue = try? container.decode(Bool.self, forKey: key) {
            return boolValue
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue != 0
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        clientGroupId = try container.decodeIfPresent(String.self, forKey: .clientGroupId)
        clientGroupName = try container.decodeIfPresent(String.self, forKey: .clientGroupName)
        groups = try container.decodeIfPresent([ClientGroup].self, forKey: .groups)
        emailSuppressed = Client.decodeOptionalBool(from: container, forKey: .emailSuppressed)
        emailSuppressedAt = Client.decodeOptionalDate(from: container, forKey: .emailSuppressedAt)
        isGeneratedEmail = Client.decodeOptionalBool(from: container, forKey: .isGeneratedEmail)
        marketingConsent = Client.decodeOptionalBool(from: container, forKey: .marketingConsent)
        ticketCount = try container.decodeIfPresent(Int.self, forKey: .ticketCount) ?? 0
        orderCount = try container.decodeIfPresent(Int.self, forKey: .orderCount) ?? 0
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount) ?? 0
        createdAt = Client.decodeOptionalDate(from: container, forKey: .createdAt) ?? Date()
        lastContactReceived = Client.decodeOptionalDate(from: container, forKey: .lastContactReceived)
        lastContactSent = Client.decodeOptionalDate(from: container, forKey: .lastContactSent)

        // Handle totalSpend decoding from String or Double
        if let totalString = try? container.decode(String.self, forKey: .totalSpend) {
            totalSpend = Double(totalString) ?? 0
        } else if let totalDouble = try? container.decode(Double.self, forKey: .totalSpend) {
            totalSpend = totalDouble
        } else {
            totalSpend = 0
        }

        // Handle averageSpend decoding from String or Double
        if let avgString = try? container.decode(String.self, forKey: .averageSpend) {
            averageSpend = Double(avgString)
        } else if let avgDouble = try? container.decode(Double.self, forKey: .averageSpend) {
            averageSpend = avgDouble
        } else {
            averageSpend = nil
        }
    }
}

// MARK: - Sample Data for Previews
extension Client {
    static var sample: Client {
        Client(
            id: "sample-client-1",
            email: "john@example.com",
            firstName: "John",
            lastName: "Smith",
            phone: "07123456789",
            countryCode: "GB",
            clientGroupId: nil,
            clientGroupName: "VIP",
            groups: nil,
            emailSuppressed: false,
            emailSuppressedAt: nil,
            isGeneratedEmail: false,
            marketingConsent: true,
            ticketCount: 2,
            orderCount: 5,
            deviceCount: 8,
            totalSpend: 450.0,
            averageSpend: 90.0,
            lastContactReceived: Date(),
            lastContactSent: Date(),
            createdAt: Date()
        )
    }
}

