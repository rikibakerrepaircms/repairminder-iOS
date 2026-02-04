//
//  EnquiryCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryCard: View {
    let enquiry: Enquiry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top) {
                // Customer avatar
                CustomerInitialsAvatar(
                    name: enquiry.customerName,
                    size: 44,
                    isNew: !enquiry.isRead
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(enquiry.customerName)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if !enquiry.isRead {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(enquiry.customerEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Time & Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(enquiry.createdAt.relativeFormatted())
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    EnquiryStatusPill(status: enquiry.status)
                }
            }

            // Device info
            HStack(spacing: 8) {
                Image(systemName: enquiry.deviceType.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(enquiry.deviceBrand) \(enquiry.deviceModel)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if let phone = enquiry.customerPhone {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Issue preview
            Text(enquiry.issueDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Footer with reply info
            HStack {
                if let lastReply = enquiry.lastReply {
                    HStack(spacing: 4) {
                        Image(systemName: lastReply.isFromStaff ? "arrow.turn.up.right" : "arrow.turn.down.left")
                            .font(.caption2)
                        Text(lastReply.isFromStaff ? "You replied" : "Customer replied")
                            .font(.caption)
                        Text("·")
                        Text(lastReply.createdAt.relativeFormatted())
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                // Reply count
                if enquiry.replyCount > 0 {
                    Label("\(enquiry.replyCount)", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(enquiry.isRead ? Color.clear : Color.blue.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Context Menu
struct EnquiryContextMenu: View {
    let enquiry: Enquiry
    let onMarkRead: () -> Void
    let onArchive: () -> Void

    var body: some View {
        Group {
            if !enquiry.isRead {
                Button {
                    onMarkRead()
                } label: {
                    Label("Mark as Read", systemImage: "envelope.open")
                }
            }

            Button {
                onArchive()
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }
}

#Preview {
    let sampleEnquiry = Enquiry(
        id: "1",
        customerName: "John Smith",
        customerEmail: "john@example.com",
        customerPhone: "07123456789",
        deviceType: .smartphone,
        deviceBrand: "Apple",
        deviceModel: "iPhone 15 Pro",
        imei: nil,
        issueDescription: "Screen is cracked and the device won't turn on after being dropped. Need urgent repair as this is my work phone.",
        preferredContact: "email",
        status: .new,
        isRead: false,
        replyCount: 2,
        lastReply: EnquiryReply(
            id: "r1",
            message: "Thank you for your enquiry. We can repair this.",
            isFromStaff: false,
            staffName: nil,
            createdAt: Date().addingTimeInterval(-3600)
        ),
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date(),
        convertedOrderId: nil
    )

    EnquiryCard(enquiry: sampleEnquiry)
        .padding()
}
