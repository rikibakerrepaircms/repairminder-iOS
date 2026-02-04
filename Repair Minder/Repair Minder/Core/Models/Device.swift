//
//  Device.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData

struct Device: Identifiable, Equatable, Sendable {
    let id: String
    let orderId: String
    let type: String
    let brand: String?
    let model: String?
    let serial: String?
    let imei: String?
    let passcode: String?
    let status: DeviceStatus
    let issue: String?
    let diagnosis: String?
    let resolution: String?
    let price: Decimal?
    let assignedUserId: String?
    let assignedUserName: String?
    let createdAt: Date
    let updatedAt: Date

    var displayName: String {
        if let brand = brand, let model = model, !brand.isEmpty, !model.isEmpty {
            return "\(brand) \(model)"
        }
        return type
    }
}

enum DeviceStatus: String, Codable, CaseIterable, Sendable {
    case bookedIn = "booked_in"
    case diagnosing = "diagnosing"
    case awaitingApproval = "awaiting_approval"
    case approved = "approved"
    case inRepair = "in_repair"
    case awaitingParts = "awaiting_parts"
    case repaired = "repaired"
    case qualityCheck = "quality_check"
    case ready = "ready"
    case collected = "collected"
    case unrepairable = "unrepairable"

    var displayName: String {
        switch self {
        case .bookedIn: return "Booked In"
        case .diagnosing: return "Diagnosing"
        case .awaitingApproval: return "Awaiting Approval"
        case .approved: return "Approved"
        case .inRepair: return "In Repair"
        case .awaitingParts: return "Awaiting Parts"
        case .repaired: return "Repaired"
        case .qualityCheck: return "Quality Check"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .unrepairable: return "Unrepairable"
        }
    }

    var colorName: String {
        switch self {
        case .bookedIn: return "blue"
        case .diagnosing: return "purple"
        case .awaitingApproval: return "orange"
        case .approved: return "teal"
        case .inRepair: return "indigo"
        case .awaitingParts: return "yellow"
        case .repaired: return "mint"
        case .qualityCheck: return "cyan"
        case .ready: return "green"
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
        case id, type, brand, model, serial, imei, passcode, status
        case issue, diagnosis, resolution, price
        case orderId, assignedUserId, assignedUserName
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderId = try container.decode(String.self, forKey: .orderId)
        type = try container.decode(String.self, forKey: .type)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        serial = try container.decodeIfPresent(String.self, forKey: .serial)
        imei = try container.decodeIfPresent(String.self, forKey: .imei)
        passcode = try container.decodeIfPresent(String.self, forKey: .passcode)
        status = try container.decode(DeviceStatus.self, forKey: .status)
        issue = try container.decodeIfPresent(String.self, forKey: .issue)
        diagnosis = try container.decodeIfPresent(String.self, forKey: .diagnosis)
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution)
        assignedUserId = try container.decodeIfPresent(String.self, forKey: .assignedUserId)
        assignedUserName = try container.decodeIfPresent(String.self, forKey: .assignedUserName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Handle Decimal decoding from String or Double
        if let priceString = try? container.decode(String.self, forKey: .price) {
            price = Decimal(string: priceString)
        } else if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = Decimal(priceDouble)
        } else {
            price = nil
        }
    }
}

// MARK: - Core Data Conversion
extension Device {
    @MainActor
    init(from entity: CDDevice) {
        self.id = entity.id ?? ""
        self.orderId = entity.orderId ?? ""
        self.type = entity.type ?? ""
        self.brand = entity.brand
        self.model = entity.model
        self.serial = entity.serial
        self.imei = entity.imei
        self.passcode = entity.passcode
        self.status = DeviceStatus(rawValue: entity.status ?? "") ?? .bookedIn
        self.issue = entity.issue
        self.diagnosis = entity.diagnosis
        self.resolution = entity.resolution
        self.price = entity.price as Decimal?
        self.assignedUserId = entity.assignedUserId
        self.assignedUserName = nil
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDDevice {
        let entity = CDDevice(context: context)
        entity.id = id
        entity.orderId = orderId
        entity.type = type
        entity.brand = brand
        entity.model = model
        entity.serial = serial
        entity.imei = imei
        entity.passcode = passcode
        entity.status = status.rawValue
        entity.issue = issue
        entity.diagnosis = diagnosis
        entity.resolution = resolution
        entity.price = price as NSDecimalNumber?
        entity.assignedUserId = assignedUserId
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.syncedAt = Date()
        entity.needsSync = false
        return entity
    }
}
