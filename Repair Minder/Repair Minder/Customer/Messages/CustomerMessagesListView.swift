//
//  CustomerMessagesListView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerMessagesListView: View {
    @State private var viewModel = CustomerMessagesListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    LoadingView(message: "Loading messages...")
                } else if let error = viewModel.error, viewModel.conversations.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadConversations() }
                    }
                } else if viewModel.conversations.isEmpty {
                    ContentUnavailableView {
                        Label("No Messages", systemImage: "message")
                    } description: {
                        Text("Messages from repair shops will appear here")
                    }
                } else {
                    conversationList
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: Conversation.self) { conversation in
                ConversationView(orderId: conversation.orderId)
            }
            .refreshable {
                await viewModel.loadConversations()
            }
            .task {
                if viewModel.conversations.isEmpty {
                    await viewModel.loadConversations()
                }
            }
        }
    }

    private var conversationList: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink(value: conversation) {
                ConversationRow(conversation: conversation)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            // Shop avatar
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)

                Text(String(conversation.shopName.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.shopName)
                        .font(.headline)

                    Spacer()

                    if let date = conversation.lastMessageAt {
                        Text(date.relativeFormatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Order \(conversation.orderRef)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }

                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
@Observable
final class CustomerMessagesListViewModel {
    private(set) var conversations: [Conversation] = []
    private(set) var isLoading = false
    var error: String?

    func loadConversations() async {
        isLoading = true
        error = nil

        do {
            let response: ConversationsResponse = try await APIClient.shared.request(
                .customerConversations(),
                responseType: ConversationsResponse.self
            )
            conversations = response.conversations
        } catch let apiError as APIError {
            switch apiError {
            case .offline:
                error = "You're offline. Pull to refresh when connected."
            default:
                error = "Failed to load messages."
            }
        } catch {
            self.error = "An unexpected error occurred."
        }

        isLoading = false
    }
}

// MARK: - Models

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    let orderId: String
    let orderRef: String
    let shopId: String
    let shopName: String
    let lastMessage: String?
    let lastMessageAt: Date?
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case id, orderId, orderRef, shopId, shopName
        case lastMessage, lastMessageAt, unreadCount
    }
}

struct ConversationsResponse: Codable {
    let conversations: [Conversation]
}

#Preview {
    CustomerMessagesListView()
}
