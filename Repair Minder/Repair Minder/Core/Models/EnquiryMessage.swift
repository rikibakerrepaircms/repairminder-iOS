//
//  EnquiryMessage.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct EnquiryMessage: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let content: String
    let isFromStaff: Bool
    let staffId: String?
    let staffName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isFromStaff
        case staffId
        case staffName
        case createdAt
    }

    init(id: String, content: String, isFromStaff: Bool, staffId: String?, staffName: String?, createdAt: Date) {
        self.id = id
        self.content = content
        self.isFromStaff = isFromStaff
        self.staffId = staffId
        self.staffName = staffName
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isFromStaff = try container.decodeIfPresent(Bool.self, forKey: .isFromStaff) ?? false
        staffId = try container.decodeIfPresent(String.self, forKey: .staffId)
        staffName = try container.decodeIfPresent(String.self, forKey: .staffName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
