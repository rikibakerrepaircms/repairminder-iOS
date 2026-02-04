//
//  Order.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData

struct Order: Identifiable, Equatable, Sendable {
    let id: String
    let orderNumber: Int
    let status: OrderStatus
    let total: Decimal?
    let deposit: Decimal?
    let balance: Decimal?
    let notes: String?
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

    var displayRef: String {
        "#\(orderNumber)"
    }

    var isPaid: Bool {
        (balance ?? 0) <= 0
    }
}

enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case bookedIn = "booked_in"
    case inProgress = "in_progress"
    case awaitingParts = "awaiting_parts"
    case ready = "ready"
    case collected = "collected"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .bookedIn: return "Booked In"
        case .inProgress: return "In Progress"
        case .awaitingParts: return "Awaiting Parts"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .cancelled: return "Cancelled"
        }
    }

    var colorName: String {
        switch self {
        case .bookedIn: return "blue"
        case .inProgress: return "orange"
        case .awaitingParts: return "yellow"
        case .ready: return "green"
        case .collected: return "gray"
        case .cancelled: return "red"
        }
    }

    var isActive: Bool {
        switch self {
        case .bookedIn, .inProgress, .awaitingParts, .ready:
            return true
        case .collected, .cancelled:
            return false
        }
    }
}

// MARK: - Codable
extension Order: Codable {
    enum CodingKeys: String, CodingKey {
        case id, status, total, deposit, balance, notes
        case orderNumber, clientId, clientName, clientEmail, clientPhone
        case locationId, locationName, assignedUserId, assignedUserName
        case deviceCount, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderNumber = try container.decode(Int.self, forKey: .orderNumber)
        status = try container.decode(OrderStatus.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        clientId = try container.decode(String.self, forKey: .clientId)
        clientName = try container.decodeIfPresent(String.self, forKey: .clientName)
        clientEmail = try container.decodeIfPresent(String.self, forKey: .clientEmail)
        clientPhone = try container.decodeIfPresent(String.self, forKey: .clientPhone)
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        assignedUserId = try container.decodeIfPresent(String.self, forKey: .assignedUserId)
        assignedUserName = try container.decodeIfPresent(String.self, forKey: .assignedUserName)
        deviceCount = try container.decodeIfPresent(Int.self, forKey: .deviceCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Handle Decimal decoding from String or Double
        if let totalString = try? container.decode(String.self, forKey: .total) {
            total = Decimal(string: totalString)
        } else if let totalDouble = try? container.decode(Double.self, forKey: .total) {
            total = Decimal(totalDouble)
        } else {
            total = nil
        }

        if let depositString = try? container.decode(String.self, forKey: .deposit) {
            deposit = Decimal(string: depositString)
        } else if let depositDouble = try? container.decode(Double.self, forKey: .deposit) {
            deposit = Decimal(depositDouble)
        } else {
            deposit = nil
        }

        if let balanceString = try? container.decode(String.self, forKey: .balance) {
            balance = Decimal(string: balanceString)
        } else if let balanceDouble = try? container.decode(Double.self, forKey: .balance) {
            balance = Decimal(balanceDouble)
        } else {
            balance = nil
        }
    }
}

// MARK: - Core Data Conversion
extension Order {
    @MainActor
    init(from entity: CDOrder) {
        self.id = entity.id ?? ""
        self.orderNumber = Int(entity.orderNumber)
        self.status = OrderStatus(rawValue: entity.status ?? "") ?? .bookedIn
        self.total = entity.total as Decimal?
        self.deposit = entity.deposit as Decimal?
        self.balance = entity.balance as Decimal?
        self.notes = entity.notes
        self.clientId = entity.clientId ?? ""
        self.clientName = entity.client?.fullName
        self.clientEmail = entity.client?.email
        self.clientPhone = entity.client?.phone
        self.locationId = entity.locationId
        self.locationName = nil
        self.assignedUserId = entity.assignedUserId
        self.assignedUserName = nil
        self.deviceCount = entity.devices?.count ?? 0
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDOrder {
        let entity = CDOrder(context: context)
        entity.id = id
        entity.orderNumber = Int32(orderNumber)
        entity.status = status.rawValue
        entity.total = total as NSDecimalNumber?
        entity.deposit = deposit as NSDecimalNumber?
        entity.balance = balance as NSDecimalNumber?
        entity.notes = notes
        entity.clientId = clientId
        entity.locationId = locationId
        entity.assignedUserId = assignedUserId
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.syncedAt = Date()
        entity.needsSync = false
        return entity
    }
}
