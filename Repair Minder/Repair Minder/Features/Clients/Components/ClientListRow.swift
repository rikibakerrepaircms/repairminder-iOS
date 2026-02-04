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
        ClientListRow(client: .sample)
    }
}
