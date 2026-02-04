//
//  MessageBubble.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct MessageBubble: View {
    let message: EnquiryMessage

    var body: some View {
        HStack {
            if message.isFromStaff {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromStaff ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(message.isFromStaff ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(message.isFromStaff ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 4) {
                    if message.isFromStaff {
                        Text(message.staffName ?? "You")
                    }
                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            if !message.isFromStaff {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(
            message: EnquiryMessage(
                id: "1",
                content: "Hello, I need help with my phone",
                isFromStaff: false,
                staffId: nil,
                staffName: nil,
                createdAt: Date().addingTimeInterval(-3600)
            )
        )

        MessageBubble(
            message: EnquiryMessage(
                id: "2",
                content: "Hi there! Thanks for reaching out. How can we help you today?",
                isFromStaff: true,
                staffId: "staff1",
                staffName: "Sarah",
                createdAt: Date().addingTimeInterval(-1800)
            )
        )
    }
    .padding()
}
