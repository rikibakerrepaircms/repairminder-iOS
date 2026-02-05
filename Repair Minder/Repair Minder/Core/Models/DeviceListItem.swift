//
//  DeviceListItem.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Device List Item

/// A device item as returned by the device list endpoint (`GET /api/devices`)
/// This is a lightweight representation for list views
struct DeviceListItem: Decodable, Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let orderId: String?  // Made optional - buyback items might not have an order
    let ticketId: String?
    let orderNumber: String?
    let clientFirstName: String?
    let clientLastName: String?
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
    let receivedAt: String?
    let dueDate: String?
    let createdAt: String
    let notes: [DeviceNote]?  // Made optional - might be null or missing
    let source: String?  // Made optional - might not be present

    /// Computed client name from first and last name
    var clientName: String? {
        guard let first = clientFirstName else { return nil }
        return "\(first) \(clientLastName ?? "")".trimmingCharacters(in: .whitespaces)
    }

    /// Parsed device status enum
    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: status) ?? .deviceReceived
    }

    /// Parsed workflow type enum
    var workflow: DeviceWorkflowType {
        DeviceWorkflowType(rawValue: workflowType) ?? .repair
    }

    /// Whether this device is overdue based on due date
    var isOverdue: Bool {
        guard let dueDate = dueDate,
              let date = DateFormatters.parseISO8601(dueDate) else { return false }
        return date < Date() && !deviceStatus.isTerminal
    }

    /// Whether this is from buyback inventory
    var isBuybackInventory: Bool {
        source == "buyback_inventory" || source == "buyback"
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

    /// Most recent note preview
    var notePreview: String? {
        notes?.first?.body
    }

    /// Safe access to notes with default empty array
    var deviceNotes: [DeviceNote] {
        notes ?? []
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Device Source

/// Source of device (order or buyback inventory)
enum DeviceSource: String, Decodable, Sendable {
    case order
    case buybackInventory = "buyback_inventory"
}
