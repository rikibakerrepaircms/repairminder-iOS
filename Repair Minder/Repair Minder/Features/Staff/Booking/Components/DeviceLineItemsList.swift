//
//  DeviceLineItemsList.swift
//  Repair Minder
//

import SwiftUI

struct DeviceLineItemsList: View {
    @Binding var items: [BookingLineItem]
    let currencyCode: String

    @State private var showSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("Services / Parts", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    showSearch.toggle()
                } label: {
                    Label("Add Service", systemImage: "plus")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }

            // Search (expandable)
            if showSearch {
                BookingProductSearch(
                    onSelect: { item in
                        items.append(item)
                        showSearch = false
                    },
                    onCancel: { showSearch = false }
                )
            }

            // Line items list
            if !items.isEmpty {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            Text(item.description)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(CurrencyFormatter.format(item.unitPrice))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Button {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.platformBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Subtotal
                    HStack {
                        Spacer()
                        Text("Subtotal:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(
                            items.reduce(0) { $0 + $1.unitPrice * Double($1.quantity) }
                        ))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.top, 8)
    }
}
