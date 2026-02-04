//
//  ConversationView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ConversationView: View {
    let orderId: String
    @State private var viewModel: ConversationViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    init(orderId: String) {
        self.orderId = orderId
        _viewModel = State(initialValue: ConversationViewModel(orderId: orderId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                LoadingView(message: "Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.messages.isEmpty {
                ErrorView(message: error) {
                    Task { await viewModel.loadMessages() }
                }
            } else {
                messagesList
            }

            // Input bar
            messageInputBar
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages()
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            Text("No messages yet")
                                .font(.headline)

                            Text("Send a message to start the conversation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var messageInputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .focused($isInputFocused)

            Button {
                Task {
                    await viewModel.sendMessage(messageText)
                    messageText = ""
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromCustomer {
                Spacer()
            }

            VStack(alignment: message.isFromCustomer ? .trailing : .leading, spacing: 4) {
                if !message.isFromCustomer, let senderName = message.senderName {
                    Text(senderName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(message.isFromCustomer ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(message.isFromCustomer ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromCustomer {
                Spacer()
            }
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class ConversationViewModel {
    let orderId: String

    private(set) var messages: [ChatMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    var error: String?

    init(orderId: String) {
        self.orderId = orderId
    }

    func loadMessages() async {
        isLoading = true
        error = nil

        do {
            let response: MessagesResponse = try await APIClient.shared.request(
                .customerOrderMessages(orderId: orderId),
                responseType: MessagesResponse.self
            )
            messages = response.messages
        } catch {
            self.error = "Failed to load messages."
        }

        isLoading = false
    }

    func sendMessage(_ content: String) async {
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        guard !trimmedContent.isEmpty else { return }

        isSending = true

        do {
            try await APIClient.shared.requestVoid(
                .customerSendMessage(orderId: orderId, message: trimmedContent)
            )
            await loadMessages()
        } catch {
            self.error = "Failed to send message."
        }

        isSending = false
    }
}

// MARK: - Models

struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isFromCustomer: Bool
    let senderName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content, isFromCustomer, senderName, createdAt
    }
}

struct MessagesResponse: Codable {
    let messages: [ChatMessage]
}

#Preview {
    NavigationStack {
        ConversationView(orderId: "test-order")
    }
}
