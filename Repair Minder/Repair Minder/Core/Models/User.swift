//
//  User.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import Foundation

struct User: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
    let companyId: String
    let role: UserRole
    let isActive: Bool
    let verified: Bool
    let twoFactorEnabled: Bool
    let magicLinkEnabled: Bool

    var displayName: String {
        if let first = firstName, let last = lastName, !first.isEmpty, !last.isEmpty {
            return "\(first) \(last)"
        }
        return username
    }

    var initials: String {
        if let first = firstName?.first, let last = lastName?.first {
            return "\(first)\(last)"
        }
        return String(username.prefix(2)).uppercased()
    }

    // Use simple CodingKeys - the APIClient's convertFromSnakeCase handles JSON key conversion
    enum CodingKeys: String, CodingKey {
        case id, email, username, firstName, lastName, companyId, role
        case isActive, verified, twoFactorEnabled, magicLinkEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        companyId = try container.decode(String.self, forKey: .companyId)
        role = try container.decode(UserRole.self, forKey: .role)

        // Handle Int -> Bool conversion for SQLite integer booleans
        if let intValue = try? container.decode(Int.self, forKey: .isActive) {
            isActive = intValue != 0
        } else {
            isActive = try container.decode(Bool.self, forKey: .isActive)
        }

        if let intValue = try? container.decode(Int.self, forKey: .verified) {
            verified = intValue != 0
        } else {
            verified = try container.decode(Bool.self, forKey: .verified)
        }

        if let intValue = try? container.decode(Int.self, forKey: .twoFactorEnabled) {
            twoFactorEnabled = intValue != 0
        } else {
            twoFactorEnabled = try container.decode(Bool.self, forKey: .twoFactorEnabled)
        }

        if let intValue = try? container.decode(Int.self, forKey: .magicLinkEnabled) {
            magicLinkEnabled = intValue != 0
        } else {
            magicLinkEnabled = try container.decode(Bool.self, forKey: .magicLinkEnabled)
        }
    }
}

enum UserRole: String, Codable, Sendable {
    case masterAdmin = "master_admin"
    case admin = "admin"
    case seniorEngineer = "senior_engineer"
    case engineer = "engineer"
    case office = "office"
    case custom

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = UserRole(rawValue: rawValue) ?? .custom
    }

    var displayName: String {
        switch self {
        case .masterAdmin: return "Master Admin"
        case .admin: return "Admin"
        case .seniorEngineer: return "Senior Engineer"
        case .engineer: return "Engineer"
        case .office: return "Office"
        case .custom: return "Custom"
        }
    }

    var canManageOrders: Bool {
        switch self {
        case .masterAdmin, .admin, .seniorEngineer, .engineer, .office:
            return true
        case .custom:
            return false
        }
    }
}
