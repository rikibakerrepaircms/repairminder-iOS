//
//  DeviceListResponse.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Device List Response

/// Response from `GET /api/devices` endpoint
/// Contains device list with pagination and filter options
struct DeviceListResponse: Decodable, Equatable, Sendable {
    let data: [DeviceListItem]
    let pagination: Pagination
    let filters: DeviceListFilters
}

// MARK: - Device List Filters

/// Filter options returned with device list
struct DeviceListFilters: Decodable, Equatable, Sendable {
    let deviceTypes: [DeviceTypeOption]?
    let engineers: [EngineerFilterInfo]?
    let locations: [LocationOption]?
    let categoryCounts: DeviceCategoryCounts?
}

/// Engineer info for filter dropdown. API returns pre-joined `{id, name}`.
struct EngineerFilterInfo: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

/// Category counts for filter tabs
struct DeviceCategoryCounts: Decodable, Equatable, Sendable {
    let repair: Int?
    let buyback: Int?
    let refurb: Int?
    let unassigned: Int?

    /// Total device count
    var total: Int {
        (repair ?? 0) + (buyback ?? 0) + (refurb ?? 0) + (unassigned ?? 0)
    }

    /// Convenience initializer for defaults
    init(repair: Int? = nil, buyback: Int? = nil, refurb: Int? = nil, unassigned: Int? = nil) {
        self.repair = repair
        self.buyback = buyback
        self.refurb = refurb
        self.unassigned = unassigned
    }
}

// MARK: - Device List Filter State

/// Current filter state for device list
struct DeviceListFilter: Equatable, Sendable {
    var page: Int = 1
    var limit: Int = 20
    var search: String = ""
    var status: String?
    var excludeStatus: String?
    var deviceTypeId: String?
    var engineerId: String?
    var locationId: String?
    var workflowCategory: WorkflowCategory = .all
    var period: DatePeriod?
    var dateFilter: DateFilterType = .created
    var showArchived: Bool = false
    var collectionStatus: CollectionStatusFilter?
    var includeBuyback: Bool = false

    /// Statuses hidden by default on the Devices LIST screen, matching the web
    /// /devices page (DEFAULT_EXCLUDED_STATUSES). Finished/gone devices are not
    /// shown unless an explicit status filter is applied.
    static let defaultExcludedStatuses = "collected,despatched,added_to_buyback"

    /// The default exclusion as an order-independent set (for comparisons).
    static let defaultExcludedStatusSet: Set<String> =
        Set(defaultExcludedStatuses.split(separator: ",").map(String.init))

    /// Statuses currently hidden from the list, parsed from `excludeStatus`.
    /// The status multi-select in the filter toggles membership of this set.
    var excludedStatusSet: Set<String> {
        Set((excludeStatus ?? "").split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    /// Default filter for the Devices LIST screen, mirroring web /devices:
    /// hides completed/collected devices AND includes buyback inventory items
    /// (ready_to_repair). Scanner and serial/IMEI lookups must NOT use this —
    /// they build a bare `DeviceListFilter()` so they can find a device in any
    /// state without pulling in buyback stock.
    static var devicesListDefault: DeviceListFilter {
        var filter = DeviceListFilter()
        filter.excludeStatus = defaultExcludedStatuses
        filter.includeBuyback = true
        return filter
    }

    /// Whether any filters are active (excluding pagination). The default
    /// exclusion is the baseline list view, so it does not count as "active".
    var hasActiveFilters: Bool {
        !search.isEmpty ||
        status != nil ||
        excludedStatusSet != Self.defaultExcludedStatusSet ||
        deviceTypeId != nil ||
        engineerId != nil ||
        locationId != nil ||
        workflowCategory != .all ||
        period != nil ||
        showArchived ||
        collectionStatus != nil
    }

    /// Reset all filters to default (keeps pagination)
    mutating func reset() {
        search = ""
        status = nil
        excludeStatus = nil
        deviceTypeId = nil
        engineerId = nil
        locationId = nil
        workflowCategory = .all
        period = nil
        dateFilter = .created
        showArchived = false
        collectionStatus = nil
        includeBuyback = false
        page = 1
    }

    /// Build URL query items for API request
    var queryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }

        // Mirrors web /devices: a single explicit `status` overrides; otherwise
        // exclude whatever statuses are unticked in the status multi-select.
        // An empty exclusion set (all statuses ticked on) sends nothing → all devices.
        if let status = status {
            items.append(URLQueryItem(name: "status", value: status))
        } else if let excludeStatus = excludeStatus, !excludeStatus.isEmpty {
            items.append(URLQueryItem(name: "exclude_status", value: excludeStatus))
        }

        if let deviceTypeId = deviceTypeId {
            items.append(URLQueryItem(name: "device_type_id", value: deviceTypeId))
        }

        if let engineerId = engineerId {
            items.append(URLQueryItem(name: "engineer_id", value: engineerId))
        }

        if let locationId = locationId {
            items.append(URLQueryItem(name: "location_id", value: locationId))
        }

        if workflowCategory != .all {
            items.append(URLQueryItem(name: "workflow_category", value: workflowCategory.rawValue))
        }

        // Match web /devices, which always requests buyback inventory alongside
        // repair devices. The buyback/refurb category tabs also imply it.
        if includeBuyback || workflowCategory == .buyback || workflowCategory == .refurb {
            items.append(URLQueryItem(name: "include_buyback", value: "true"))
        }

        if let period = period {
            items.append(URLQueryItem(name: "period", value: period.rawValue))
            items.append(URLQueryItem(name: "date_filter", value: dateFilter.rawValue))
        }

        if showArchived {
            items.append(URLQueryItem(name: "show_archived", value: "true"))
        }

        if let collectionStatus = collectionStatus {
            items.append(URLQueryItem(name: "collection_status", value: collectionStatus.rawValue))
        }

        return items
    }
}

// MARK: - Filter Enums

/// Workflow category filter
enum WorkflowCategory: String, CaseIterable, Identifiable, Sendable {
    case all = ""
    case repair = "repair"
    case buyback = "buyback"
    case refurb = "refurb"
    case unassigned = "unassigned"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .repair: return "Repairs"
        case .buyback: return "Buyback"
        case .refurb: return "Refurb"
        case .unassigned: return "Unassigned"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .repair: return "wrench.and.screwdriver"
        case .buyback: return "arrow.triangle.2.circlepath"
        case .refurb: return "arrow.clockwise"
        case .unassigned: return "questionmark.folder"
        }
    }
}

/// Date period filter
enum DatePeriod: String, CaseIterable, Identifiable, Sendable {
    case today
    case yesterday
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        }
    }
}

/// Date filter type (filter by created or completed date)
enum DateFilterType: String, CaseIterable, Identifiable, Sendable {
    case created
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .created: return "Created"
        case .completed: return "Completed"
        }
    }
}

/// Collection status filter
enum CollectionStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case awaiting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .awaiting: return "Awaiting Collection"
        }
    }
}
