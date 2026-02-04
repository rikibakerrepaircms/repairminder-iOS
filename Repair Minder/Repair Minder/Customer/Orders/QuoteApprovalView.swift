//
//  QuoteApprovalView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

/// Full-screen quote approval view
struct QuoteApprovalView: View {
    let order: CustomerOrder
    @State private var viewModel: QuoteApprovalViewModel
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @Environment(\.dismiss) private var dismiss

    init(order: CustomerOrder) {
        self.order = order
        _viewModel = State(initialValue: QuoteApprovalViewModel(orderId: order.id))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quote header
                    QuoteHeader(order: order)

                    if viewModel.isLoading && viewModel.quote == nil {
                        ProgressView("Loading quote...")
                            .padding()
                    } else if let quote = viewModel.quote {
                        // Device breakdown
                        QuoteBreakdownCard(quote: quote)

                        // Total
                        QuoteTotalCard(quote: quote)

                        // Terms
                        QuoteTermsSection()

                        // Action buttons
                        QuoteActionButtons(
                            onApprove: {
                                Task {
                                    await viewModel.approveQuote()
                                    if viewModel.error == nil {
                                        dismiss()
                                    }
                                }
                            },
                            onReject: {
                                showRejectSheet = true
                            },
                            isLoading: viewModel.isLoading
                        )
                    } else if let error = viewModel.error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Review Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await viewModel.loadQuote()
            }
            .sheet(isPresented: $showRejectSheet) {
                RejectReasonSheet(
                    reason: $rejectReason,
                    isLoading: viewModel.isLoading,
                    onSubmit: {
                        Task {
                            await viewModel.rejectQuote(reason: rejectReason)
                            if viewModel.error == nil {
                                showRejectSheet = false
                                dismiss()
                            }
                        }
                    }
                )
            }
        }
    }
}

struct QuoteHeader: View {
    let order: CustomerOrder

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Quote Ready for Approval")
                .font(.title2)
                .fontWeight(.bold)

            Text("Order \(order.displayRef)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Quote Approval ViewModel

@MainActor
@Observable
final class QuoteApprovalViewModel {
    let orderId: String

    private(set) var quote: Quote?
    private(set) var isLoading = false
    var error: String?

    init(orderId: String) {
        self.orderId = orderId
    }

    func loadQuote() async {
        isLoading = true
        error = nil

        do {
            let response: QuoteResponse = try await APIClient.shared.request(
                .customerOrderQuote(orderId: orderId),
                responseType: QuoteResponse.self
            )
            quote = response.quote
        } catch {
            self.error = "Failed to load quote details."
        }

        isLoading = false
    }

    func approveQuote() async {
        isLoading = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(.customerApproveQuote(orderId: orderId))
        } catch {
            self.error = "Failed to approve quote. Please try again."
        }

        isLoading = false
    }

    func rejectQuote(reason: String) async {
        isLoading = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(.customerRejectQuote(orderId: orderId, reason: reason))
        } catch {
            self.error = "Failed to decline quote. Please try again."
        }

        isLoading = false
    }
}

#Preview {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let order = try! decoder.decode(CustomerOrder.self, from: """
        {
            "id": "test",
            "orderNumber": 123,
            "status": "awaiting_approval",
            "deviceSummary": "iPhone 15 Pro",
            "total": "149.99",
            "createdAt": "2026-02-01T10:00:00Z",
            "updatedAt": "2026-02-01T10:00:00Z"
        }
        """.data(using: .utf8)!)

    return QuoteApprovalView(order: order)
}
