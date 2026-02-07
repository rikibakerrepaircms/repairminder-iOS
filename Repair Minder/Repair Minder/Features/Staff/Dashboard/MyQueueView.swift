//
//  MyQueueView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Navigation

/// Navigation target for device detail
private struct DeviceNavigation: Hashable {
    let orderId: String
    let deviceId: String
}

// MARK: - My Queue View

/// Staff work queue showing devices assigned to the current user
struct MyQueueView: View {
    @State private var viewModel = MyQueueViewModel()
    @State private var searchText = ""
    @State private var deviceNavigation: DeviceNavigation?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isRegularWidth {
            iPadBody
        } else {
            iPhoneBody
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneBody: some View {
        NavigationStack {
            queueContent(wideRows: false)
                .navigationDestination(item: $deviceNavigation) { nav in
                    DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
                }
        }
    }

    // MARK: - iPad Layout

    private var iPadBody: some View {
        AnimatedSplitView(showDetail: deviceNavigation != nil) {
            NavigationStack {
                queueContent(wideRows: false)
            }
        } detail: {
            if let nav = deviceNavigation {
                NavigationStack {
                    DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
                }
                .id("\(nav.orderId)-\(nav.deviceId)")
            }
        }
    }

    // MARK: - Shared Queue Content

    @ViewBuilder
    private func queueContent(wideRows: Bool) -> some View {
        VStack(spacing: 0) {
            filterHeader

            if viewModel.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                deviceList(wideRows: wideRows)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadQueue()
        }
        .overlay {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView()
            }
        }
    }

    // MARK: - Filter Header

    private var filterHeader: some View {
        VStack(spacing: 6) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search devices...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            await viewModel.setSearch(newValue)
                        }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task { await viewModel.clearSearch() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .cornerRadius(8)

            // Category Filter Boxes
            HStack(spacing: 4) {
                ForEach(QueueCategory.allCases) { category in
                    QueueCategoryBox(
                        category: category,
                        count: count(for: category),
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        Task {
                            await viewModel.setCategory(category)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGroupedBackground))
    }

    private func count(for category: QueueCategory) -> Int {
        let counts = viewModel.categoryCounts
        switch category {
        case .all: return counts.total
        case .repair: return counts.repair ?? 0
        case .buyback: return counts.buyback ?? 0
        case .unassigned: return counts.unassigned ?? 0
        }
    }

    // MARK: - Device List

    @ViewBuilder
    private func deviceList(wideRows: Bool) -> some View {
        List {
            ForEach(viewModel.devices) { device in
                DeviceQueueRow(device: device, isCompact: !wideRows) {
                    if let orderId = device.orderId {
                        deviceNavigation = DeviceNavigation(orderId: orderId, deviceId: device.id)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(
                    isRegularWidth && deviceNavigation?.deviceId == device.id
                        ? Color.accentColor.opacity(0.1)
                        : Color(.secondarySystemGroupedBackground)
                )
                .onAppear {
                    Task {
                        await viewModel.loadMoreIfNeeded(currentItem: device)
                    }
                }
            }

            // Loading more indicator
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .hidesBookingFABOnScroll()
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(viewModel.emptyMessage)
                .font(.headline)
                .foregroundStyle(.secondary)

            if viewModel.selectedCategory != .all || !viewModel.searchText.isEmpty {
                Button("Clear Filters") {
                    Task {
                        viewModel.selectedCategory = .all
                        await viewModel.clearSearch()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
    }

    private var emptyStateIcon: String {
        switch viewModel.selectedCategory {
        case .all:
            return "tray"
        case .repair:
            return "wrench.and.screwdriver"
        case .buyback:
            return "arrow.triangle.2.circlepath"
        case .unassigned:
            return "questionmark.folder"
        }
    }
}

// MARK: - Queue Category Box

private struct QueueCategoryBox: View {
    let category: QueueCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(count)")
                    .font(.caption.bold())
                Text(category.shortLabel)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? category.color.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? category.color : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MyQueueView()
}
