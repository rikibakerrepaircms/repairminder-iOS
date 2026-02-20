//
//  CustomerMessage.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Customer Message

/// Message in ticket conversation (visible to customers)
/// Note: Internal notes (type = "note") are excluded by the API
struct CustomerMessage: Codable, Identifiable, Sendable {
    let id: String
    let type: String  // "outbound", "inbound", "outbound_sms"
    let subject: String?
    let bodyText: String?
    let createdAt: Date

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case id, type, subject, bodyText, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        bodyText = try container.decodeIfPresent(String.self, forKey: .bodyText)
        if let str = try? container.decode(String.self, forKey: .createdAt) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: str) { createdAt = d }
            else {
                iso.formatOptions = [.withInternetDateTime]
                if let d = iso.date(from: str) { createdAt = d }
                else {
                    let mysql = DateFormatter()
                    mysql.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    mysql.timeZone = TimeZone(identifier: "UTC")
                    createdAt = mysql.date(from: str) ?? Date()
                }
            }
        } else { createdAt = Date() }
    }

    // MARK: - Computed Properties

    /// Whether this is a message from the company
    var isFromCompany: Bool {
        type == "outbound" || type == "outbound_sms"
    }

    /// Whether this is a message from the customer
    var isFromCustomer: Bool {
        type == "inbound"
    }

    /// Whether this is an SMS message
    var isSms: Bool {
        type == "outbound_sms"
    }

    /// Message type for display
    var typeLabel: String {
        switch type {
        case "outbound": return "Email"
        case "outbound_sms": return "SMS"
        case "inbound": return "Your Reply"
        default: return "Message"
        }
    }

    /// Icon for message type
    var typeIcon: String {
        switch type {
        case "outbound": return "envelope.fill"
        case "outbound_sms": return "message.fill"
        case "inbound": return "arrow.up.circle.fill"
        default: return "doc.text.fill"
        }
    }

    /// Alignment for message bubble
    var alignment: HorizontalAlignment {
        isFromCustomer ? .trailing : .leading
    }

    /// Background color for message bubble
    var backgroundColor: Color {
        isFromCustomer ? .blue : Color.platformGray6
    }

    /// Text color for message bubble
    var textColor: Color {
        isFromCustomer ? .white : .primary
    }

    /// Formatted date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(createdAt) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: createdAt))"
        } else if calendar.isDateInYesterday(createdAt) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: createdAt))"
        } else if calendar.isDate(createdAt, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: createdAt)
        } else {
            return DateFormatters.formatHumanDate(createdAt)
        }
    }

    /// Preview text (truncated body for list display)
    var previewText: String {
        let text = bodyText ?? ""
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
}

// MARK: - Customer Reply Request

/// Request body for POST /api/customer/orders/:orderId/reply
struct CustomerReplyRequest: Encodable {
    let message: String
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case message
        case deviceId = "device_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        if let deviceId = deviceId {
            try container.encode(deviceId, forKey: .deviceId)
        }
    }
}

/// Response from POST /api/customer/orders/:orderId/reply
struct CustomerReplyResponse: Decodable {
    let messageId: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case createdAt = "created_at"
    }
}
