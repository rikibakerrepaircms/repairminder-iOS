//
//  TicketMessage.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData

struct TicketMessage: Identifiable, Equatable, Sendable {
    let id: String
    let ticketId: String
    let content: String
    let senderType: SenderType
    let senderName: String?
    let senderId: String?
    let isInternal: Bool
    let createdAt: Date

    var isFromStaff: Bool {
        senderType == .staff
    }
}

enum SenderType: String, Codable, Sendable {
    case staff
    case client

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Codable
extension TicketMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, content, senderType, senderName, senderId, isInternal
        case ticketId, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        ticketId = try container.decode(String.self, forKey: .ticketId)
        content = try container.decode(String.self, forKey: .content)
        senderType = try container.decode(SenderType.self, forKey: .senderType)
        senderName = try container.decodeIfPresent(String.self, forKey: .senderName)
        senderId = try container.decodeIfPresent(String.self, forKey: .senderId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Handle Int -> Bool conversion for SQLite integer booleans
        if let intValue = try? container.decode(Int.self, forKey: .isInternal) {
            isInternal = intValue != 0
        } else {
            isInternal = try container.decodeIfPresent(Bool.self, forKey: .isInternal) ?? false
        }
    }
}

// MARK: - Core Data Conversion
extension TicketMessage {
    @MainActor
    init(from entity: CDTicketMessage) {
        self.id = entity.id ?? ""
        self.ticketId = entity.ticketId ?? ""
        self.content = entity.content ?? ""
        self.senderType = SenderType(rawValue: entity.senderType ?? "") ?? .client
        self.senderName = entity.senderName
        self.senderId = entity.senderId
        self.isInternal = entity.isInternal
        self.createdAt = entity.createdAt ?? Date()
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDTicketMessage {
        let entity = CDTicketMessage(context: context)
        entity.id = id
        entity.ticketId = ticketId
        entity.content = content
        entity.senderType = senderType.rawValue
        entity.senderName = senderName
        entity.senderId = senderId
        entity.isInternal = isInternal
        entity.createdAt = createdAt
        entity.syncedAt = Date()
        entity.needsSync = false
        return entity
    }
}
