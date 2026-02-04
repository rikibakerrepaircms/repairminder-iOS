//
//  TicketMessage.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

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

