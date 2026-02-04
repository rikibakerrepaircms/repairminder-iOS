//
//  Company.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

struct Company: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let domain: String?
    let isActive: Bool
    let currencyCode: String
    let depositsEnabled: Bool

    var currencySymbol: String {
        switch currencyCode {
        case "GBP": return "£"
        case "EUR": return "€"
        case "USD": return "$"
        default: return currencyCode
        }
    }

    // Use simple CodingKeys - the APIClient's convertFromSnakeCase handles JSON key conversion
    enum CodingKeys: String, CodingKey {
        case id, name, domain, isActive, currencyCode, depositsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)

        // Handle Int -> Bool conversion for SQLite integer booleans
        if let intValue = try? container.decode(Int.self, forKey: .isActive) {
            isActive = intValue != 0
        } else {
            isActive = try container.decode(Bool.self, forKey: .isActive)
        }

        if let intValue = try? container.decode(Int.self, forKey: .depositsEnabled) {
            depositsEnabled = intValue != 0
        } else if let boolValue = try? container.decode(Bool.self, forKey: .depositsEnabled) {
            depositsEnabled = boolValue
        } else {
            depositsEnabled = false
        }
    }
}
