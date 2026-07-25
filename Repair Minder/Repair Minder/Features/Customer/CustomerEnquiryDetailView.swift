//
//  CustomerEnquiryDetailView.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import SwiftUI

/// Customer-facing enquiry detail: subject, status, the sell next-steps card,
/// the message thread and a reply box.
///
/// The equivalent of `src/pages/customer/CustomerEnquiryDetailPage.tsx` in the web
/// portal. Not to be confused with `Features/Staff/Enquiries/EnquiryDetailView`,
/// which is the staff ticket screen.
///
/// Pushed onto an existing NavigationStack - it deliberately does not create its
/// own, so it works from the order list, the enquiry list and iPad detail panes.
struct CustomerEnquiryDetailView: View {
    @StateObject private var viewModel: CustomerEnquiryDetailViewModel

    init(ticketId: String) {
        _viewModel = StateObject(wrappedValue: CustomerEnquiryDetailViewModel(ticketId: ticketId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.enquiry == nil {
                LottieLoadingView(size: 100, message: "Loading enquiry...")
            } else if let error = viewModel.errorMessage, viewModel.enquiry == nil {
                errorView(error)
            } else if let enquiry = viewModel.enquiry {
                content(enquiry)
            }
        }
        .navigationTitle("Enquiry")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Content

    private func content(_ enquiry: CustomerEnquiryDetail) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                header(enquiry)

                // Sell orders only. Directly under the header and above the
                // messages, because it is the first thing someone who has just
                // agreed to sell a device needs to read. A nil enquiry_kind is an
                // ordinary enquiry and renders nothing here.
                // Above the next steps: someone with a window waiting on them should
                // not have to read four generic steps first. Renders nothing when no
                // collection is in play.
                if let slot = viewModel.collectionSlot {
                    CustomerCollectionSlotCard(
                        slot: slot,
                        isBusy: viewModel.isUpdatingSlot,
                        errorMessage: viewModel.slotError,
                        onConfirm: { Task { await viewModel.confirmCollectionSlot() } },
                        onRequest: { date, window in
                            Task { await viewModel.requestCollectionSlot(date: date, window: window) }
                        }
                    )
                }

                if viewModel.showsSellNextSteps {
                    CustomerSellNextStepsCard(ticketId: viewModel.ticketId, fulfilment: enquiry.fulfilment)
                }

                messagesSection(enquiry)
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Header

    private func header(_ enquiry: CustomerEnquiryDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(enquiry.displaySubject)
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statusBadge(enquiry.status)
            }

            Text(subtitle(enquiry))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func subtitle(_ enquiry: CustomerEnquiryDetail) -> String {
        var parts = ["Enquiry #\(enquiry.ticketNumber)"]
        if let created = enquiry.createdAt {
            parts.append(DateFormatters.formatHumanDate(created))
        }
        return parts.joined(separator: " · ")
    }

    private func statusBadge(_ status: String) -> some View {
        let color = statusColor(status)
        return Text(CustomerEnquiryStatus.label(for: status))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "pending": return .orange
        case "resolved": return .blue
        case "closed": return .gray
        default: return .green
        }
    }

    // MARK: - Messages

    private func messagesSection(_ enquiry: CustomerEnquiryDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Messages")
                .font(.headline)

            if !viewModel.isClosed {
                replyBox
            }

            if enquiry.messages.isEmpty {
                Text("No messages yet. Send a message above to get in touch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(enquiry.messages) { message in
                    CustomerMessageBubble(message: message)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var replyBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type your message here...", text: $viewModel.replyText, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isSendingReply)

            if let replyError = viewModel.replyError {
                Text(replyError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button {
                    Task { await viewModel.sendReply() }
                } label: {
                    if viewModel.isSendingReply {
                        Label("Sending...", systemImage: "clock")
                    } else {
                        Label("Send Message", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isSendingReply
                    || viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomerEnquiryDetailView(ticketId: "test-ticket-id")
    }
}
