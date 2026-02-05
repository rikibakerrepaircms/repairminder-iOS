//
//  User.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - User Model (Staff)

/// Staff user returned from authentication endpoints
/// API returns snake_case fields, decoder converts automatically
struct User: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let companyId: String
    let role: UserRole
    let phiAccessLevel: String?
    let dataClassification: String?
    let isActive: Bool
    let magicLinkEnabled: Bool?
    let companyStatus: String?
    let lastLogin: String?
    let createdAt: String?
    let updatedAt: String?

    /// Full display name combining first and last name
    var displayName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    /// User's initials for avatar display
    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    /// Whether the user's company is in quarantine mode
    var isQuarantined: Bool {
        companyStatus == "pending_approval" || companyStatus == "suspended"
    }

    /// Custom decoding to handle `is_active` as Int (0/1) from backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        companyId = try container.decode(String.self, forKey: .companyId)
        role = try container.decode(UserRole.self, forKey: .role)
        phiAccessLevel = try container.decodeIfPresent(String.self, forKey: .phiAccessLevel)
        dataClassification = try container.decodeIfPresent(String.self, forKey: .dataClassification)
        magicLinkEnabled = try? container.decodeIfPresent(Bool.self, forKey: .magicLinkEnabled)
            ?? (container.decodeIfPresent(Int.self, forKey: .magicLinkEnabled).map { $0 != 0 })
        companyStatus = try container.decodeIfPresent(String.self, forKey: .companyStatus)
        lastLogin = try container.decodeIfPresent(String.self, forKey: .lastLogin)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle is_active as Bool or Int (backend returns 0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isActive) {
            isActive = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isActive) {
            isActive = intValue != 0
        } else {
            isActive = true
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, email, firstName, lastName, companyId, role
        case phiAccessLevel, dataClassification, isActive
        case magicLinkEnabled, companyStatus, lastLogin
        case createdAt, updatedAt
    }
}

// MARK: - User Role

/// Staff role levels with their permissions
enum UserRole: String, Codable, CaseIterable, Sendable {
    case masterAdmin = "master_admin"
    case admin = "admin"
    case seniorEngineer = "senior_engineer"
    case engineer = "engineer"
    case office = "office"

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .masterAdmin: return "Master Admin"
        case .admin: return "Admin"
        case .seniorEngineer: return "Senior Engineer"
        case .engineer: return "Engineer"
        case .office: return "Office"
        }
    }

    /// Whether this role has admin privileges
    var isAdmin: Bool {
        self == .masterAdmin || self == .admin
    }
}

// MARK: - Company Model

/// Company information returned with authentication
/// Note: Customer auth returns a simplified company object without status/VAT fields
struct Company: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let status: String  // May be missing in customer auth - defaults to "active"
    let currencyCode: String?
    let vatNumber: String?
    let logoUrl: String?
    let vatRateRepair: Double?
    let vatRateDeviceSale: Double?
    let vatRateAccessory: Double?
    let vatRateDevicePurchase: Double?

    /// Whether the company is active
    var isActive: Bool {
        status == "active"
    }

    /// Whether the company is pending approval (quarantine mode)
    var isPendingApproval: Bool {
        status == "pending_approval"
    }

    /// Whether the company is suspended
    var isSuspended: Bool {
        status == "suspended"
    }

    /// Custom decoding to handle flexible field types from backend
    /// Customer auth returns simplified company without status - defaults to "active"
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Status may be missing in customer auth responses - default to "active"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
        vatNumber = try container.decodeIfPresent(String.self, forKey: .vatNumber)
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)

        // Handle VAT rates that may come as Int, Double, or String
        vatRateRepair = Self.decodeVatRate(from: container, forKey: .vatRateRepair)
        vatRateDeviceSale = Self.decodeVatRate(from: container, forKey: .vatRateDeviceSale)
        vatRateAccessory = Self.decodeVatRate(from: container, forKey: .vatRateAccessory)
        vatRateDevicePurchase = Self.decodeVatRate(from: container, forKey: .vatRateDevicePurchase)
    }

    private static func decodeVatRate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let doubleValue = Double(stringValue) {
            return doubleValue
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, status, currencyCode, vatNumber, logoUrl
        case vatRateRepair, vatRateDeviceSale, vatRateAccessory, vatRateDevicePurchase
    }
}

// MARK: - Customer Client (for Customer Portal auth)

/// Customer client returned from customer authentication
/// Separate from the staff-facing Client model in Client.swift
struct CustomerClient: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String
    let name: String?

    /// Full display name
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    /// Client's initials for avatar display
    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        let result = first + last
        return result.isEmpty ? email.prefix(2).uppercased() : result.uppercased()
    }
}

// MARK: - Company Selection Item

/// Simplified company info returned when customer has multiple companies
struct CompanySelectionItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let logoUrl: String?
}
