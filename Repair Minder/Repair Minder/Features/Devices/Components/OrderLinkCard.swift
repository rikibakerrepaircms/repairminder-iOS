//
//  OrderLinkCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderLinkCard: View {
    let orderId: String
    let onNavigate: () -> Void

    var body: some View {
        Button {
            onNavigate()
        } label: {
            HStack {
                Label("View Parent Order", systemImage: "doc.text.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        OrderLinkCard(orderId: "order-123") {
            print("Navigate to order")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
