//
//  Device.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct Device: Identifiable, Equatable, Sendable {
    let id: String
    let orderId: String?
    let ticketId: String?
    let orderNumber: Int?
    let clientFirstName: String?
    let clientLastName: String?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let status: DeviceStatus
    let workflowType: String?
    let deviceType: DeviceTypeInfo?
    let assignedEngineer: AssignedEngineer?
    let locationId: String?
    let subLocationId: String?
    let subLocation: SubLocation?
    let receivedAt: Date?
    let dueDate: Date?
    let createdAt: Date
    let notes: [DeviceNote]?
    let source: String?

    // Nested types for backend response
    struct DeviceTypeInfo: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let slug: String?
    }

    struct AssignedEngineer: Codable, Equatable, Sendable {
        let id: String
        let name: String
    }

    struct SubLocation: Codable, Equatable, Sendable {
        let id: String
        let code: String?
        let description: String?
        let type: String?
        let locationId: String?
    }

    struct DeviceNote: Codable, Equatable, Sendable {
        let body: String?
        let createdAt: String?  // Backend returns string, not Date
        let createdBy: String?
        let deviceId: String?
    }

    // Computed properties for backwards compatibility
    var clientName: String? {
        [clientFirstName, clientLastName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
            .isEmpty ? nil : [clientFirstName, clientLastName]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
    }

    var assignedUserId: String? {
        assignedEngineer?.id
    }

    var assignedUserName: String? {
        assignedEngineer?.name
    }

    var type: String {
        deviceType?.name ?? "Unknown"
    }
}

enum DeviceStatus: String, Codable, CaseIterable, Sendable {
    case received = "received"
    case bookedIn = "booked_in"
    case diagnosing = "diagnosing"
    case awaitingApproval = "awaiting_approval"
    case approved = "approved"
    case inRepair = "in_repair"
    case awaitingParts = "awaiting_parts"
    case repaired = "repaired"
    case qualityCheck = "quality_check"
    case ready = "ready"
    case repairedReady = "repaired_ready"
    case collected = "collected"
    case unrepairable = "unrepairable"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        // Handle any unknown status gracefully
        self = DeviceStatus(rawValue: rawValue) ?? .received
    }

    var displayName: String {
        switch self {
        case .received: return "Received"
        case .bookedIn: return "Booked In"
        case .diagnosing: return "Diagnosing"
        case .awaitingApproval: return "Awaiting Approval"
        case .approved: return "Approved"
        case .inRepair: return "In Repair"
        case .awaitingParts: return "Awaiting Parts"
        case .repaired: return "Repaired"
        case .qualityCheck: return "Quality Check"
        case .ready: return "Ready"
        case .repairedReady: return "Repaired & Ready"
        case .collected: return "Collected"
        case .unrepairable: return "Unrepairable"
        }
    }

    var colorName: String {
        switch self {
        case .received: return "blue"
        case .bookedIn: return "blue"
        case .diagnosing: return "purple"
        case .awaitingApproval: return "orange"
        case .approved: return "teal"
        case .inRepair: return "indigo"
        case .awaitingParts: return "yellow"
        case .repaired: return "mint"
        case .qualityCheck: return "cyan"
        case .ready: return "green"
        case .repairedReady: return "green"
        case .collected: return "gray"
        case .unrepairable: return "red"
        }
    }

    var isActive: Bool {
        switch self {
        case .collected, .unrepairable:
            return false
        default:
            return true
        }
    }
}

// MARK: - Codable
extension Device: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case orderId
        case ticketId
        case orderNumber
        case clientFirstName
        case clientLastName
        case displayName
        case serialNumber
        case imei
        case colour
        case status
        case workflowType
        case deviceType
        case assignedEngineer
        case locationId
        case subLocationId
        case subLocation
        case receivedAt
        case dueDate
        case createdAt
        case notes
        case source
    }

    // Date formatters for various backend formats
    private static let sqliteDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

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

    private static func parseDate(from string: String) -> Date? {
        // Try ISO8601 with fractional seconds first
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        // Try ISO8601 without fractional seconds
        if let date = iso8601FormatterNoFraction.date(from: string) {
            return date
        }
        // Try SQLite format
        if let date = sqliteDateFormatter.date(from: string) {
            return date
        }
        return nil
    }

    private static func decodeOptionalDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        // Try decoding as Date first (for automatic ISO8601)
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        // Try decoding as String and parsing
        if let dateString = try? container.decode(String.self, forKey: key) {
            return parseDate(from: dateString)
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderId = try container.decodeIfPresent(String.self, forKey: .orderId)
        ticketId = try container.decodeIfPresent(String.self, forKey: .ticketId)
        orderNumber = try container.decodeIfPresent(Int.self, forKey: .orderNumber)
        clientFirstName = try container.decodeIfPresent(String.self, forKey: .clientFirstName)
        clientLastName = try container.decodeIfPresent(String.self, forKey: .clientLastName)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Unknown Device"
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        imei = try container.decodeIfPresent(String.self, forKey: .imei)
        colour = try container.decodeIfPresent(String.self, forKey: .colour)
        status = try container.decodeIfPresent(DeviceStatus.self, forKey: .status) ?? .received
        workflowType = try container.decodeIfPresent(String.self, forKey: .workflowType)
        deviceType = try container.decodeIfPresent(DeviceTypeInfo.self, forKey: .deviceType)
        assignedEngineer = try container.decodeIfPresent(AssignedEngineer.self, forKey: .assignedEngineer)
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        subLocationId = try container.decodeIfPresent(String.self, forKey: .subLocationId)
        subLocation = try container.decodeIfPresent(SubLocation.self, forKey: .subLocation)

        // Handle dates that may come in various formats
        receivedAt = Device.decodeOptionalDate(from: container, forKey: .receivedAt)
        dueDate = Device.decodeOptionalDate(from: container, forKey: .dueDate)
        createdAt = Device.decodeOptionalDate(from: container, forKey: .createdAt) ?? Date()

        notes = try container.decodeIfPresent([DeviceNote].self, forKey: .notes)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }
}

// MARK: - Sample Data for Previews
extension Device {
    static var sample: Device {
        Device(
            id: "sample-device-1",
            orderId: "sample-order-1",
            ticketId: nil,
            orderNumber: 12345,
            clientFirstName: "John",
            clientLastName: "Doe",
            displayName: "Apple iPhone 14 Pro",
            serialNumber: "ABC123",
            imei: "123456789",
            colour: "Black",
            status: .inRepair,
            workflowType: "repair",
            deviceType: DeviceTypeInfo(id: "1", name: "Phone", slug: "phone"),
            assignedEngineer: AssignedEngineer(id: "user1", name: "John Smith"),
            locationId: nil,
            subLocationId: nil,
            subLocation: nil,
            receivedAt: Date(),
            dueDate: Date().addingTimeInterval(86400 * 3),
            createdAt: Date(),
            notes: nil,
            source: "order"
        )
    }

    static var sampleMacBook: Device {
        Device(
            id: "sample-device-2",
            orderId: "sample-order-1",
            ticketId: nil,
            orderNumber: 12345,
            clientFirstName: "Jane",
            clientLastName: "Smith",
            displayName: "Apple MacBook Pro 14\"",
            serialNumber: "XYZ789",
            imei: nil,
            colour: "Silver",
            status: .awaitingParts,
            workflowType: "repair",
            deviceType: DeviceTypeInfo(id: "2", name: "Laptop", slug: "laptop"),
            assignedEngineer: nil,
            locationId: nil,
            subLocationId: nil,
            subLocation: nil,
            receivedAt: Date(),
            dueDate: nil,
            createdAt: Date(),
            notes: nil,
            source: "order"
        )
    }
}

