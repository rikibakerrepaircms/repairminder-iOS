//
//  PushPreferences.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Push Preferences Model

/// User's push notification preferences
/// Matches the backend `push_notification_preferences` table structure
struct PushPreferences: Codable, Equatable, Sendable {
    var notificationsEnabled: Bool
    var orderStatusChanged: Bool
    var orderCreated: Bool
    var orderCollected: Bool
    var deviceStatusChanged: Bool
    var quoteApproved: Bool
    var quoteRejected: Bool
    var paymentReceived: Bool
    var newEnquiry: Bool
    var enquiryReply: Bool

    /// Default preferences - all enabled
    static let allEnabled = PushPreferences(
        notificationsEnabled: true,
        orderStatusChanged: true,
        orderCreated: true,
        orderCollected: true,
        deviceStatusChanged: true,
        quoteApproved: true,
        quoteRejected: true,
        paymentReceived: true,
        newEnquiry: true,
        enquiryReply: true
    )

    /// All preferences disabled
    static let allDisabled = PushPreferences(
        notificationsEnabled: false,
        orderStatusChanged: false,
        orderCreated: false,
        orderCollected: false,
        deviceStatusChanged: false,
        quoteApproved: false,
        quoteRejected: false,
        paymentReceived: false,
        newEnquiry: false,
        enquiryReply: false
    )
}

// MARK: - Push Preferences Update Request

/// Request body for PUT /api/user/push-preferences
/// Only include fields that should be updated
struct PushPreferencesUpdateRequest: Codable {
    var notificationsEnabled: Bool?
    var orderStatusChanged: Bool?
    var orderCreated: Bool?
    var orderCollected: Bool?
    var deviceStatusChanged: Bool?
    var quoteApproved: Bool?
    var quoteRejected: Bool?
    var paymentReceived: Bool?
    var newEnquiry: Bool?
    var enquiryReply: Bool?

    /// Create a request to update a single preference
    static func single(key: WritableKeyPath<PushPreferencesUpdateRequest, Bool?>, value: Bool) -> PushPreferencesUpdateRequest {
        var request = PushPreferencesUpdateRequest()
        request[keyPath: key] = value
        return request
    }

    /// Create a request to disable all preferences (master toggle off)
    static var disableAll: PushPreferencesUpdateRequest {
        PushPreferencesUpdateRequest(
            notificationsEnabled: false,
            orderStatusChanged: false,
            orderCreated: false,
            orderCollected: false,
            deviceStatusChanged: false,
            quoteApproved: false,
            quoteRejected: false,
            paymentReceived: false,
            newEnquiry: false,
            enquiryReply: false
        )
    }
}
