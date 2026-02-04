//
//  DeviceListView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @Environment(AppRouter.self) var router
    @State private var showFilter = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                LoadingView(message: "Loading devices...")
            } else if viewModel.devices.isEmpty {
                EmptyStateView(
                    icon: "iphone",
                    title: "No Devices",
                    message: viewModel.isQueueMode
                        ? "Your queue is empty"
                        : "No devices match your criteria"
                )
            } else {
                devicesList
            }
        }
        .navigationTitle(viewModel.isQueueMode ? "My Queue" : "Devices")
        .searchable(text: $viewModel.searchText, prompt: "Search devices...")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Mode", selection: $viewModel.isQueueMode) {
                    Text("My Queue").tag(true)
                    Text("All").tag(false)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilter = true
                } label: {
                    Image(systemName: viewModel.hasActiveFilters
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showFilter) {
            DeviceFilterSheet(viewModel: viewModel)
        }
        .task {
            if viewModel.devices.isEmpty {
                await viewModel.loadDevices()
            }
        }
        .onChange(of: viewModel.isQueueMode) { _, _ in
            Task { await viewModel.loadDevices() }
        }
    }

    private var devicesList: some View {
        List {
            ForEach(viewModel.devices) { device in
                DeviceListRow(device: device)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.navigate(to: .deviceDetail(id: device.id))
                    }
            }

            if viewModel.hasMorePages {
                HStack {
                    Spacer()
                    ProgressView()
                        .onAppear {
                            Task { await viewModel.loadMore() }
                        }
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .deviceDetail(let id):
            DeviceDetailView(deviceId: id)
        case .orderDetail(let id):
            OrderDetailView(orderId: id)
        default:
            EmptyView()
        }
    }
}

// MARK: - Device List Row

struct DeviceListRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.displayName)
                        .font(.headline)

                    DeviceStatusBadge(status: device.status)
                }

                if let issue = device.issue, !issue.isEmpty {
                    Text(issue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let assignedName = device.assignedUserName {
                    Label(assignedName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let price = device.price {
                    Text(formatCurrency(price))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text(device.createdAt.formatted(as: .short))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

// MARK: - Filter Sheet

struct DeviceFilterSheet: View {
    @ObservedObject var viewModel: DeviceListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DeviceStatus.allCases, id: \.self) { status in
                        Button {
                            viewModel.toggleFilter(status: status)
                        } label: {
                            HStack {
                                Image(systemName: viewModel.selectedStatuses.contains(status)
                                    ? "checkmark.square.fill"
                                    : "square")
                                    .foregroundStyle(viewModel.selectedStatuses.contains(status) ? .blue : .secondary)
                                    .font(.title3)

                                DeviceStatusBadge(status: status)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Status")
                } footer: {
                    if viewModel.selectedStatuses.isEmpty {
                        Text("No filters applied - showing all devices")
                    } else {
                        Text("\(viewModel.selectedStatuses.count) status\(viewModel.selectedStatuses.count == 1 ? "" : "es") selected")
                    }
                }
            }
            .navigationTitle("Filter Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.hasActiveFilters {
                        Button("Clear") {
                            viewModel.clearFilters()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    DeviceListView()
        .environment(AppRouter())
}
