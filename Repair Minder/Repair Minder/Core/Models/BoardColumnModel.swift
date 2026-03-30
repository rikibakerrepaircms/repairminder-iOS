//
//  BoardColumnModel.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import Foundation

// MARK: - Board Column Model

/// Column configuration from `GET /api/board/columns`
struct BoardColumnModel: Identifiable, Sendable, Equatable {
    let id: String
    let companyId: String
    let title: String
    let columnType: String  // "status", "pinned", "custom"
    let sortOrder: Int
    let isVisible: FlexibleBool
    let icon: String?
    let color: String?
    let scope: String
    let actions: [BoardColumnAction]
}

extension BoardColumnModel: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, companyId, title, columnType, sortOrder, isVisible, icon, color, scope, actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        companyId = try container.decode(String.self, forKey: .companyId)
        title = try container.decode(String.self, forKey: .title)
        columnType = try container.decodeIfPresent(String.self, forKey: .columnType) ?? "custom"
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isVisible = try container.decodeIfPresent(FlexibleBool.self, forKey: .isVisible) ?? FlexibleBool(true)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        scope = try container.decodeIfPresent(String.self, forKey: .scope) ?? "company"
        // Gracefully handle actions decode failure — return empty array instead of crashing
        actions = (try? container.decode([BoardColumnAction].self, forKey: .actions)) ?? []
    }
}

/// Action associated with a board column (maps statuses to columns)
struct BoardColumnAction: Identifiable, Sendable, Equatable {
    let id: String
    let columnId: String?
    let actionType: String
    let actionValue: String?
    let sortOrder: Int
}

extension BoardColumnAction: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, columnId, actionType, actionValue, sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Handle id as String or Int (SQLite json_group_array may return integer)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }
        columnId = try container.decodeIfPresent(String.self, forKey: .columnId)
        actionType = try container.decodeIfPresent(String.self, forKey: .actionType) ?? ""
        actionValue = try container.decodeIfPresent(String.self, forKey: .actionValue)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

/// Card position mapping a device to a specific column
struct BoardCardPosition: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let deviceId: String
    let columnId: String
    let sortOrder: Int?
}

// MARK: - API Response Wrappers

/// Response from `GET /api/board/columns`
struct BoardColumnsData: Decodable, Sendable {
    let columns: [BoardColumnModel]
}

/// Response from `GET /api/board/card-positions`
struct BoardCardPositionsData: Decodable, Sendable {
    let positions: [BoardCardPosition]
}

// MARK: - Flexible Bool

/// Handles `is_visible` which can be Int (0/1) or Bool from the API
struct FlexibleBool: Decodable, Sendable, Equatable {
    let value: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue != 0
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = true
        }
    }

    init(_ value: Bool) {
        self.value = value
    }
}

// MARK: - Single Column Response

/// Response from `POST /api/board/columns` or `PATCH /api/board/columns/:id`
struct BoardColumnSingleData: Decodable, Sendable {
    let column: BoardColumnModel
}

/// Response from `POST /api/board/columns/:id/actions`
struct BoardActionData: Decodable, Sendable {
    let action: BoardColumnAction
}

// MARK: - Pinned Preferences

/// A user's pinned column visibility preference
struct PinnedPreference: Decodable, Sendable, Equatable {
    let columnId: String
    let isEnabled: FlexibleBool
}

/// Response from `GET /api/board/pinned-preferences`
struct BoardPinnedPreferencesData: Decodable, Sendable {
    let preferences: [PinnedPreference]
}

// MARK: - Schedule Models

/// A schedule item from the schedule API (camelCase JSON — works with .convertFromSnakeCase)
struct ScheduleItemModel: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let deviceId: String
    let orderId: String?
    let scheduleDate: String
    let startMinutes: Int
    var duration: Int
    let deviceName: String?
    let orderNumber: Int?
    let completedAt: String?
}

/// Response from `GET /api/schedule`
struct ScheduleResponseData: Decodable, Sendable {
    let date: String
    let items: [ScheduleItemModel]
}

/// A single engineer's schedule in the team schedule response
struct TeamScheduleEntry: Decodable, Sendable {
    let userId: String
    let userName: String
    let items: [ScheduleItemModel]
}

/// Response from `GET /api/schedule/team`
struct TeamScheduleResponseData: Decodable, Sendable {
    let date: String
    let schedules: [TeamScheduleEntry]
}

// MARK: - Engineer Info

/// Lightweight engineer identification for the colour legend
struct EngineerInfo: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
}
