//
//  BoardService.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import Foundation

// MARK: - Board Service

/// API client for board configuration endpoints
@MainActor
enum BoardService {

    /// Fetch board columns for the given scope
    static func listColumns(scope: String = "company") async throws -> [BoardColumnModel] {
        let data: BoardColumnsData = try await APIClient.shared.request(
            .boardColumns(scope: scope)
        )
        return data.columns
    }

    /// Seed default columns for the given scope
    static func seedDefaults(scope: String = "company", copyFrom: String? = nil) async throws -> [BoardColumnModel] {
        var body: [String: String] = ["scope": scope]
        if let copyFrom = copyFrom {
            body["copyFrom"] = copyFrom
        }
        let data: BoardColumnsData = try await APIClient.shared.request(
            .boardSeedDefaults,
            body: body
        )
        return data.columns
    }

    /// Fetch card positions for the given scope
    static func listCardPositions(scope: String = "company") async throws -> [BoardCardPosition] {
        let data: BoardCardPositionsData = try await APIClient.shared.request(
            .boardCardPositions(scope: scope)
        )
        return data.positions
    }

    /// Place a card in a specific column
    static func placeCard(columnId: String, deviceId: String, scope: String = "company") async throws {
        try await APIClient.shared.requestVoid(
            .boardPlaceCard,
            body: ["column_id": columnId, "device_id": deviceId, "scope": scope]
        )
    }

    // MARK: - Device Actions (for column drop)

    /// Update device status via order endpoint
    static func updateDeviceStatus(orderId: String, deviceId: String, status: String) async throws {
        try await APIClient.shared.requestVoid(
            .updateDeviceStatus(orderId: orderId, deviceId: deviceId),
            body: ["status": status]
        )
    }

    /// Assign or clear engineer on a device
    static func updateDeviceEngineer(deviceId: String, engineerId: String?) async throws {
        let body: [String: AnyEncodable] = [
            "assigned_engineer_id": AnyEncodable(engineerId)
        ]
        try await APIClient.shared.requestVoid(
            .updateDeviceEngineer(deviceId: deviceId),
            body: body
        )
    }

    /// Set or clear sub-location on a device
    static func updateDeviceSubLocation(deviceId: String, subLocationId: String?) async throws {
        let body: [String: AnyEncodable] = [
            "sub_location_id": AnyEncodable(subLocationId)
        ]
        try await APIClient.shared.requestVoid(
            .updateDeviceSubLocation(deviceId: deviceId),
            body: body
        )
    }

    // MARK: - Column CRUD

    /// Create a new board column
    static func createColumn(title: String, scope: String, columnType: String, sortOrder: Int, color: String? = nil, icon: String? = nil) async throws -> BoardColumnModel {
        var body: [String: AnyEncodable] = [
            "title": AnyEncodable(title),
            "scope": AnyEncodable(scope),
            "column_type": AnyEncodable(columnType),
            "sort_order": AnyEncodable(sortOrder),
        ]
        if let color { body["color"] = AnyEncodable(color) }
        if let icon { body["icon"] = AnyEncodable(icon) }
        let data: BoardColumnSingleData = try await APIClient.shared.request(.boardCreateColumn, body: body)
        return data.column
    }

    /// Update column properties
    static func updateColumn(id: String, title: String? = nil, color: String? = nil, icon: String? = nil, isVisible: Bool? = nil) async throws -> BoardColumnModel {
        var body: [String: AnyEncodable] = [:]
        if let title { body["title"] = AnyEncodable(title) }
        if let color { body["color"] = AnyEncodable(color) }
        if let icon { body["icon"] = AnyEncodable(icon) }
        if let isVisible { body["is_visible"] = AnyEncodable(isVisible ? 1 : 0) }
        let data: BoardColumnSingleData = try await APIClient.shared.request(.boardUpdateColumn(id: id), body: body)
        return data.column
    }

    /// Delete a board column
    static func deleteColumn(id: String) async throws {
        try await APIClient.shared.requestVoid(.boardDeleteColumn(id: id))
    }

    /// Reorder columns by updating their sort_order
    static func reorderColumns(columnIds: [String]) async throws {
        let columns = columnIds.enumerated().map { index, id in
            ["id": AnyEncodable(id), "sort_order": AnyEncodable(index)]
        }
        try await APIClient.shared.requestVoid(.boardReorderColumns, body: ["columns": AnyEncodable(columns)])
    }

    // MARK: - Column Actions

    /// Add an action to a column
    static func createAction(columnId: String, actionType: String, actionValue: String) async throws -> BoardColumnAction {
        let body: [String: String] = [
            "action_type": actionType,
            "action_value": actionValue,
        ]
        let data: BoardActionData = try await APIClient.shared.request(.boardCreateAction(columnId: columnId), body: body)
        return data.action
    }

    /// Remove an action from a column
    static func deleteAction(columnId: String, actionId: String) async throws {
        try await APIClient.shared.requestVoid(.boardDeleteAction(columnId: columnId, actionId: actionId))
    }

    // MARK: - Pinned Preferences

    /// Fetch user's pinned column preferences
    static func fetchPinnedPreferences() async throws -> [PinnedPreference] {
        let data: BoardPinnedPreferencesData = try await APIClient.shared.request(.boardPinnedPreferences)
        return data.preferences
    }

    /// Toggle a pinned column on or off
    static func updatePinnedPreference(columnId: String, isEnabled: Bool) async throws {
        try await APIClient.shared.requestVoid(
            .boardUpdatePinnedPreference(columnId: columnId),
            body: ["is_enabled": isEnabled ? 1 : 0]
        )
    }

    // MARK: - Schedule

    /// Fetch current user's schedule for a date
    static func fetchSchedule(date: String) async throws -> [ScheduleItemModel] {
        let data: ScheduleResponseData = try await APIClient.shared.request(.schedule(date: date))
        return data.items
    }

    /// Fetch team schedule for a date (admin only), flattened into a single array
    static func fetchTeamSchedule(date: String) async throws -> [ScheduleItemModel] {
        let data: TeamScheduleResponseData = try await APIClient.shared.request(.teamSchedule(date: date))
        return data.schedules.flatMap(\.items)
    }

    /// Update a schedule item (resize duration and/or start time)
    static func updateScheduleItem(id: String, startMinutes: Int? = nil, duration: Int? = nil) async throws {
        var body: [String: AnyEncodable] = [:]
        if let startMinutes { body["startMinutes"] = AnyEncodable(startMinutes) }
        if let duration { body["duration"] = AnyEncodable(duration) }
        try await APIClient.shared.requestVoid(
            .updateScheduleItem(id: id),
            body: body
        )
    }
}
