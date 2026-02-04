//
//  Enquiry.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

struct Enquiry: Identifiable, Equatable, Sendable {
    let id: String
    let customerName: String
    let customerEmail: String
    let customerPhone: String?
    let deviceType: EnquiryDeviceType
    let deviceBrand: String
    let deviceModel: String
    let imei: String?
    let issueDescription: String
    let preferredContact: String?
    let status: EnquiryStatus
    let isRead: Bool
    let replyCount: Int
    let lastReply: EnquiryReply?
    let createdAt: Date
    let updatedAt: Date
    let convertedOrderId: String?
}

// MARK: - Codable
extension Enquiry: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case customerName
        case customerEmail
        case customerPhone
        case deviceType
        case deviceBrand
        case deviceModel
        case imei
        case issueDescription
        case preferredContact
        case status
        case isRead
        case replyCount
        case lastReply
        case createdAt
        case updatedAt
        case convertedOrderId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        customerName = try container.decode(String.self, forKey: .customerName)
        customerEmail = try container.decode(String.self, forKey: .customerEmail)
        customerPhone = try container.decodeIfPresent(String.self, forKey: .customerPhone)
        deviceType = try container.decodeIfPresent(EnquiryDeviceType.self, forKey: .deviceType) ?? .other
        deviceBrand = try container.decode(String.self, forKey: .deviceBrand)
        deviceModel = try container.decode(String.self, forKey: .deviceModel)
        imei = try container.decodeIfPresent(String.self, forKey: .imei)
        issueDescription = try container.decode(String.self, forKey: .issueDescription)
        preferredContact = try container.decodeIfPresent(String.self, forKey: .preferredContact)
        status = try container.decode(EnquiryStatus.self, forKey: .status)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        lastReply = try container.decodeIfPresent(EnquiryReply.self, forKey: .lastReply)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        convertedOrderId = try container.decodeIfPresent(String.self, forKey: .convertedOrderId)
    }
}

// MARK: - EnquiryReply
struct EnquiryReply: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let message: String
    let isFromStaff: Bool
    let staffName: String?
    let createdAt: Date

    // Computed properties for compatibility with customer-facing views
    var isFromShop: Bool { isFromStaff }
    var senderName: String? { staffName }
}
