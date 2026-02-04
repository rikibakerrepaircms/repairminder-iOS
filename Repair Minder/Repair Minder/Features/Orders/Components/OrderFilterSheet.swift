//
//  OrderFilterSheet.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderFilterSheet: View {
    @ObservedObject var viewModel: OrderListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button {
                            viewModel.toggleFilter(status: status)
                        } label: {
                            HStack {
                                Image(systemName: viewModel.selectedStatuses.contains(status)
                                    ? "checkmark.square.fill"
                                    : "square")
                                    .foregroundStyle(viewModel.selectedStatuses.contains(status) ? .blue : .secondary)
                                    .font(.title3)

                                OrderStatusBadge(status: status, size: .small)
                                Text(status.displayName)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } header: {
                    Text("Status")
                } footer: {
                    if viewModel.selectedStatuses.isEmpty {
                        Text("No filters applied - showing all orders")
                    } else {
                        Text("\(viewModel.selectedStatuses.count) status\(viewModel.selectedStatuses.count == 1 ? "" : "es") selected")
                    }
                }
            }
            .navigationTitle("Filter Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.hasActiveFilters {
                        Button("Clear") {
                            viewModel.clearFilters()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    OrderFilterSheet(viewModel: OrderListViewModel())
}
