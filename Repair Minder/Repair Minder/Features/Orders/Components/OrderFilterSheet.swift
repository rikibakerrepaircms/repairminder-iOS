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
                Section("Status") {
                    Button {
                        viewModel.applyFilter(status: nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("All Statuses")
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.selectedStatus == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button {
                            viewModel.applyFilter(status: status)
                            dismiss()
                        } label: {
                            HStack {
                                OrderStatusBadge(status: status, size: .small)
                                Text(status.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if viewModel.selectedStatus == status {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
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
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    OrderFilterSheet(viewModel: OrderListViewModel())
}
