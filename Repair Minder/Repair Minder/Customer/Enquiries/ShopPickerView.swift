//
//  ShopPickerView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ShopPickerView: View {
    @Binding var selectedShop: Shop?
    @State private var viewModel = ShopPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Loading shops...")
                } else if let error = viewModel.error {
                    ErrorView(message: error) {
                        Task { await viewModel.loadPreviousShops() }
                    }
                } else if viewModel.previousShops.isEmpty {
                    ContentUnavailableView {
                        Label("No Previous Shops", systemImage: "building.2")
                    } description: {
                        Text("You haven't used any repair shops yet")
                    }
                } else {
                    shopList
                }
            }
            .navigationTitle("Select Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadPreviousShops()
            }
        }
    }

    private var shopList: some View {
        List(viewModel.previousShops) { shop in
            Button {
                selectedShop = shop
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shop.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let address = shop.address {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Label("\(shop.orderCount) orders", systemImage: "doc.text")

                            if let lastUsed = shop.lastOrderDate {
                                Text("•")
                                Text("Last: \(lastUsed.relativeFormatted())")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if selectedShop?.id == shop.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    ShopPickerView(selectedShop: .constant(nil))
}
