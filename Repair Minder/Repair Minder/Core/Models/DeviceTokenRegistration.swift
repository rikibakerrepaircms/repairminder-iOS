//
//  DeviceTokenRegistration.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Device Token Registration

/// Request body for POST /api/user/device-token
struct DeviceTokenRegistration: Codable {
    let deviceToken: String
    let platform: String
    let appType: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?

    /// Create registration for staff app
    static func forStaff(token: String) -> DeviceTokenRegistration {
        DeviceTokenRegistration(
            deviceToken: token,
            platform: platformIdentifier,
            appType: "staff",
            deviceName: platformDeviceModel(),
            osVersion: platformOSVersion(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }

    /// Create registration for customer app
    static func forCustomer(token: String) -> DeviceTokenRegistration {
        DeviceTokenRegistration(
            deviceToken: token,
            platform: platformIdentifier,
            appType: "customer",
            deviceName: platformDeviceModel(),
            osVersion: platformOSVersion(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
    }
}

// MARK: - Device Token Unregistration

/// Request body for DELETE /api/user/device-token
struct DeviceTokenUnregistration: Codable {
    let deviceToken: String
}

// MARK: - Registered Device Token

/// Device token info returned from GET /api/user/device-tokens
struct RegisteredDeviceToken: Codable, Identifiable {
    let id: String
    let platform: String
    let appType: String
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let lastUsedAt: String?
    let createdAt: String?
}
