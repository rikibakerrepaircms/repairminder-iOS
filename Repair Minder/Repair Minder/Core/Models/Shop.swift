//
//  Shop.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

/// Shop model for enquiry submission
struct Shop: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let address: String?
    let phone: String?
    let email: String?
    let website: String?
    let orderCount: Int
    let lastOrderDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, address, phone, email, website
        case orderCount, lastOrderDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        orderCount = try container.decodeIfPresent(Int.self, forKey: .orderCount) ?? 0
        lastOrderDate = try container.decodeIfPresent(Date.self, forKey: .lastOrderDate)
    }
}
