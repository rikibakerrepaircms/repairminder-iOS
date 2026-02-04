//
//  ConversationThread.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ConversationThread: View {
    let messages: [EnquiryMessage]
    let scrollProxy: ScrollViewProxy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conversation", systemImage: "bubble.left.and.bubble.right")
                .font(.headline)

            if messages.isEmpty {
                Text("No messages yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                }
            }
        }
        .onChange(of: messages.count) { _, _ in
            if let lastId = messages.last?.id {
                withAnimation {
                    scrollProxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
}

#Preview {
    ScrollViewReader { proxy in
        ScrollView {
            ConversationThread(
                messages: [
                    EnquiryMessage(
                        id: "1",
                        content: "Hi, I need help with my phone screen repair",
                        isFromStaff: false,
                        staffId: nil,
                        staffName: nil,
                        createdAt: Date().addingTimeInterval(-7200)
                    ),
                    EnquiryMessage(
                        id: "2",
                        content: "Thank you for contacting us! Can you provide more details about the damage?",
                        isFromStaff: true,
                        staffId: "staff1",
                        staffName: "John",
                        createdAt: Date().addingTimeInterval(-3600)
                    ),
                    EnquiryMessage(
                        id: "3",
                        content: "The screen is cracked in the top right corner and touch doesn't work there.",
                        isFromStaff: false,
                        staffId: nil,
                        staffName: nil,
                        createdAt: Date().addingTimeInterval(-1800)
                    )
                ],
                scrollProxy: proxy
            )
            .padding()
        }
    }
}
