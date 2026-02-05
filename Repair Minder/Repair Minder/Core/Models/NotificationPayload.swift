//
//  NotificationPayload.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

// MARK: - Notification Type

/// Types of push notifications sent by the backend
enum NotificationType: String, Codable, CaseIterable {
    case orderCreated = "order_created"
    case orderStatusChanged = "order_status_changed"
    case deviceAssigned = "device_assigned"
    case deviceStatusChanged = "device_status_changed"
    case quoteApproved = "quote_approved"
    case quoteRejected = "quote_rejected"
    case paymentReceived = "payment_received"
    case enquiryReceived = "enquiry_received"
    case enquiryReply = "enquiry_reply"
    case ticketMessage = "ticket_message"

    /// Human-readable description
    var displayName: String {
        switch self {
        case .orderCreated: return "Order Created"
        case .orderStatusChanged: return "Order Status Changed"
        case .deviceAssigned: return "Device Assigned"
        case .deviceStatusChanged: return "Device Status Changed"
        case .quoteApproved: return "Quote Approved"
        case .quoteRejected: return "Quote Rejected"
        case .paymentReceived: return "Payment Received"
        case .enquiryReceived: return "New Enquiry"
        case .enquiryReply: return "Enquiry Reply"
        case .ticketMessage: return "Support Message"
        }
    }
}

// MARK: - Entity Type

/// Entity types referenced in push notifications
enum NotificationEntityType: String, Codable {
    case order
    case device
    case enquiry
    case ticket
}

// MARK: - Notification Payload

/// Parsed push notification payload for deep linking
struct NotificationPayload {
    let type: NotificationType?
    let entityType: NotificationEntityType?
    let entityId: String?

    /// Initialize from push notification userInfo dictionary
    init(userInfo: [AnyHashable: Any]) {
        if let typeString = userInfo["type"] as? String {
            self.type = NotificationType(rawValue: typeString)
        } else {
            self.type = nil
        }

        if let entityTypeString = userInfo["entity_type"] as? String {
            self.entityType = NotificationEntityType(rawValue: entityTypeString)
        } else {
            self.entityType = nil
        }

        self.entityId = userInfo["entity_id"] as? String
    }

    /// Whether this payload has enough information for deep linking
    var canDeepLink: Bool {
        type != nil && entityId != nil
    }
}

// MARK: - Deep Link Destination

/// Destination screens for deep linking from notifications
enum DeepLinkDestination: Equatable {
    case order(id: String)
    case device(id: String)
    case enquiry(id: String)
    case ticket(id: String)

    /// Create destination from notification payload
    static func from(payload: NotificationPayload) -> DeepLinkDestination? {
        guard let type = payload.type, let entityId = payload.entityId else {
            return nil
        }

        switch type {
        case .orderCreated, .orderStatusChanged, .quoteApproved, .quoteRejected, .paymentReceived:
            return .order(id: entityId)

        case .deviceAssigned, .deviceStatusChanged:
            return .device(id: entityId)

        case .enquiryReceived, .enquiryReply:
            return .enquiry(id: entityId)

        case .ticketMessage:
            return .ticket(id: entityId)
        }
    }
}
