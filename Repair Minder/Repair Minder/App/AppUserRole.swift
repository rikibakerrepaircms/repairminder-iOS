//
//  AppUserRole.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

/// Application user role - determines which portal the user is accessing
/// Staff users access the full repair shop management features
/// Customer users access the customer portal to view orders and communicate
enum AppUserRole: String, Codable, CaseIterable, Sendable {
    /// Staff member (admin, engineer, office, etc.)
    case staff

    /// Customer viewing their orders
    case customer

    /// Display name for UI
    var displayName: String {
        switch self {
        case .staff: return "Staff"
        case .customer: return "Customer"
        }
    }

    /// Description for role selection screen
    var description: String {
        switch self {
        case .staff:
            return "I fix broken phones and electronics"
        case .customer:
            return "I'm getting my broken phone or electronic fixed"
        }
    }

    /// Icon name for SF Symbols
    var iconName: String {
        switch self {
        case .staff: return "wrench.and.screwdriver"
        case .customer: return "person.crop.circle"
        }
    }
}

// MARK: - UserDefaults Storage

extension AppUserRole {
    private static let userDefaultsKey = "selectedAppUserRole"

    /// Save the selected role to UserDefaults
    static func save(_ role: AppUserRole) {
        UserDefaults.standard.set(role.rawValue, forKey: userDefaultsKey)
    }

    /// Load the previously selected role from UserDefaults
    static func load() -> AppUserRole? {
        guard let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey) else {
            return nil
        }
        return AppUserRole(rawValue: rawValue)
    }

    /// Clear the saved role
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
