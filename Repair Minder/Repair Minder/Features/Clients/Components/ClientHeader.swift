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

            if let groupName = client.clientGroupName, !groupName.isEmpty {
                Text(groupName)
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
        ClientHeader(client: .sample)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
