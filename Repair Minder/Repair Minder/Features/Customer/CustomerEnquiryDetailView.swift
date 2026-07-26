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

                // FIRST of the three cards, because it holds the only pending action
                // on the screen: an offered window is not booked until the seller
                // taps "That time works". Renders nothing when no collection is in
                // play, which is most enquiries.
                if let slot = viewModel.collectionSlot {
                    CustomerCollectionSlotCard(
                        slot: slot,
                        isBusy: viewModel.isUpdatingSlot,
                        errorMessage: viewModel.slotError,
                        // Keys the prep checklist's ticks to this collection.
                        ticketId: viewModel.ticketId,
                        // Forks the prep checklist between the sell and repair
                        // task lists.
                        kind: enquiry.enquiryKind,
                        onConfirm: { Task { await viewModel.confirmCollectionSlot() } },
                        onRequest: { date, window in
                            Task { await viewModel.requestCollectionSlot(date: date, window: window) }
                        }
                    )
                }

                // EVERY SELL ORDER, not just a walk-in.
                //
                // This was gated on `fulfilment == "visit"`, which made the apps the
                // odd one out: buildSellOrderConfirmationEmail already puts
                // `dropOffText` - address, hours and the order ID to quote - on EVERY
                // branch, because the address is not an alternative route, it is
                // where we are, and a seller who finds themselves passing should not
                // have to hunt for it. The only condition left is a location on file;
                // the card renders nothing without one.
                //
                // BELOW the collection card on purpose - that card holds the only
                // pending action on the screen. A walk-in has no slot, so this is
                // still the first card they see. The endpoint orders locations by
                // is_primary DESC, so the first entry is the ticket's own shop, or
                // the primary one when it is assigned to none.
                if viewModel.showsNextSteps {
                    CustomerShopVisitCard(
                        location: enquiry.company?.locations?.first,
                        ticketNumber: enquiry.ticketNumber
                    )
                }

                if viewModel.showsNextSteps {
                    if enquiry.isRepairOrder {
                        CustomerRepairNextStepsCard(
                            ticketId: viewModel.ticketId,
                            fulfilment: enquiry.fulfilment
                        )
                    } else {
                        CustomerSellNextStepsCard(
                            ticketId: viewModel.ticketId,
                            fulfilment: enquiry.fulfilment
                        )
                    }
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

            // ORDERS ONLY. This is the reference staff ask for on the phone about an
            // open order, so on an order it has to be findable without hunting and
            // readable out loud - it used to be a footnote sharing a line with the date.
            //
            // An ordinary enquiry gets none of this and keeps the line it always had:
            // someone who asked us a question has no order, and does not need a
            // reference set in title type. Twin of the block in
            // CustomerEnquiryDetailPage.tsx.
            if enquiry.isOrder {
                VStack(alignment: .leading, spacing: 1) {
                    Text("ORDER ID")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text("\(enquiry.ticketNumber)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .textSelection(.enabled)
                    Text("Quote this if you get in touch with us.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    /// On an ORDER the reference has its own block below, so this is just the date.
    /// An ordinary enquiry keeps the reference here, where it has always been.
    private func subtitle(_ enquiry: CustomerEnquiryDetail) -> String {
        var parts: [String] = []
        if !enquiry.isOrder { parts.append("Enquiry #\(enquiry.ticketNumber)") }
        if let created = enquiry.createdAt { parts.append(DateFormatters.formatHumanDate(created)) }
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
