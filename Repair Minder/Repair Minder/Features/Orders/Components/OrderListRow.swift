//
//  OrderListRow.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderListRow: View {
    let order: Order

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(order.displayRef)
                        .font(.headline)

                    OrderStatusBadge(status: order.status)
                }

                Text(order.clientName ?? order.clientEmail ?? "Unknown Client")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let total = order.total {
                    Text(formatCurrency(total))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(order.createdAt.formatted(as: .short))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

#Preview {
    List {
        OrderListRow(order: Order(
            id: "1",
            orderNumber: 1234,
            status: .inProgress,
            total: 150.00,
            deposit: 50.00,
            balance: 100.00,
            notes: nil,
            clientId: "c1",
            clientName: "John Smith",
            clientEmail: "john@example.com",
            clientPhone: "07123456789",
            locationId: nil,
            locationName: nil,
            assignedUserId: nil,
            assignedUserName: nil,
            deviceCount: 2,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
