//
//  OrderHistorySection.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderHistorySection: View {
    let orders: [Order]
    let hasMore: Bool
    let onTapOrder: (String) -> Void
    let onLoadMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order History")
                .font(.headline)
                .padding(.horizontal, 4)

            if orders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No orders yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(orders) { order in
                        OrderHistoryRow(order: order)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onTapOrder(order.id)
                            }

                        if order.id != orders.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }

                    if hasMore {
                        Divider()
                            .padding(.leading, 16)
                        HStack {
                            Spacer()
                            ProgressView()
                                .onAppear {
                                    onLoadMore()
                                }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct OrderHistoryRow: View {
    let order: Order

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(order.displayRef)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    OrderStatusBadge(status: order.status, size: .small)
                }

                Text(order.createdAt.formatted(as: .medium))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let total = order.total {
                    Text(formatCurrency(total))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            OrderHistorySection(
                orders: [
                    Order(
                        id: "1",
                        orderNumber: 1234,
                        status: .collected,
                        total: 150,
                        deposit: 50,
                        balance: 0,
                        notes: nil,
                        clientId: "c1",
                        clientName: "John Smith",
                        clientEmail: nil,
                        clientPhone: nil,
                        locationId: nil,
                        locationName: nil,
                        assignedUserId: nil,
                        assignedUserName: nil,
                        deviceCount: 2,
                        createdAt: Date().addingTimeInterval(-86400 * 30),
                        updatedAt: Date()
                    ),
                    Order(
                        id: "2",
                        orderNumber: 1189,
                        status: .inProgress,
                        total: 85,
                        deposit: nil,
                        balance: 85,
                        notes: nil,
                        clientId: "c1",
                        clientName: "John Smith",
                        clientEmail: nil,
                        clientPhone: nil,
                        locationId: nil,
                        locationName: nil,
                        assignedUserId: nil,
                        assignedUserName: nil,
                        deviceCount: 1,
                        createdAt: Date().addingTimeInterval(-86400 * 7),
                        updatedAt: Date()
                    )
                ],
                hasMore: false,
                onTapOrder: { _ in },
                onLoadMore: {}
            )

            OrderHistorySection(
                orders: [],
                hasMore: false,
                onTapOrder: { _ in },
                onLoadMore: {}
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
