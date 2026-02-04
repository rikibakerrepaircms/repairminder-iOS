//
//  ClientStatsCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientStatsCard: View {
    let client: Client

    var body: some View {
        HStack {
            StatItem(title: "Orders", value: "\(client.orderCount)")
            Divider()
            StatItem(title: "Total Spent", value: formatCurrency(client.totalSpent))
            Divider()
            StatItem(title: "Since", value: client.createdAt.formatted(as: .medium))
        }
        .frame(height: 60)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

private struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ClientStatsCard(client: Client(
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
        orderCount: 15,
        totalSpent: 2450,
        createdAt: Date().addingTimeInterval(-86400 * 365),
        updatedAt: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}
