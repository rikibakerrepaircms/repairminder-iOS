//
//  StatCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Spacer()

                if let change = change {
                    ChangeIndicator(percentage: change)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    HStack {
        StatCard(
            title: "Revenue",
            value: "£12,450",
            change: 12.5,
            icon: "sterlingsign.circle",
            color: .green
        )

        StatCard(
            title: "Devices",
            value: "48",
            change: -5.2,
            icon: "iphone",
            color: .blue
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
