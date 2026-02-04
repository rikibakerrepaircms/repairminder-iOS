//
//  Order.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct Order: Identifiable, Equatable, Sendable {
    let id: String
    let orderNumber: Int
    let status: OrderStatus
    let total: Decimal?
    let deposit: Decimal?
    let balance: Decimal?
    let notes: [OrderNote]?
    let clientId: String
    let clientName: String?
    let clientEmail: String?
    let clientPhone: String?
    let locationId: String?
    let locationName: String?
    let assignedUserId: String?
    let assignedUserName: String?
    let deviceCount: Int
    let createdAt: Date
    let updatedAt: Date

    struct OrderNote: Codable, Equatable, Sendable {
        let body: String?
        let createdAt: String?
        let createdBy: String?
        let deviceId: String?
        let deviceName: String?
    }

    var displayRef: String {
        "#\(orderNumber)"
    }

    var isPaid: Bool {
        (balance ?? 0) <= 0
    }
}

enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case awaitingDevice = "awaiting_device"
    case inProgress = "in_progress"
    case serviceComplete = "service_complete"
    case awaitingCollection = "awaiting_collection"
    case collectedDespatched = "collected_despatched"
    // Legacy statuses for backwards compatibility
    case bookedIn = "booked_in"
    case awaitingParts = "awaiting_parts"
    case ready = "ready"
    case collected = "collected"
    case cancelled = "cancelled"
    case complete = "complete"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = OrderStatus(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .awaitingDevice: return "Awaiting Device"
        case .inProgress: return "In Progress"
        case .serviceComplete: return "Service Complete"
        case .awaitingCollection: return "Awaiting Collection"
        case .collectedDespatched: return "Collected/Despatched"
        case .bookedIn: return "Booked In"
        case .awaitingParts: return "Awaiting Parts"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .cancelled: return "Cancelled"
        case .complete: return "Complete"
        case .unknown: return "Unknown"
        }
    }

    var colorName: String {
        switch self {
        case .awaitingDevice: return "purple"
        case .inProgress: return "orange"
        case .serviceComplete: return "blue"
        case .awaitingCollection: return "green"
        case .collectedDespatched: return "gray"
        case .bookedIn: return "blue"
        case .awaitingParts: return "yellow"
        case .ready: return "green"
        case .collected, .complete: return "gray"
        case .cancelled: return "red"
        case .unknown: return "gray"
        }
    }

    var isActive: Bool {
        switch self {
        case .awaitingDevice, .inProgress, .serviceComplete, .awaitingCollection,
             .bookedIn, .awaitingParts, .ready:
            return true
        case .collectedDespatched, .collected, .cancelled, .complete, .unknown:
            return false
        }
    }
}

// MARK: - Codable
extension Order: Codable {
    enum CodingKeys: String, CodingKey {
        case id, status, client, location, notes
        case orderNumber
        case orderTotal
        case amountPaid
        case balanceDue
        case deviceCount
        case assignedUser
        case createdAt, updatedAt
    }

    // Nested structures to match backend response
    struct ClientInfo: Decodable {
        let id: String
        let email: String?
        let firstName: String?
        let lastName: String?
        let phone: String?

        var fullName: String? {
            let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }
    }

    struct LocationInfo: Decodable {
        let id: String
        let name: String?
    }

    struct AssignedUserInfo: Decodable {
        let id: String
        let name: String?
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderNumber = try container.decode(Int.self, forKey: .orderNumber)
        status = try container.decode(OrderStatus.self, forKey: .status)
        notes = try container.decodeIfPresent([OrderNote].self, forKey: .notes)
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount) ?? 0

        // Handle SQLite datetime format "YYYY-MM-DD HH:mm:ss"
        if let createdString = try? container.decode(String.self, forKey: .createdAt),
           let parsedDate = Order.dateFormatter.date(from: createdString) {
            createdAt = parsedDate
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }

        if let updatedString = try? container.decode(String.self, forKey: .updatedAt),
           let parsedDate = Order.dateFormatter.date(from: updatedString) {
            updatedAt = parsedDate
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }

        // Decode nested client object
        let client = try container.decode(ClientInfo.self, forKey: .client)
        clientId = client.id
        clientName = client.fullName
        clientEmail = client.email
        clientPhone = client.phone

        // Decode optional nested location
        if let location = try container.decodeIfPresent(LocationInfo.self, forKey: .location) {
            locationId = location.id
            locationName = location.name
        } else {
            locationId = nil
            locationName = nil
        }

        // Decode optional nested assigned_user
        if let assignedUser = try container.decodeIfPresent(AssignedUserInfo.self, forKey: .assignedUser) {
            assignedUserId = assignedUser.id
            assignedUserName = assignedUser.name
        } else {
            assignedUserId = nil
            assignedUserName = nil
        }

        // Handle Decimal decoding from String or Double for order_total
        if let totalString = try? container.decode(String.self, forKey: .orderTotal) {
            total = Decimal(string: totalString)
        } else if let totalDouble = try? container.decode(Double.self, forKey: .orderTotal) {
            total = Decimal(totalDouble)
        } else {
            total = nil
        }

        // Handle amount_paid (deposit)
        if let paidString = try? container.decode(String.self, forKey: .amountPaid) {
            deposit = Decimal(string: paidString)
        } else if let paidDouble = try? container.decode(Double.self, forKey: .amountPaid) {
            deposit = Decimal(paidDouble)
        } else {
            deposit = nil
        }

        // Handle balance_due
        if let balanceString = try? container.decode(String.self, forKey: .balanceDue) {
            balance = Decimal(string: balanceString)
        } else if let balanceDouble = try? container.decode(Double.self, forKey: .balanceDue) {
            balance = Decimal(balanceDouble)
        } else {
            balance = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encode(status, forKey: .status)
        // Notes are read-only from API, not encoded
        try container.encode(deviceCount, forKey: .deviceCount)
        try container.encodeIfPresent(total, forKey: .orderTotal)
        try container.encodeIfPresent(deposit, forKey: .amountPaid)
        try container.encodeIfPresent(balance, forKey: .balanceDue)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

