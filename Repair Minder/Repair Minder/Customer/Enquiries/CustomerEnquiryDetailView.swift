//
//  CustomerEnquiryDetailView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerEnquiryDetailView: View {
    let enquiryId: String
    @State private var viewModel: CustomerEnquiryDetailViewModel
    @State private var replyMessage = ""
    @FocusState private var isReplyFocused: Bool

    init(enquiryId: String) {
        self.enquiryId = enquiryId
        _viewModel = State(initialValue: CustomerEnquiryDetailViewModel(enquiryId: enquiryId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.enquiry == nil {
                LoadingView(message: "Loading enquiry...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.enquiry == nil {
                ErrorView(message: error) {
                    Task { await viewModel.loadEnquiry() }
                }
            } else if let enquiry = viewModel.enquiry {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        enquiryHeader(enquiry)

                        // Device info
                        deviceInfoCard(enquiry)

                        // Issue description
                        issueCard(enquiry)

                        // Conversation
                        if let replies = enquiry.replies, !replies.isEmpty {
                            conversationSection(replies)
                        }

                        // Converted order link
                        if let orderId = enquiry.convertedOrderId {
                            NavigationLink(destination: CustomerOrderDetailView(orderId: orderId)) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("View Order")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }

                // Reply input (if not closed/converted)
                if enquiry.status != .closed && enquiry.status != .converted {
                    replyInputBar
                }
            }
        }
        .navigationTitle("Enquiry")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEnquiry()
        }
    }

    // MARK: - Components

    private func enquiryHeader(_ enquiry: CustomerEnquiry) -> some View {
        VStack(spacing: 12) {
            CustomerEnquiryStatusBadge(status: enquiry.status)

            Text(enquiry.shopName)
                .font(.headline)

            Text("Submitted \(enquiry.createdAt.relativeFormatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func deviceInfoCard(_ enquiry: CustomerEnquiry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Device", systemImage: "iphone")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack {
                Text(enquiry.deviceDisplayName)
                    .font(.headline)
                Spacer()
                Text(enquiry.deviceType.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func issueCard(_ enquiry: CustomerEnquiry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Issue Description", systemImage: "exclamationmark.bubble")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(enquiry.issueDescription)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func conversationSection(_ replies: [EnquiryReply]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Conversation", systemImage: "bubble.left.and.bubble.right")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ForEach(replies) { reply in
                replyBubble(reply)
            }
        }
    }

    private func replyBubble(_ reply: EnquiryReply) -> some View {
        HStack {
            if !reply.isFromShop {
                Spacer()
            }

            VStack(alignment: reply.isFromShop ? .leading : .trailing, spacing: 4) {
                if reply.isFromShop, let name = reply.senderName {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }

                Text(reply.message)
                    .font(.subheadline)

                Text(reply.createdAt.relativeFormatted())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(reply.isFromShop ? Color(.secondarySystemBackground) : Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if reply.isFromShop {
                Spacer()
            }
        }
    }

    private var replyInputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $replyMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isReplyFocused)

            Button {
                Task {
                    await viewModel.sendReply(message: replyMessage)
                    replyMessage = ""
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(replyMessage.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSending)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class CustomerEnquiryDetailViewModel {
    let enquiryId: String

    private(set) var enquiry: CustomerEnquiry?
    private(set) var isLoading = false
    private(set) var isSending = false
    var error: String?

    init(enquiryId: String) {
        self.enquiryId = enquiryId
    }

    func loadEnquiry() async {
        isLoading = true
        error = nil

        do {
            let response: CustomerEnquiryDetailResponse = try await APIClient.shared.request(
                .customerEnquiry(id: enquiryId),
                responseType: CustomerEnquiryDetailResponse.self
            )
            enquiry = response.enquiry
        } catch {
            self.error = "Failed to load enquiry details."
        }

        isLoading = false
    }

    func sendReply(message: String) async {
        isSending = true

        do {
            try await APIClient.shared.requestVoid(
                .customerEnquiryReply(enquiryId: enquiryId, message: message)
            )
            await loadEnquiry()
        } catch {
            self.error = "Failed to send message."
        }

        isSending = false
    }
}

struct CustomerEnquiryDetailResponse: Codable {
    let enquiry: CustomerEnquiry
}

#Preview {
    NavigationStack {
        CustomerEnquiryDetailView(enquiryId: "test-id")
    }
}
