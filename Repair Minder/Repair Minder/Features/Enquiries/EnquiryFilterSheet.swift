//
//  EnquiryFilterSheet.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryFilterSheet: View {
    @ObservedObject var viewModel: EnquiryListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: EnquiryFilter
    @State private var sortOrder: SortOrder = .newest

    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case unread = "Unread First"
    }

    init(viewModel: EnquiryListViewModel) {
        self.viewModel = viewModel
        _selectedFilter = State(initialValue: viewModel.selectedFilter)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Status Filter") {
                    ForEach(EnquiryFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            HStack {
                                Text(filter.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if let count = viewModel.filterCounts[filter], count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }

                                if selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Sort By") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Enquiries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedFilter = .all
                        sortOrder = .newest
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.selectedFilter = selectedFilter
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    EnquiryFilterSheet(viewModel: EnquiryListViewModel())
}
