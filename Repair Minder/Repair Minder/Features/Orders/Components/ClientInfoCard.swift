//
//  ClientInfoCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientInfoCard: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Client", systemImage: "person.fill")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                if let name = order.clientName {
                    HStack(spacing: 8) {
                        Image(systemName: "person")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(name)
                            .font(.subheadline)
                    }
                }

                if let email = order.clientEmail {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let phone = order.clientPhone {
                    HStack(spacing: 8) {
                        Image(systemName: "phone")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ClientInfoCard(order: Order(
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
    .padding()
    .background(Color(.systemGroupedBackground))
}
