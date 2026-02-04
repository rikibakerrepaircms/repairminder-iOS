//
//  CustomerEnquiry.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import SwiftUI

/// Customer enquiry model for repair requests
struct CustomerEnquiry: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let shopId: String
    let shopName: String
    let deviceType: String
    let deviceBrand: String
    let deviceModel: String
    let issueDescription: String
    let status: CustomerEnquiryStatus
    let preferredContact: String?
    let createdAt: Date
    let updatedAt: Date
    let replies: [EnquiryReply]?
    let convertedOrderId: String?

    enum CodingKeys: String, CodingKey {
        case id, shopId, shopName, deviceType, deviceBrand, deviceModel
        case issueDescription, status, preferredContact
        case createdAt, updatedAt, replies, convertedOrderId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        shopId = try container.decode(String.self, forKey: .shopId)
        shopName = try container.decodeIfPresent(String.self, forKey: .shopName) ?? ""
        deviceType = try container.decode(String.self, forKey: .deviceType)
        deviceBrand = try container.decode(String.self, forKey: .deviceBrand)
        deviceModel = try container.decodeIfPresent(String.self, forKey: .deviceModel) ?? ""
        issueDescription = try container.decode(String.self, forKey: .issueDescription)
        status = try container.decode(CustomerEnquiryStatus.self, forKey: .status)
        preferredContact = try container.decodeIfPresent(String.self, forKey: .preferredContact)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        replies = try container.decodeIfPresent([EnquiryReply].self, forKey: .replies)
        convertedOrderId = try container.decodeIfPresent(String.self, forKey: .convertedOrderId)
    }

    var deviceDisplayName: String {
        if !deviceBrand.isEmpty && !deviceModel.isEmpty {
            return "\(deviceBrand) \(deviceModel)"
        } else if !deviceBrand.isEmpty {
            return deviceBrand
        }
        return deviceType
    }
}

/// Enquiry status
enum CustomerEnquiryStatus: String, Codable, Sendable {
    case pending = "pending"
    case responded = "responded"
    case converted = "converted"
    case closed = "closed"

    var displayName: String {
        switch self {
        case .pending: return "Awaiting Reply"
        case .responded: return "Shop Replied"
        case .converted: return "Order Created"
        case .closed: return "Closed"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .responded: return .blue
        case .converted: return .green
        case .closed: return .gray
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .responded: return "envelope.open.fill"
        case .converted: return "checkmark.circle.fill"
        case .closed: return "xmark.circle.fill"
        }
    }
}
