//
//  OrderTrackingHeader.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderTrackingHeader: View {
    let order: CustomerOrder

    var body: some View {
        VStack(spacing: 16) {
            // Large status icon
            ZStack {
                Circle()
                    .fill(order.status.color.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: order.status.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(order.status.color)
            }

            // Status title
            Text(order.status.customerDisplayName)
                .font(.title2)
                .fontWeight(.bold)

            // Status description
            Text(order.status.customerDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Order reference
            HStack(spacing: 4) {
                Text("Order")
                    .foregroundStyle(.secondary)
                Text(order.displayRef)
                    .fontWeight(.medium)
            }
            .font(.caption)
        }
        .padding()
    }
}

#Preview {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let order = try! decoder.decode(CustomerOrder.self, from: """
        {
            "id": "test",
            "orderNumber": 123,
            "status": "in_progress",
            "deviceSummary": "iPhone 15 Pro",
            "createdAt": "2026-02-01T10:00:00Z",
            "updatedAt": "2026-02-01T10:00:00Z"
        }
        """.data(using: .utf8)!)

    return OrderTrackingHeader(order: order)
}
