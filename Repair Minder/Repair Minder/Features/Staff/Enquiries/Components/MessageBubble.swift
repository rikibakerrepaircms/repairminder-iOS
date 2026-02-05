//
//  MessageBubble.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// A message bubble in the conversation thread
struct MessageBubble: View {
    let message: TicketMessage

    var body: some View {
        HStack(alignment: .top) {
            if !message.type.isFromCustomer && message.type != .note {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.type.isFromCustomer ? .leading : .trailing, spacing: 4) {
                // Header
                messageHeader

                // Content
                messageContent

                // Attachments
                if message.hasAttachments {
                    attachmentsList
                }

                // Delivery events (for outbound messages)
                if message.type == .outbound || message.type == .outboundSms {
                    deliveryStatus
                }
            }
            .padding(12)
            .background(bubbleBackground)
            .cornerRadius(16)
            .contextMenu {
                contextMenuItems
            }

            if message.type.isFromCustomer {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Message Header

    private var messageHeader: some View {
        HStack(spacing: 8) {
            // Type icon
            Image(systemName: message.type.icon)
                .font(.caption)
                .foregroundColor(typeColor)

            // Sender name
            Text(message.senderName)
                .font(.caption.weight(.semibold))
                .foregroundColor(typeColor)

            Spacer()

            // Time
            Text(message.relativeDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Message Content

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subject for inbound emails
            if let subject = message.subject, message.type == .inbound {
                Text(subject)
                    .font(.subheadline.weight(.medium))
            }

            // Body
            Text(message.displayContent)
                .font(.body)
                .textSelection(.enabled)

            // Device association (for notes)
            if let deviceName = message.deviceName {
                HStack(spacing: 4) {
                    Image(systemName: "iphone")
                    Text(deviceName)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Attachments

    private var attachmentsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(message.attachments ?? []) { attachment in
                AttachmentRow(attachment: attachment)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Delivery Events

    @ViewBuilder
    private var deliveryStatus: some View {
        if let events = message.events, !events.isEmpty {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(events) { event in
                    HStack(spacing: 4) {
                        Image(systemName: event.icon)
                            .font(.caption2)
                        Text(event.label)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text(event.formattedDate)
                            .font(.caption2)
                    }
                    .foregroundColor(event.color)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Styling

    private var bubbleBackground: Color {
        switch message.type {
        case .inbound:
            return Color(.systemGray5)
        case .outbound, .outboundSms:
            return Color.blue.opacity(0.15)
        case .note:
            return Color.orange.opacity(0.15)
        }
    }

    private var typeColor: Color {
        switch message.type {
        case .inbound:
            return .primary
        case .outbound, .outboundSms:
            return .blue
        case .note:
            return .orange
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            UIPasteboard.general.string = message.displayContent
        } label: {
            Label("Copy Text", systemImage: "doc.on.doc")
        }

        if message.type == .note {
            Label("Internal Note", systemImage: "eye.slash")
        }
    }
}

// MARK: - Attachment Row

private struct AttachmentRow: View {
    let attachment: MessageAttachment

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.iconName)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.caption)
                    .lineLimit(1)
                Text(attachment.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.down.circle")
                .foregroundColor(.blue)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Customer message
        MessageBubble(message: TicketMessage(
            id: "1",
            type: .inbound,
            fromEmail: "customer@example.com",
            fromName: "John Smith",
            toEmail: "support@company.com",
            subject: "iPhone Screen Issue",
            bodyText: "Hi, my iPhone screen is cracked. Can you help?",
            bodyHtml: nil,
            deviceId: nil,
            deviceName: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
            createdBy: nil,
            events: nil,
            attachments: nil
        ))

        // Staff reply
        MessageBubble(message: TicketMessage(
            id: "2",
            type: .outbound,
            fromEmail: "support@company.com",
            fromName: "Staff Reply",
            toEmail: "customer@example.com",
            subject: nil,
            bodyText: "Hi John, we can definitely help! Please bring your device to our store.",
            bodyHtml: nil,
            deviceId: nil,
            deviceName: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800)),
            createdBy: CreatedByUser(id: "user1", firstName: "Jane", lastName: "Doe"),
            events: [
                MessageEvent(id: "e1", eventType: "sent", eventData: nil, createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))),
                MessageEvent(id: "e2", eventType: "delivered", eventData: nil, createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1790))),
                MessageEvent(id: "e3", eventType: "opened", eventData: nil, createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-900))),
                MessageEvent(id: "e4", eventType: "opened", eventData: nil, createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))),
                MessageEvent(id: "e5", eventType: "clicked", eventData: nil, createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-290)))
            ],
            attachments: nil
        ))

        // Internal note
        MessageBubble(message: TicketMessage(
            id: "3",
            type: .note,
            fromEmail: nil,
            fromName: "Internal Note",
            toEmail: nil,
            subject: nil,
            bodyText: "Customer prefers afternoon appointments.",
            bodyHtml: nil,
            deviceId: "device1",
            deviceName: "Apple iPhone 14 Pro",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            createdBy: CreatedByUser(id: "user1", firstName: "Jane", lastName: "Doe"),
            events: nil,
            attachments: nil
        ))
    }
    .padding()
}
