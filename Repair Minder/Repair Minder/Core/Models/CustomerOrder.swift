//
//  CustomerOrder.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import SwiftUI

/// Customer-facing order model with friendly status descriptions
struct CustomerOrder: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let orderNumber: Int
    let status: CustomerOrderStatus
    let deviceSummary: String
    let total: Decimal?
    let deposit: Decimal?
    let balance: Decimal?
    let shopName: String?
    let createdAt: Date
    let updatedAt: Date
    let devices: [CustomerDevice]?

    var displayRef: String { "#\(orderNumber)" }

    var isPaid: Bool {
        (balance ?? 0) <= 0
    }

    enum CodingKeys: String, CodingKey {
        case id, status, total, deposit, balance
        case orderNumber, deviceSummary, shopName
        case createdAt, updatedAt, devices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        orderNumber = try container.decode(Int.self, forKey: .orderNumber)
        status = try container.decode(CustomerOrderStatus.self, forKey: .status)
        deviceSummary = try container.decodeIfPresent(String.self, forKey: .deviceSummary) ?? ""
        shopName = try container.decodeIfPresent(String.self, forKey: .shopName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        devices = try container.decodeIfPresent([CustomerDevice].self, forKey: .devices)

        // Handle Decimal decoding from String or Double
        if let totalString = try? container.decode(String.self, forKey: .total) {
            total = Decimal(string: totalString)
        } else if let totalDouble = try? container.decode(Double.self, forKey: .total) {
            total = Decimal(totalDouble)
        } else {
            total = nil
        }

        if let depositString = try? container.decode(String.self, forKey: .deposit) {
            deposit = Decimal(string: depositString)
        } else if let depositDouble = try? container.decode(Double.self, forKey: .deposit) {
            deposit = Decimal(depositDouble)
        } else {
            deposit = nil
        }

        if let balanceString = try? container.decode(String.self, forKey: .balance) {
            balance = Decimal(string: balanceString)
        } else if let balanceDouble = try? container.decode(Double.self, forKey: .balance) {
            balance = Decimal(balanceDouble)
        } else {
            balance = nil
        }
    }
}

/// Device information for customer view
struct CustomerDevice: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let type: String
    let brand: String?
    let model: String?
    let status: CustomerDeviceStatus
    let issue: String?
    let price: Decimal?

    var displayName: String {
        if let brand = brand, let model = model, !brand.isEmpty, !model.isEmpty {
            return "\(brand) \(model)"
        }
        return type
    }

    enum CodingKeys: String, CodingKey {
        case id, type, brand, model, status, issue, price
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        status = try container.decode(CustomerDeviceStatus.self, forKey: .status)
        issue = try container.decodeIfPresent(String.self, forKey: .issue)

        if let priceString = try? container.decode(String.self, forKey: .price) {
            price = Decimal(string: priceString)
        } else if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = Decimal(priceDouble)
        } else {
            price = nil
        }
    }
}

/// Customer-friendly device status
enum CustomerDeviceStatus: String, Codable, Sendable {
    case received = "booked_in"
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
        case .received: return "Received"
        case .diagnosing: return "Being Checked"
        case .awaitingApproval: return "Quote Ready"
        case .approved: return "Approved"
        case .inRepair: return "Repairing"
        case .awaitingParts: return "Waiting for Parts"
        case .repaired: return "Repaired"
        case .qualityCheck: return "Final Checks"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .unrepairable: return "Cannot Repair"
        }
    }

    var color: Color {
        switch self {
        case .received: return .blue
        case .diagnosing: return .purple
        case .awaitingApproval: return .orange
        case .approved: return .teal
        case .inRepair: return .indigo
        case .awaitingParts: return .gray
        case .repaired: return .mint
        case .qualityCheck: return .cyan
        case .ready: return .green
        case .collected: return .gray
        case .unrepairable: return .red
        }
    }
}

/// Customer-friendly order status with descriptions
enum CustomerOrderStatus: String, Codable, CaseIterable, Sendable {
    case received = "booked_in"
    case diagnosing = "diagnosing"
    case awaitingApproval = "awaiting_approval"
    case inRepair = "in_progress"
    case awaitingParts = "awaiting_parts"
    case qualityCheck = "quality_check"
    case ready = "ready"
    case collected = "collected"

    var customerDisplayName: String {
        switch self {
        case .received: return "Received"
        case .diagnosing: return "Being Diagnosed"
        case .awaitingApproval: return "Approval Needed"
        case .inRepair: return "Being Repaired"
        case .awaitingParts: return "Waiting for Parts"
        case .qualityCheck: return "Final Checks"
        case .ready: return "Ready for Collection"
        case .collected: return "Collected"
        }
    }

    var customerDescription: String {
        switch self {
        case .received: return "We've received your device and it's in our queue"
        case .diagnosing: return "Our technician is examining your device"
        case .awaitingApproval: return "Please review and approve the repair quote"
        case .inRepair: return "Your device is being repaired"
        case .awaitingParts: return "We're waiting for parts to arrive"
        case .qualityCheck: return "We're running final quality checks"
        case .ready: return "Your device is ready! Come collect it anytime"
        case .collected: return "Thanks for choosing us!"
        }
    }

    var icon: String {
        switch self {
        case .received: return "tray.and.arrow.down.fill"
        case .diagnosing: return "magnifyingglass"
        case .awaitingApproval: return "hand.raised.fill"
        case .inRepair: return "wrench.and.screwdriver.fill"
        case .awaitingParts: return "shippingbox.fill"
        case .qualityCheck: return "checkmark.shield.fill"
        case .ready: return "checkmark.circle.fill"
        case .collected: return "hand.thumbsup.fill"
        }
    }

    var color: Color {
        switch self {
        case .received: return .blue
        case .diagnosing: return .orange
        case .awaitingApproval: return .yellow
        case .inRepair: return .purple
        case .awaitingParts: return .gray
        case .qualityCheck: return .teal
        case .ready: return .green
        case .collected: return .gray
        }
    }

    var isActive: Bool {
        switch self {
        case .collected:
            return false
        default:
            return true
        }
    }

    var requiresAction: Bool {
        self == .awaitingApproval
    }
}
