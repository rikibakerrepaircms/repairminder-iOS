//
//  TicketMessage.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI

// MARK: - Ticket Message

/// A message in a ticket conversation (email, note, or SMS)
struct TicketMessage: Codable, Identifiable, Sendable, Equatable {
    let id: String
    let type: MessageType
    let fromEmail: String?
    let fromName: String?
    let toEmail: String?
    let subject: String?
    let bodyText: String?
    let bodyHtml: String?
    let deviceId: String?
    let deviceName: String?
    let createdAt: String
    let createdBy: CreatedByUser?
    let source: String?
    let events: [MessageEvent]?
    let attachments: [MessageAttachment]?

    // MARK: - Computed Properties

    /// Display content - prefer text over HTML stripped
    var displayContent: String {
        if let text = bodyText, !text.isEmpty {
            return text
        }
        if let html = bodyHtml {
            return html.strippingHTML()
        }
        return ""
    }

    /// Truncated preview for list views
    var previewContent: String {
        let content = displayContent
        if content.count > 100 {
            return String(content.prefix(100)) + "..."
        }
        return content
    }

    /// Sender display name
    var senderName: String {
        if type == .note {
            return createdBy?.fullName ?? "Staff"
        }
        if type.isFromCustomer {
            return fromName ?? fromEmail ?? "Customer"
        }
        return createdBy?.fullName ?? fromName ?? "Staff"
    }

    /// Formatted creation date
    var formattedDate: String {
        guard let date = DateFormatters.parseDate(createdAt) else {
            return createdAt
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Relative time since creation
    var relativeDate: String {
        guard let date = DateFormatters.parseDate(createdAt) else {
            return createdAt
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Whether this message has attachments
    var hasAttachments: Bool {
        !(attachments?.isEmpty ?? true)
    }

    /// Latest delivery event status
    var deliveryStatus: DeliveryStatus {
        guard let events = events, !events.isEmpty else {
            return .unknown
        }

        // Check for error states first. "failed" is what the Voodoo SMS webhook
        // records for a receipt the network refused (UNDELIVERED/EXPIRED/
        // REJECTED); without it an undeliverable text reported as .sent.
        if events.contains(where: {
            $0.eventType == "bounced" || $0.eventType == "blocked" || $0.eventType == "failed"
        }) {
            return .failed
        }

        // Check for opened (best case)
        if events.contains(where: { $0.eventType == "opened" }) {
            return .opened
        }

        // Check for clicked
        if events.contains(where: { $0.eventType == "clicked" }) {
            return .clicked
        }

        // Check for delivered
        if events.contains(where: { $0.eventType == "delivered" }) {
            return .delivered
        }

        // Check for sent
        if events.contains(where: { $0.eventType == "sent" }) {
            return .sent
        }

        return .unknown
    }
}

// MARK: - Delivery Status

/// Email delivery status derived from events
enum DeliveryStatus: String, Sendable {
    case unknown
    case sent
    case delivered
    case opened
    case clicked
    case failed

    var label: String {
        switch self {
        case .unknown: return "Unknown"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .opened: return "Opened"
        case .clicked: return "Clicked"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .sent: return "paperplane"
        case .delivered: return "checkmark.circle"
        case .opened: return "envelope.open"
        case .clicked: return "hand.tap"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var isSuccess: Bool {
        switch self {
        case .sent, .delivered, .opened, .clicked:
            return true
        case .unknown, .failed:
            return false
        }
    }
}

// MARK: - Created By User

/// User who created the message
struct CreatedByUser: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let firstName: String?
    let lastName: String?

    var fullName: String {
        [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - Message Event

/// Email tracking event (sent, delivered, opened, clicked, bounced)
struct MessageEvent: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let eventType: String
    let eventData: EventData?
    let createdAt: String

    /// When the event actually happened, preferring the provider's own timestamp
    /// over the moment we recorded the receipt.
    ///
    /// Normally seconds apart. In August 2026 Voodoo's delivery receipts ran up
    /// to 15 hours behind, so `createdAt` dated a text most of a day late.
    var displayTimestamp: String {
        if let providerTimestamp = eventData?.timestamp,
           DateFormatters.parseDate(providerTimestamp) != nil {
            return providerTimestamp
        }
        return createdAt
    }

    /// Formatted event date
    var formattedDate: String {
        let source = displayTimestamp
        guard let date = DateFormatters.parseDate(source) else {
            return source
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Human-readable event label
    var label: String {
        switch eventType {
        case "sent": return "Sent"
        case "delivered": return "Delivered"
        case "opened": return "Opened"
        case "clicked": return "Link Clicked"
        case "bounced": return "Bounced"
        case "blocked": return "Blocked"
        case "failed": return "Not delivered"
        case "unknown": return "Unknown status"
        default: return eventType.capitalized
        }
    }

    /// SF Symbol icon for the event type
    var icon: String {
        switch eventType {
        case "sent": return "paperplane"
        case "delivered": return "checkmark.circle"
        case "opened": return "envelope.open"
        case "clicked": return "hand.tap"
        case "bounced", "failed": return "exclamationmark.triangle"
        case "blocked": return "xmark.shield"
        default: return "questionmark.circle"
        }
    }

    /// Color for the event type
    var color: Color {
        switch eventType {
        case "sent": return .secondary
        case "delivered": return .green
        case "opened": return .blue
        case "clicked": return .purple
        case "bounced", "blocked", "failed": return .red
        default: return .secondary
        }
    }
}

// MARK: - Event Data

/// Additional data for an event (flexible structure)
struct EventData: Codable, Equatable, Sendable {
    let postmarkMessageId: String?
    let to: String?
    let subject: String?
    let sentAt: String?
    let deliveredAt: String?
    /// When the PROVIDER says the event happened. Both Postmark and Voodoo send
    /// this; it is not the same as the event row's created_at, which is when we
    /// recorded the receipt.
    let timestamp: String?
    /// Raw provider status, e.g. Voodoo's "DELIVERED" / "UNDELIVERED".
    let status: String?

    // Flexible decoding for varying event data structures
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        postmarkMessageId = try container.decodeIfPresent(String.self, forKey: .postmarkMessageId)
        to = try container.decodeIfPresent(String.self, forKey: .to)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        sentAt = try container.decodeIfPresent(String.self, forKey: .sentAt)
        deliveredAt = try container.decodeIfPresent(String.self, forKey: .deliveredAt)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }

    private enum CodingKeys: String, CodingKey {
        case postmarkMessageId
        case to
        case subject
        case sentAt
        case deliveredAt
        case timestamp
        case status
    }
}

// MARK: - Message Attachment

/// File attachment on a message
struct MessageAttachment: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let filename: String
    let contentType: String
    let sizeBytes: Int
    let downloadUrl: String
    let createdAt: String

    /// Human-readable file size
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    /// File extension
    var fileExtension: String {
        (filename as NSString).pathExtension.lowercased()
    }

    /// Icon name based on content type
    var iconName: String {
        if contentType.hasPrefix("image/") {
            return "photo"
        }
        if contentType.hasPrefix("video/") {
            return "video"
        }
        if contentType == "application/pdf" {
            return "doc.text"
        }
        if contentType.contains("spreadsheet") || fileExtension == "csv" || fileExtension == "xlsx" {
            return "tablecells"
        }
        if contentType.contains("document") || fileExtension == "doc" || fileExtension == "docx" {
            return "doc"
        }
        return "paperclip"
    }

    /// Whether this is an image that can be previewed
    var isImage: Bool {
        contentType.hasPrefix("image/")
    }
}

// MARK: - String Extension

extension String {
    /// Strip HTML tags from string
    func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }

        // Fallback: simple regex removal
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

// MARK: - Reply Request

/// Request body for POST /api/tickets/:id/reply
struct TicketReplyRequest: Encodable {
    let htmlBody: String
    let textBody: String?
    let status: String?
    let fromCustomEmailId: String?
    let pendingAttachmentIds: [String]?
    let sendSms: Bool?
}

// MARK: - Note Request

/// Request body for POST /api/tickets/:id/note
struct TicketNoteRequest: Encodable {
    let body: String
    let deviceId: String?
}

// MARK: - Status Request

/// Request body for PATCH /api/tickets/:id (status-only update).
/// Used to reopen a ticket — there's no dedicated reopen endpoint.
struct TicketStatusRequest: Encodable {
    var status: String
}

// MARK: - Reply Response

/// Response from POST /api/tickets/:id/reply
struct TicketReplyResponse: Decodable, Sendable {
    let messageId: String
    let postmarkMessageId: String?
    let type: String
    let bodyHtml: String?
    let bodyText: String?
    let createdAt: String
}

// MARK: - Note Response

/// Response from POST /api/tickets/:id/note
struct TicketNoteResponse: Decodable, Sendable {
    let id: String
    let type: String
    let body: String
    let deviceId: String?
    let createdByUserId: String
    let createdAt: String
}

// MARK: - AI Response

/// Response from POST /api/tickets/:id/generate-response
struct AIResponseResult: Decodable, Sendable {
    let text: String
    let usage: AIUsage
    let model: String
    let provider: String
}

/// POST start response for an async AI job
struct AIJobStart: Decodable, Sendable {
    let jobId: String
    let status: String
}

/// GET status response for an async AI job
struct AIJobStatus: Decodable, Sendable {
    let status: String           // idle | running | done | error
    let result: AIResponseResult?
}

/// Token usage for AI generation
struct AIUsage: Decodable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cost: Double
}

/// Request body for AI response generation
struct AIResponseRequest: Encodable {
    let locationId: String?
}

/// Providers offered by the AI Rewrite button's inline picker.
enum RewriteProvider: String, CaseIterable, Identifiable {
    case deepseek
    case qwen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .qwen: return "Qwen"
        }
    }
}

/// Request body for AI rewrite
struct AIRewriteRequest: Encodable {
    let text: String
    let locationId: String?
    /// Per-call provider override ("deepseek" | "qwen") from the rewrite
    /// provider picker. Unrecognized/omitted values fall back to the
    /// admin-configured rewrite-settings provider server-side.
    let provider: String?
}
