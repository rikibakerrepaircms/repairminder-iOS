//
//  NotificationPayload.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation

/// Represents a parsed push notification payload
struct NotificationPayload {
    let type: NotificationType
    let entityId: String?
    let title: String
    let body: String
    let badge: Int?

    /// Types of notifications the app can receive
    enum NotificationType: String, Sendable {
        // Order notifications
        case orderCreated = "order_created"
        case orderStatusChanged = "order_status_changed"

        // Device notifications
        case deviceAssigned = "device_assigned"
        case deviceStatusChanged = "device_status_changed"

        // Ticket/Support notifications
        case ticketMessage = "ticket_message"
        case ticketReopened = "ticket_reopened"

        // Payment notifications
        case paymentReceived = "payment_received"

        // Enquiry notifications
        case enquiryReceived = "enquiry_received"
        case enquiryReply = "enquiry_reply"

        // Quote notifications
        case quoteApproved = "quote_approved"
        case quoteRejected = "quote_rejected"

        // Unknown/fallback
        case unknown

        /// The associated entity type for deep linking
        var entityType: EntityType? {
            switch self {
            case .orderCreated, .orderStatusChanged, .paymentReceived, .quoteApproved, .quoteRejected:
                return .order
            case .deviceAssigned, .deviceStatusChanged:
                return .device
            case .ticketMessage, .ticketReopened:
                return .ticket
            case .enquiryReceived, .enquiryReply:
                return .enquiry
            case .unknown:
                return nil
            }
        }

        enum EntityType: String {
            case order
            case device
            case ticket
            case enquiry
        }
    }

    /// Initialize from a notification's userInfo dictionary
    init?(userInfo: [AnyHashable: Any]) {
        // Parse APS payload
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any] else {
            // Try flat alert structure
            if let aps = userInfo["aps"] as? [String: Any],
               let alertString = aps["alert"] as? String {
                title = "RepairMinder"
                body = alertString
                badge = aps["badge"] as? Int
                type = Self.parseType(from: userInfo)
                entityId = userInfo["entity_id"] as? String
                return
            }
            return nil
        }

        title = alert["title"] as? String ?? "RepairMinder"
        body = alert["body"] as? String ?? ""
        badge = aps["badge"] as? Int

        type = Self.parseType(from: userInfo)
        entityId = userInfo["entity_id"] as? String
    }

    /// Parse notification type from userInfo
    private static func parseType(from userInfo: [AnyHashable: Any]) -> NotificationType {
        guard let typeString = userInfo["type"] as? String else {
            return .unknown
        }
        return NotificationType(rawValue: typeString) ?? .unknown
    }
}

// MARK: - Debug Description

extension NotificationPayload: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        NotificationPayload(
            type: \(type.rawValue),
            entityId: \(entityId ?? "nil"),
            title: \(title),
            body: \(body.prefix(50))...,
            badge: \(badge?.description ?? "nil")
        )
        """
    }
}
