//
//  QuickActionsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct QuickActionsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "New Order",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    router.selectedTab = .orders
                }

                QuickActionButton(
                    title: "Scan",
                    icon: "qrcode.viewfinder",
                    color: .green
                ) {
                    router.navigate(to: .scanner)
                }

                QuickActionButton(
                    title: "Devices",
                    icon: "iphone",
                    color: .orange
                ) {
                    router.navigate(to: .devices)
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickActionsView()
        .environment(AppRouter())
        .padding()
}
