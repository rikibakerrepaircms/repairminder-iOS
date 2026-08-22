//
//  ConvertEnquiryToOrderSheet.swift
//  Repair Minder
//

import SwiftUI

/// Turns an enquiry into an order without leaving the ticket. Mirrors the web
/// convert modal (TicketDetailPage): pick a service type, then run the normal
/// booking wizard with the client details and location already filled in and
/// `existingTicketId` set, so POST /api/orders adopts this ticket instead of
/// opening a new one.
///
/// Intake defaults to `.collection` because the reason this lives on the phone
/// is doorstep pickups — staff can still switch it on the Customer step.
struct ConvertEnquiryToOrderSheet: View {
    let ticket: Ticket
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BookingViewModel()
    @State private var selectedServiceType: ServiceType?

    /// Repair and buyback are the two conversion targets, matching the web
    /// modal's SERVICE_TYPE_OPTIONS. Accessories and device sales are their own
    /// counter flows and never start life as an enquiry.
    private var availableServiceTypes: [ServiceType] {
        viewModel.buybackEnabled ? [.repair, .buyback] : [.repair]
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingLocations {
                    ProgressView("Loading...")
                } else if availableServiceTypes.count == 1, let onlyType = availableServiceTypes.first {
                    // Buyback disabled — nothing to choose, go straight in.
                    Color.clear
                        .onAppear { selectedServiceType = onlyType }
                } else {
                    serviceTypePicker
                }
            }
            .navigationTitle("Convert to Order")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedServiceType) { serviceType in
                BookingWizardView(
                    viewModel: viewModel,
                    serviceType: serviceType,
                    title: "Convert to Order",
                    onComplete: {
                        onComplete()
                        dismiss()
                    }
                )
            }
        }
        .task {
            // Prefill first: loadTermsAndConditions only applies company
            // country defaults while existingClientId is still nil.
            viewModel.prefill(fromTicket: ticket)
            viewModel.formData.intakeMethod = .collection
            // A sell lead converts to a buyback order and a repair lead to a
            // repair order. Staff can still change it on the next screen.
            if ticket.enquiryKind == CustomerEnquiryKind.sell {
                selectedServiceType = viewModel.buybackEnabled ? .buyback : .repair
            } else if ticket.enquiryKind == CustomerEnquiryKind.repairOrder {
                selectedServiceType = .repair
            }
            await viewModel.loadInitialData()
        }
    }

    private var serviceTypePicker: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("What is this order for?")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(ticket.client?.displayName ?? ticket.subject)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(availableServiceTypes) { serviceType in
                    ServiceTypeCard(serviceType: serviceType) {
                        selectedServiceType = serviceType
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

#Preview {
    ConvertEnquiryToOrderSheet(
        ticket: Ticket(
            id: "ticket-1",
            ticketNumber: 100000001,
            subject: "Selling my iPhone 14",
            status: .open,
            ticketType: .lead,
            assignedUserId: nil,
            assignedUser: nil,
            mergedIntoTicketId: nil,
            locationId: nil,
            location: nil,
            requiresLocation: nil,
            receivedCustomEmail: nil,
            lastReplyFromCustomEmailId: nil,
            createdAt: "2026-07-25T10:00:00Z",
            updatedAt: "2026-07-25T10:00:00Z",
            lastClientUpdate: nil,
            client: nil,
            messages: nil,
            order: nil,
            notes: nil,
            smsAvailable: nil,
            smsRemaining: nil,
            smsAlreadySent: nil,
            enquiryKind: "sell",
            fulfilment: "collection",
            collectionSlot: nil,
            sellDeclaration: nil,
            buybackLabels: nil
        ),
        onComplete: {}
    )
}
