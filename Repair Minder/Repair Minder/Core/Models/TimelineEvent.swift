//
//  TimelineEvent.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

/// Timeline event for order tracking
struct TimelineEvent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String?
    let date: Date?
    let isCompleted: Bool
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, description, date, isCompleted, isCurrent
    }

    init(id: String, title: String, description: String? = nil, date: Date? = nil, isCompleted: Bool = false, isCurrent: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.date = date
        self.isCompleted = isCompleted
        self.isCurrent = isCurrent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isCurrent = try container.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false
    }
}
