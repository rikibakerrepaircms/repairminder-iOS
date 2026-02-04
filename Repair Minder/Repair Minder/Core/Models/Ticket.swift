//
//  Ticket.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct Ticket: Identifiable, Equatable, Sendable {
    let id: String
    let ticketNumber: Int
    let subject: String
    let status: TicketStatus
    let ticketType: String?
    let clientId: String?
    let clientEmail: String?
    let clientName: String?
    let assignedUserId: String?
    let assignedFirstName: String?
    let assignedLastName: String?
    let locationId: String?
    let locId: String?
    let locName: String?
    let orderId: String?
    let orderStatus: String?
    let deviceCount: Int
    let lastClientUpdate: Date?
    let createdAt: Date
    let updatedAt: Date

    var displayRef: String {
        "#\(ticketNumber)"
    }

    // Computed property for backwards compatibility
    var assignedUserName: String? {
        [assignedFirstName, assignedLastName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
            .isEmpty ? nil : [assignedFirstName, assignedLastName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
    }
}

enum TicketStatus: String, Codable, CaseIterable, Sendable {
    case open
    case pending
    case closed
    case awaitingReply = "awaiting_reply"
    case inProgress = "in_progress"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        // Handle any unknown status gracefully
        self = TicketStatus(rawValue: rawValue) ?? .open
    }

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .closed: return "Closed"
        case .awaitingReply: return "Awaiting Reply"
        case .inProgress: return "In Progress"
        }
    }

    var colorName: String {
        switch self {
        case .open: return "green"
        case .pending: return "orange"
        case .closed: return "gray"
        case .awaitingReply: return "yellow"
        case .inProgress: return "blue"
        }
    }
}

// MARK: - Decodable
extension Ticket: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, subject, status
        case ticketNumber, ticketType
        case client, location, order
        case assignedUserId, assignedUser
        case locationId
        case lastClientUpdate
        case createdAt, updatedAt
    }

    // Nested types for backend response
    struct TicketClient: Decodable {
        let id: String
        let email: String?
        let name: String?
    }

    struct TicketLocation: Decodable {
        let id: String
        let name: String?
    }

    struct TicketOrder: Decodable {
        let id: String
        let status: String?
        let deviceCount: Int?
    }

    struct TicketAssignedUser: Decodable {
        let id: String
        let name: String?
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ticketNumber = try container.decode(Int.self, forKey: .ticketNumber)
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
        status = try container.decodeIfPresent(TicketStatus.self, forKey: .status) ?? .open
        ticketType = try container.decodeIfPresent(String.self, forKey: .ticketType)

        // Decode nested client object
        if let client = try container.decodeIfPresent(TicketClient.self, forKey: .client) {
            clientId = client.id
            clientEmail = client.email
            clientName = client.name
        } else {
            clientId = nil
            clientEmail = nil
            clientName = nil
        }

        // Decode nested assigned_user object or direct assigned_user_id
        if let assignedUser = try container.decodeIfPresent(TicketAssignedUser.self, forKey: .assignedUser) {
            assignedUserId = assignedUser.id
            // Parse name into first/last if possible
            let nameParts = assignedUser.name?.components(separatedBy: " ") ?? []
            assignedFirstName = nameParts.first
            assignedLastName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : nil
        } else {
            assignedUserId = try container.decodeIfPresent(String.self, forKey: .assignedUserId)
            assignedFirstName = nil
            assignedLastName = nil
        }

        // Decode nested location object
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        if let location = try container.decodeIfPresent(TicketLocation.self, forKey: .location) {
            locId = location.id
            locName = location.name
        } else {
            locId = nil
            locName = nil
        }

        // Decode nested order object
        if let order = try container.decodeIfPresent(TicketOrder.self, forKey: .order) {
            orderId = order.id
            orderStatus = order.status
            deviceCount = order.deviceCount ?? 0
        } else {
            orderId = nil
            orderStatus = nil
            deviceCount = 0
        }

        lastClientUpdate = Ticket.decodeOptionalDate(from: container, forKey: .lastClientUpdate)
        createdAt = Ticket.decodeOptionalDate(from: container, forKey: .createdAt) ?? Date()
        updatedAt = Ticket.decodeOptionalDate(from: container, forKey: .updatedAt) ?? Date()
    }
}

