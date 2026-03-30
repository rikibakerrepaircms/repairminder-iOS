//
//  BoardViewModel.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Board Device Item

/// A device displayed on the board, usable with both DeviceListItem and DeviceQueueItem
struct BoardDeviceItem: Identifiable, Sendable, Equatable {
    let id: String
    let orderId: String?
    let orderNumber: String?
    let displayName: String
    let status: String
    let engineerId: String?
    let engineerName: String?
    let dueDate: String?
    let workflowType: String
    let serialNumber: String?
    let imei: String?
    let notePreview: String?
    let source: String?
    let canCompleteRepair: Bool

    /// Whether this device is actively being worked on
    var isInProgress: Bool {
        status == "repairing" || status == "diagnosing"
    }

    /// Formatted due date
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        return DateFormatters.formatRelativeDate(dueDate)
    }

    /// Parsed device status
    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: status) ?? .deviceReceived
    }

    /// Whether this is a buyback device
    var isBuyback: Bool {
        source == "buyback" || source == "buyback_inventory"
    }

    /// Initialize from a DeviceListItem
    init(from device: DeviceListItem) {
        self.id = device.id
        self.orderId = device.orderId
        self.orderNumber = device.orderNumber
        self.displayName = device.displayName
        self.status = device.status
        self.engineerId = device.assignedEngineer?.id
        self.engineerName = device.assignedEngineer?.name
        self.dueDate = device.dueDate
        self.workflowType = device.workflowType
        self.serialNumber = device.serialNumber
        self.imei = device.imei
        self.notePreview = device.notePreview
        self.source = device.source
        self.canCompleteRepair = false
    }

    /// Initialize from a DeviceQueueItem
    init(from device: DeviceQueueItem) {
        self.id = device.id
        self.orderId = device.orderId
        self.orderNumber = device.orderNumber.map { String($0) }
        self.displayName = device.displayName
        self.status = device.status
        self.engineerId = device.assignedEngineer?.id
        self.engineerName = device.assignedEngineer?.name
        self.dueDate = device.dueDate
        self.workflowType = device.workflowType
        self.serialNumber = device.serialNumber
        self.imei = device.imei
        self.notePreview = device.notes?.first?.body
        self.source = device.source
        self.canCompleteRepair = device.canCompleteRepair ?? false
    }
}

// MARK: - Board Column Data

/// A column with its grouped devices, ready for display
struct BoardColumnData: Identifiable, Sendable, Equatable {
    let id: String
    let column: BoardColumnModel
    var devices: [BoardDeviceItem]

    var count: Int { devices.count }
    var isEmpty: Bool { devices.isEmpty }
}

// MARK: - Board View Model

/// Manages board state: columns, device grouping, card positions, and drag-drop actions
@MainActor
@Observable
final class BoardViewModel {

    // MARK: - State

    var columnData: [BoardColumnData] = []
    var isLoading = false
    var error: String?

    /// Callback to refresh devices after a column action
    var onDevicesChanged: (() -> Void)?

    // MARK: - Timeline & Legend State

    /// Schedule items for today (for timeline column)
    var scheduleItems: [ScheduleItemModel] = []

    /// Unique engineers extracted from all devices (for colour legend)
    var engineers: [EngineerInfo] = []

    /// All devices passed to the board (needed for timeline matching)
    var allDevices: [BoardDeviceItem] = []

    /// All columns (exposed for ListBuilderSheet)
    var columns: [BoardColumnModel] = []

    /// Board scope (exposed for ListBuilderSheet)
    private(set) var scope: String

    // MARK: - Private State

    private var cardPositions: [BoardCardPosition] = []

    // MARK: - Init

    init(scope: String = "company") {
        self.scope = scope
    }

    // MARK: - Computed Properties

    /// The pinned timeline column (if visible)
    var timelineColumn: BoardColumnModel? {
        columns.first { $0.columnType == "pinned" && $0.isVisible.value }
    }

    // MARK: - Public Methods

    /// Load board configuration (columns + card positions), then group provided devices
    func loadBoard(devices: [BoardDeviceItem]) async {
        isLoading = true
        error = nil
        allDevices = devices

        do {
            // Fetch columns and card positions in parallel
            async let columnsTask = BoardService.listColumns(scope: scope)
            async let positionsTask = BoardService.listCardPositions(scope: scope)

            var cols = try await columnsTask
            let positions = try await positionsTask

            // Auto-seed if no columns exist (company scope only)
            if cols.isEmpty {
                if scope == "company" {
                    cols = try await BoardService.seedDefaults(scope: scope)
                }
            }

            self.columns = cols
            self.cardPositions = positions

            groupDevices(devices)
            extractEngineers(from: devices)
        } catch {
            self.error = "Failed to load board: \(error.localizedDescription)"
            #if DEBUG
            print("Board load error: \(error)")
            #endif
        }

        isLoading = false

        // Load schedule in background (don't block main board load)
        Task { await loadSchedule() }
    }

    /// Re-group devices into columns (e.g., after a device list refresh)
    func updateDevices(_ devices: [BoardDeviceItem]) {
        guard !columns.isEmpty else { return }
        allDevices = devices
        groupDevices(devices)
        extractEngineers(from: devices)
    }

    /// Seed defaults for user scope from company board
    func seedFromCompany() async {
        isLoading = true
        do {
            let cols = try await BoardService.seedDefaults(scope: scope, copyFrom: "company")
            self.columns = cols
        } catch {
            self.error = "Failed to set up board"
        }
        isLoading = false
    }

    /// Whether the board needs setup (user scope, no columns)
    var needsSetup: Bool {
        scope == "user" && columns.isEmpty && !isLoading
    }

    // MARK: - Schedule

    /// Load schedule items for today
    func loadSchedule() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())

        do {
            if scope == "company" {
                // Try team schedule first (admin-only); fall back to user schedule
                do {
                    scheduleItems = try await BoardService.fetchTeamSchedule(date: dateString)
                } catch {
                    scheduleItems = try await BoardService.fetchSchedule(date: dateString)
                }
            } else {
                scheduleItems = try await BoardService.fetchSchedule(date: dateString)
            }
        } catch {
            // Schedule is optional — don't show error to user
            #if DEBUG
            print("Schedule load error: \(error)")
            #endif
        }
    }

    // MARK: - Column Management

    /// Reload columns from API (after CRUD operations in list builder)
    func reloadColumns() async {
        do {
            columns = try await BoardService.listColumns(scope: scope)
            groupDevices(allDevices)
        } catch {
            #if DEBUG
            print("Reload columns error: \(error)")
            #endif
        }
    }

    /// ID of a newly scheduled item (for auto-expand on timeline)
    var newlyScheduledId: String?

    /// Update a schedule item's duration (from timeline card bottom resize)
    func updateScheduleDuration(itemId: String, duration: Int) async {
        // Optimistic update
        if let idx = scheduleItems.firstIndex(where: { $0.id == itemId }) {
            scheduleItems[idx].duration = duration
        }

        do {
            try await BoardService.updateScheduleItem(id: itemId, duration: duration)
        } catch {
            await loadSchedule()
        }
    }

    /// Update a schedule item's start time and duration (from timeline card top resize)
    func updateScheduleStartTime(itemId: String, startMinutes: Int, duration: Int) async {
        // Optimistic update
        if let idx = scheduleItems.firstIndex(where: { $0.id == itemId }) {
            scheduleItems[idx] = ScheduleItemModel(
                id: scheduleItems[idx].id,
                deviceId: scheduleItems[idx].deviceId,
                orderId: scheduleItems[idx].orderId,
                scheduleDate: scheduleItems[idx].scheduleDate,
                startMinutes: startMinutes,
                duration: duration,
                deviceName: scheduleItems[idx].deviceName,
                orderNumber: scheduleItems[idx].orderNumber,
                completedAt: scheduleItems[idx].completedAt
            )
        }

        do {
            try await BoardService.updateScheduleItem(id: itemId, startMinutes: startMinutes, duration: duration)
        } catch {
            await loadSchedule()
        }
    }

    // MARK: - Drag & Drop

    /// Move a device from one column to another, executing column actions
    /// Returns true on success, false on failure (card is reverted)
    func moveDevice(_ device: BoardDeviceItem, fromColumnId: String, toColumnId: String) async -> Bool {
        // Don't do anything if dropped on same column
        guard fromColumnId != toColumnId else { return false }

        // Find target column
        guard let targetColumnIndex = columnData.firstIndex(where: { $0.id == toColumnId }),
              let sourceColumnIndex = columnData.firstIndex(where: { $0.id == fromColumnId }) else {
            return false
        }

        let targetColumn = columnData[targetColumnIndex]

        // 1. Optimistic: move card immediately
        if let deviceIndex = columnData[sourceColumnIndex].devices.firstIndex(where: { $0.id == device.id }) {
            columnData[sourceColumnIndex].devices.remove(at: deviceIndex)
        }
        columnData[targetColumnIndex].devices.append(device)

        // 2. Execute actions
        do {
            // Place card position
            try await BoardService.placeCard(
                columnId: toColumnId,
                deviceId: device.id,
                scope: scope
            )

            // Execute column actions
            for action in targetColumn.column.actions {
                try await executeAction(action, device: device)
            }

            // Refresh devices to get updated state
            onDevicesChanged?()
            return true
        } catch {
            #if DEBUG
            print("Column action failed: \(error)")
            #endif

            // 3. Revert: move card back
            if let deviceIndex = columnData[targetColumnIndex].devices.firstIndex(where: { $0.id == device.id }) {
                columnData[targetColumnIndex].devices.remove(at: deviceIndex)
            }
            columnData[sourceColumnIndex].devices.append(device)

            return false
        }
    }

    // MARK: - Private Methods

    /// Execute a single column action on a device
    private func executeAction(_ action: BoardColumnAction, device: BoardDeviceItem) async throws {
        switch action.actionType {
        case "set_status":
            if device.isBuyback {
                // Buyback status uses a different endpoint — not implemented in iOS yet
                // Skip silently for now
            } else if let orderId = device.orderId, let value = action.actionValue {
                try await BoardService.updateDeviceStatus(
                    orderId: orderId,
                    deviceId: device.id,
                    status: value
                )
            }

        case "set_engineer":
            try await BoardService.updateDeviceEngineer(
                deviceId: device.id,
                engineerId: action.actionValue
            )

        case "clear_engineer":
            try await BoardService.updateDeviceEngineer(
                deviceId: device.id,
                engineerId: nil
            )

        case "set_sub_location":
            try await BoardService.updateDeviceSubLocation(
                deviceId: device.id,
                subLocationId: action.actionValue
            )

        case "clear_sub_location":
            try await BoardService.updateDeviceSubLocation(
                deviceId: device.id,
                subLocationId: nil
            )

        default:
            break
        }
    }

    /// Group devices into columns based on card positions and status-action matching
    private func groupDevices(_ devices: [BoardDeviceItem]) {
        // Build lookup: deviceId -> columnId from card positions
        let positionMap = Dictionary(
            cardPositions.map { ($0.deviceId, $0.columnId) },
            uniquingKeysWith: { _, last in last }
        )

        // Build lookup: status -> columnId from column actions
        var statusToColumnId: [String: String] = [:]
        for column in columns {
            for action in column.actions where action.actionType == "set_status" {
                if let value = action.actionValue {
                    statusToColumnId[value] = column.id
                }
            }
        }

        // Sort columns by sort_order, filter visible only
        let visibleColumns = columns
            .filter { $0.isVisible.value }
            .sorted { $0.sortOrder < $1.sortOrder }

        // Group devices into columns
        var columnDevices: [String: [BoardDeviceItem]] = [:]
        for column in visibleColumns {
            columnDevices[column.id] = []
        }

        for device in devices {
            // Priority 1: Explicit card position
            if let columnId = positionMap[device.id],
               columnDevices[columnId] != nil {
                columnDevices[columnId]?.append(device)
                continue
            }

            // Priority 2: Status-based matching
            if let columnId = statusToColumnId[device.status],
               columnDevices[columnId] != nil {
                columnDevices[columnId]?.append(device)
            }
            // Devices that don't match any column are silently dropped
        }

        // Build column data
        columnData = visibleColumns.map { column in
            BoardColumnData(
                id: column.id,
                column: column,
                devices: columnDevices[column.id] ?? []
            )
        }
    }

    /// Extract unique engineers from devices for the colour legend
    private func extractEngineers(from devices: [BoardDeviceItem]) {
        var seen = Set<String>()
        var result: [EngineerInfo] = []
        for device in devices {
            if let id = device.engineerId, let name = device.engineerName, !seen.contains(id) {
                seen.insert(id)
                result.append(EngineerInfo(id: id, name: name))
            }
        }
        engineers = result
    }
}
