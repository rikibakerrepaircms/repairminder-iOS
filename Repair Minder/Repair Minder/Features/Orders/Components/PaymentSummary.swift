//
//  PaymentSummary.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct PaymentSummary: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Payment", systemImage: "creditcard")
                .font(.headline)

            VStack(spacing: 8) {
                if let total = order.total {
                    PaymentRow(label: "Total", value: formatCurrency(total))
                }
                if let deposit = order.deposit, deposit > 0 {
                    PaymentRow(label: "Deposit", value: formatCurrency(deposit))
                }
                if let balance = order.balance {
                    PaymentRow(
                        label: "Balance",
                        value: formatCurrency(balance),
                        highlight: balance > 0
                    )
                }

                if order.isPaid {
                    HStack {
                        Spacer()
                        Label("Paid", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

struct PaymentRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(highlight ? .semibold : .regular)
                .foregroundStyle(highlight ? .primary : .secondary)
        }
        .font(.subheadline)
    }
}

#Preview {
    VStack(spacing: 20) {
        PaymentSummary(order: Order(
            id: "1",
            orderNumber: 1234,
            status: .inProgress,
            total: 150.00,
            deposit: 50.00,
            balance: 100.00,
            notes: nil,
            clientId: "c1",
            clientName: "John Smith",
            clientEmail: nil,
            clientPhone: nil,
            locationId: nil,
            locationName: nil,
            assignedUserId: nil,
            assignedUserName: nil,
            deviceCount: 2,
            createdAt: Date(),
            updatedAt: Date()
        ))

        PaymentSummary(order: Order(
            id: "2",
            orderNumber: 1235,
            status: .collected,
            total: 200.00,
            deposit: 200.00,
            balance: 0,
            notes: nil,
            clientId: "c1",
            clientName: "Jane Doe",
            clientEmail: nil,
            clientPhone: nil,
            locationId: nil,
            locationName: nil,
            assignedUserId: nil,
            assignedUserName: nil,
            deviceCount: 1,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
