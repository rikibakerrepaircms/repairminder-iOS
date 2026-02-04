//
//  ClientListRow.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientListRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            ClientAvatar(name: client.displayName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(client.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(client.orderCount) orders")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatCurrency(client.totalSpent))
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

#Preview {
    List {
        ClientListRow(client: Client(
            id: "1",
            email: "john@example.com",
            firstName: "John",
            lastName: "Smith",
            phone: "07123456789",
            company: nil,
            address: nil,
            city: nil,
            postcode: nil,
            notes: nil,
            orderCount: 5,
            totalSpent: 450,
            createdAt: Date(),
            updatedAt: Date()
        ))
        ClientListRow(client: Client(
            id: "2",
            email: "jane@example.com",
            firstName: "Jane",
            lastName: "Doe",
            phone: nil,
            company: "Acme Corp",
            address: nil,
            city: nil,
            postcode: nil,
            notes: nil,
            orderCount: 12,
            totalSpent: 1250,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
