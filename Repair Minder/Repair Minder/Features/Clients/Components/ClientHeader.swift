//
//  ClientHeader.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientHeader: View {
    let client: Client

    var body: some View {
        VStack(spacing: 12) {
            ClientAvatar(name: client.displayName, size: 80)

            Text(client.displayName)
                .font(.title2)
                .fontWeight(.bold)

            Text(client.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let phone = client.phone, !phone.isEmpty {
                Text(phone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let company = client.company, !company.isEmpty {
                Text(company)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 20) {
        ClientHeader(client: Client(
            id: "1",
            email: "john@example.com",
            firstName: "John",
            lastName: "Smith",
            phone: "07123456789",
            company: "Acme Corp",
            address: nil,
            city: nil,
            postcode: nil,
            notes: nil,
            orderCount: 5,
            totalSpent: 450,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
