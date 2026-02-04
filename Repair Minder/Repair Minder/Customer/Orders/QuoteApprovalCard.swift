//
//  QuoteApprovalCard.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct QuoteApprovalCard: View {
    let order: CustomerOrder
    let quote: Quote?
    let isLoading: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Alert banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Action Required")
                        .font(.headline)

                    Text("Please review and approve the repair quote")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Quote breakdown
            if let quote = quote {
                QuoteBreakdownCard(quote: quote)
                QuoteTotalCard(quote: quote)
            } else if let total = order.total {
                // Simple total display if full quote not available
                HStack {
                    Text("Quoted Total")
                        .font(.subheadline)
                    Spacer()
                    Text(total.formatted(.currency(code: "GBP")))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Terms
            QuoteTermsSection()

            // Action buttons
            QuoteActionButtons(
                onApprove: onApprove,
                onReject: onReject,
                isLoading: isLoading
            )
        }
        .padding(.horizontal)
    }
}

struct QuoteBreakdownCard: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repair Details")
                .font(.headline)

            ForEach(quote.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description)
                            .font(.subheadline)

                        if let deviceName = item.deviceName {
                            Text(deviceName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if item.quantity > 1 {
                        Text("\(item.quantity) x ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.price.formatted(.currency(code: "GBP")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if item.id != quote.items.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuoteTotalCard: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                Spacer()
                Text(quote.subtotal.formatted(.currency(code: "GBP")))
            }
            .font(.subheadline)

            if quote.vat > 0 {
                HStack {
                    Text("VAT (20%)")
                    Spacer()
                    Text(quote.vat.formatted(.currency(code: "GBP")))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text(quote.total.formatted(.currency(code: "GBP")))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            if quote.depositPaid > 0 {
                HStack {
                    Text("Deposit Paid")
                    Spacer()
                    Text("-\(quote.depositPaid.formatted(.currency(code: "GBP")))")
                }
                .font(.subheadline)
                .foregroundStyle(.green)

                HStack {
                    Text("Balance Due")
                        .fontWeight(.medium)
                    Spacer()
                    Text(quote.balanceDue.formatted(.currency(code: "GBP")))
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuoteTermsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By approving this quote:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("You authorize us to proceed with the repair")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Payment is due upon collection")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuoteActionButtons: View {
    let onApprove: () -> Void
    let onReject: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onApprove()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Approve Quote", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .disabled(isLoading)

            Button(role: .destructive) {
                onReject()
            } label: {
                Label("Decline Quote", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isLoading)
        }
    }
}

struct RejectReasonSheet: View {
    @Binding var reason: String
    let isLoading: Bool
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Please tell us why you're declining this quote")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $reason)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                Text("Common reasons: too expensive, no longer needed, found alternative")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding()
            .navigationTitle("Decline Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isLoading)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit()
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
        .presentationDetents([.medium])
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

    return ScrollView {
        QuoteApprovalCard(
            order: order,
            quote: nil,
            isLoading: false,
            onApprove: {},
            onReject: {}
        )
    }
}
