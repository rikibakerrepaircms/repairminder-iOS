//
//  ActiveWorkItem.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Active Work Response

/// Response from `/api/devices/my-active-work`
/// Returns devices where the user has started but not completed diagnosis or repair
struct ActiveWorkResponse: Decodable, Equatable, Sendable {
    let data: [ActiveWorkItem]
}

// MARK: - Active Work Item

/// Device with in-progress work (diagnosis or repair started but not completed)
/// Note: Uses synthesized Codable with .convertFromSnakeCase decoder strategy
struct ActiveWorkItem: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let orderId: String?  // Made optional - might not be present for all items
    let orderNumber: Int  // Backend returns as Int
    let status: String
    let displayName: String
    let workType: String
    let startedAt: String

    /// Order number as String
    var orderNumberString: String { String(orderNumber) }

    /// Type of work being performed
    var activeWorkType: WorkType {
        WorkType(rawValue: workType) ?? .diagnosis
    }

    /// Parsed device status
    var deviceStatus: DeviceStatus {
        DeviceStatus(rawValue: status) ?? .diagnosing
    }

    /// How long the work has been in progress
    var duration: String {
        guard let startDate = DateFormatters.parseISO8601(startedAt) else {
            return "-"
        }

        let interval = Date().timeIntervalSince(startDate)
        let minutes = Int(interval / 60)

        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours < 24 {
            return "\(hours)h \(remainingMinutes)m"
        }

        let days = hours / 24
        let remainingHours = hours % 24
        return "\(days)d \(remainingHours)h"
    }

    /// Whether the work has been going on for a long time (> 4 hours)
    var isLongRunning: Bool {
        guard let startDate = DateFormatters.parseISO8601(startedAt) else {
            return false
        }
        let hours = Date().timeIntervalSince(startDate) / 3600
        return hours > 4
    }
}

// MARK: - Flexible String

/// Helper type for decoding values that may be Int or String
struct FlexibleString: Decodable, Equatable, Sendable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
        } else {
            value = ""
        }
    }
}

// MARK: - Work Type

/// Type of active work on a device
enum WorkType: String, Codable, Sendable {
    case diagnosis
    case repair

    var displayName: String {
        switch self {
        case .diagnosis: return "Diagnosing"
        case .repair: return "Repairing"
        }
    }

    var icon: String {
        switch self {
        case .diagnosis: return "magnifyingglass"
        case .repair: return "wrench.and.screwdriver.fill"
        }
    }

    var actionLabel: String {
        switch self {
        case .diagnosis: return "Complete Diagnosis"
        case .repair: return "Complete Repair"
        }
    }
}
