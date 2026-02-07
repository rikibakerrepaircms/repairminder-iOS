//
//  DeviceQueueItem.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

// MARK: - My Queue Response

/// Response from `/api/devices/my-queue`
struct MyQueueResponse: Decodable, Equatable, Sendable {
    let data: [DeviceQueueItem]
    let pagination: Pagination
    let filters: QueueFilters
}

/// Filter options returned with queue response
struct QueueFilters: Decodable, Equatable, Sendable {
    let deviceTypes: [DeviceTypeOption]?
    let statuses: [String]?
    let categoryCounts: CategoryCounts?
    let engineers: [EngineerOption]?
    let locations: [LocationOption]?

    struct CategoryCounts: Decodable, Equatable, Sendable {
        let repair: Int?
        let buyback: Int?
        let unassigned: Int?

        var total: Int { (repair ?? 0) + (buyback ?? 0) + (unassigned ?? 0) }

        // Convenience initializer for defaults
        static var empty: CategoryCounts {
            CategoryCounts(repair: 0, buyback: 0, unassigned: 0)
        }

        init(repair: Int?, buyback: Int?, unassigned: Int?) {
            self.repair = repair
            self.buyback = buyback
            self.unassigned = unassigned
        }
    }
}

struct DeviceTypeOption: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let slug: String
}

struct EngineerOption: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

struct LocationOption: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Device Queue Item

/// Device item in the user's work queue
struct DeviceQueueItem: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let orderId: String?
    let ticketId: String?
    let orderNumber: Int?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let status: String
    let workflowType: String
    let deviceType: DeviceTypeInfo?
    let assignedEngineer: AssignedEngineerInfo?
    let locationId: String?
    let subLocationId: String?
    let subLocation: SubLocationInfo?
    let createdAt: String
    let dueDate: String?
    let receivedAt: String?
    let scheduled: ScheduleInfo?
    let canCompleteReport: Bool?  // Made optional - might not be present
    let canCompleteRepair: Bool?  // Made optional - might not be present
    let preTestPhotosCount: Int?  // Made optional - might not be present
    let notes: [DeviceNote]?  // Made optional - might be null or missing
    let checklist: FlexibleChecklist?  // Can be empty array [] or object
    let source: String?  // Made optional - might not be present

    /// Parsed device status enum
    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: status) ?? .deviceReceived
    }

    /// Parsed workflow type enum
    var workflow: DeviceWorkflowType {
        DeviceWorkflowType(rawValue: workflowType) ?? .repair
    }

    /// Whether this is from buyback inventory (not an order device)
    var isBuybackInventory: Bool {
        source == "buyback"
    }

    /// Safe access to canCompleteReport with default
    var canComplete: Bool {
        canCompleteReport ?? false
    }

    /// Safe access to canCompleteRepair with default
    var canRepair: Bool {
        canCompleteRepair ?? false
    }

    /// Safe access to preTestPhotosCount with default
    var photosCount: Int {
        preTestPhotosCount ?? 0
    }

    /// Safe access to notes with default empty array
    var deviceNotes: [DeviceNote] {
        notes ?? []
    }

    /// Formatted due date
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        return DateFormatters.formatRelativeDate(dueDate)
    }

    /// Formatted received date
    var formattedReceivedAt: String? {
        guard let receivedAt = receivedAt else { return nil }
        return DateFormatters.formatRelativeDate(receivedAt)
    }

    /// Whether the device is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate,
              let date = DateFormatters.parseISO8601(dueDate) else { return false }
        return date < Date()
    }

    /// Most recent note preview
    var notePreview: String? {
        deviceNotes.first?.body
    }

    /// Checklist completion percentage
    var checklistProgress: Int {
        checklist?.value?.percentComplete ?? 0
    }

    /// Next action label from checklist
    var nextAction: String? {
        checklist?.value?.nextActionLabel
    }
}

// MARK: - Nested Types

struct DeviceTypeInfo: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
}

struct AssignedEngineerInfo: Decodable, Equatable, Sendable {
    let id: String
    let name: String
}

struct SubLocationInfo: Decodable, Equatable, Sendable {
    let id: String
    let code: String
    let description: String?
    let type: String?
    let locationId: String?
}

struct ScheduleInfo: Decodable, Equatable, Sendable {
    let id: String
    let date: String
    let startMinutes: Int?
    let duration: Int?

    /// Formatted schedule time
    var formattedTime: String {
        guard let startMinutes = startMinutes else { return "Scheduled" }
        let hours = startMinutes / 60
        let mins = startMinutes % 60
        let period = hours >= 12 ? "PM" : "AM"
        let displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours)
        return String(format: "%d:%02d %@", displayHour, mins, period)
    }
}

struct DeviceNote: Decodable, Equatable, Sendable, Identifiable {
    let body: String
    let createdAt: String
    let createdBy: String?
    let deviceId: String?

    var id: String { "\(createdAt)-\(body.prefix(20))" }

    /// Whether this is a device-specific note or general order note
    var isDeviceSpecific: Bool {
        deviceId != nil
    }
}

struct DeviceChecklist: Equatable, Sendable {
    let items: [ChecklistItem]
    let percentComplete: Int
    let nextActionLabel: String?

    struct ChecklistItem: Decodable, Equatable, Sendable, Identifiable {
        let label: String
        let completed: Bool

        var id: String { label }
    }
}

extension DeviceChecklist: Decodable {
    init(from decoder: Decoder) throws {
        // First try to decode as an object
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([ChecklistItem].self, forKey: .items) ?? []
        percentComplete = try container.decodeIfPresent(Int.self, forKey: .percentComplete) ?? 0
        nextActionLabel = try container.decodeIfPresent(String.self, forKey: .nextActionLabel)
    }

    private enum CodingKeys: String, CodingKey {
        case items, percentComplete, nextActionLabel
    }
}

/// Wrapper to handle checklist that can be either an empty array or an object
struct FlexibleChecklist: Decodable, Equatable, Sendable {
    let value: DeviceChecklist?

    init(from decoder: Decoder) throws {
        // Try to decode as single value (empty array case)
        if let container = try? decoder.singleValueContainer() {
            // Check if it's an empty array by trying to decode as [String]
            if let _ = try? container.decode([String].self) {
                // It's an empty array, set to nil
                value = nil
                return
            }
        }

        // Try to decode as object
        if let checklist = try? DeviceChecklist(from: decoder) {
            value = checklist
        } else {
            value = nil
        }
    }
}

// MARK: - Queue Category Filter

/// Filter categories for my queue
enum QueueCategory: String, CaseIterable, Identifiable, Sendable {
    case all = ""
    case repair = "repair"
    case buyback = "buyback"
    case unassigned = "unassigned"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .repair: return "Repairs"
        case .buyback: return "Buyback"
        case .unassigned: return "Unassigned"
        }
    }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .repair: return "wrench.and.screwdriver"
        case .buyback: return "arrow.triangle.2.circlepath"
        case .unassigned: return "questionmark.folder"
        }
    }

    var shortLabel: String {
        switch self {
        case .all: return "All"
        case .repair: return "Repairs"
        case .buyback: return "Buyback"
        case .unassigned: return "Unassign"
        }
    }

    var color: Color {
        switch self {
        case .all: return .blue
        case .repair: return .green
        case .buyback: return .purple
        case .unassigned: return .orange
        }
    }
}

// MARK: - Date Formatters

/// Utility for parsing and formatting dates
enum DateFormatters {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let mysqlFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let humanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()

    static func parseDate(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
            ?? iso8601FormatterNoFraction.date(from: string)
            ?? mysqlFormatter.date(from: string)
    }

    static func parseISO8601(_ string: String) -> Date? {
        parseDate(string)
    }

    static func formatRelativeDate(_ string: String) -> String? {
        guard let date = parseDate(string) else { return nil }
        return formatHumanDate(date)
    }

    static func formatHumanDate(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let suffix = ordinalSuffix(for: day)
        let base = humanDateFormatter.string(from: date)
        // Insert ordinal suffix after the day number
        let parts = base.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return base }
        return "\(day)\(suffix) \(parts[1])"
    }

    private static func ordinalSuffix(for day: Int) -> String {
        switch day {
        case 11, 12, 13: return "th"
        default:
            switch day % 10 {
            case 1: return "st"
            case 2: return "nd"
            case 3: return "rd"
            default: return "th"
            }
        }
    }
}
