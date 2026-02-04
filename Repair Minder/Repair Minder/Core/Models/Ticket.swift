//
//  Ticket.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData

struct Ticket: Identifiable, Equatable, Sendable {
    let id: String
    let ticketNumber: Int
    let subject: String
    let status: TicketStatus
    let priority: String?
    let clientId: String?
    let clientEmail: String
    let clientName: String?
    let assignedUserId: String?
    let assignedUserName: String?
    let orderId: String?
    let orderRef: String?
    let messageCount: Int
    let lastMessageAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var displayRef: String {
        "#\(ticketNumber)"
    }
}

enum TicketStatus: String, Codable, CaseIterable, Sendable {
    case open
    case pending
    case closed

    var displayName: String {
        rawValue.capitalized
    }

    var colorName: String {
        switch self {
        case .open: return "green"
        case .pending: return "orange"
        case .closed: return "gray"
        }
    }
}

// MARK: - Codable
extension Ticket: Codable {
    enum CodingKeys: String, CodingKey {
        case id, subject, status, priority
        case ticketNumber, clientId, clientEmail, clientName
        case assignedUserId, assignedUserName
        case orderId, orderRef, messageCount, lastMessageAt
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ticketNumber = try container.decode(Int.self, forKey: .ticketNumber)
        subject = try container.decode(String.self, forKey: .subject)
        status = try container.decode(TicketStatus.self, forKey: .status)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        clientId = try container.decodeIfPresent(String.self, forKey: .clientId)
        clientEmail = try container.decode(String.self, forKey: .clientEmail)
        clientName = try container.decodeIfPresent(String.self, forKey: .clientName)
        assignedUserId = try container.decodeIfPresent(String.self, forKey: .assignedUserId)
        assignedUserName = try container.decodeIfPresent(String.self, forKey: .assignedUserName)
        orderId = try container.decodeIfPresent(String.self, forKey: .orderId)
        orderRef = try container.decodeIfPresent(String.self, forKey: .orderRef)
        messageCount = try container.decodeIfPresent(Int.self, forKey: .messageCount) ?? 0
        lastMessageAt = try container.decodeIfPresent(Date.self, forKey: .lastMessageAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Core Data Conversion
extension Ticket {
    @MainActor
    init(from entity: CDTicket) {
        self.id = entity.id ?? ""
        self.ticketNumber = Int(entity.ticketNumber)
        self.subject = entity.subject ?? ""
        self.status = TicketStatus(rawValue: entity.status ?? "") ?? .open
        self.priority = entity.priority
        self.clientId = entity.clientId
        self.clientEmail = entity.clientEmail ?? ""
        self.clientName = entity.clientName
        self.assignedUserId = entity.assignedUserId
        self.assignedUserName = nil
        self.orderId = entity.orderId
        self.orderRef = nil
        self.messageCount = entity.messages?.count ?? 0
        self.lastMessageAt = entity.lastMessageAt
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDTicket {
        let entity = CDTicket(context: context)
        entity.id = id
        entity.ticketNumber = Int32(ticketNumber)
        entity.subject = subject
        entity.status = status.rawValue
        entity.priority = priority
        entity.clientId = clientId
        entity.clientEmail = clientEmail
        entity.clientName = clientName
        entity.assignedUserId = assignedUserId
        entity.orderId = orderId
        entity.lastMessageAt = lastMessageAt
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.syncedAt = Date()
        return entity
    }
}
