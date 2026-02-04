//
//  RecentOrdersView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct RecentOrdersSection: View {
    let orders: [Order]
    let currencySymbol: String
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Orders")
                    .font(.headline)

                Spacer()

                Button("See All") {
                    router.selectedTab = .orders
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(orders) { order in
                    RecentOrderRow(order: order, currencySymbol: currencySymbol)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.navigate(to: .orderDetail(id: order.id))
                        }

                    if order.id != orders.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct RecentOrderRow: View {
    let order: Order
    let currencySymbol: String

    var body: some View {
        HStack(spacing: 12) {
            // Order Number Badge
            Text(order.displayRef)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(order.clientName ?? order.clientEmail ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let total = order.total {
                    Text("\(currencySymbol)\(NSDecimalNumber(decimal: total).intValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(order.createdAt.relativeFormatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var statusColor: Color {
        switch order.status {
        case .bookedIn: return .blue
        case .inProgress: return .orange
        case .awaitingParts: return .yellow
        case .ready: return .green
        case .collected: return .gray
        case .cancelled: return .red
        }
    }
}

#Preview {
    RecentOrdersSection(orders: [], currencySymbol: "£")
        .environment(AppRouter())
}
