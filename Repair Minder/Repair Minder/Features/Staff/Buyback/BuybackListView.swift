//
//  BuybackListView.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import SwiftUI

struct BuybackListView: View {
    var isEmbedded: Bool = false
    var onBack: (() -> Void)? = nil

    @StateObject private var viewModel = BuybackListViewModel()
    @State private var selectedItemId: String?
    @State private var showPurchasePrice = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        Group {
            if isEmbedded {
                embeddedBody
            } else if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await viewModel.loadItems()
        }
    }

    // MARK: - Embedded Layout (inside another NavigationStack)

    private var embeddedBody: some View {
        VStack(spacing: 0) {
            filterHeader
            mainContent
        }
        .navigationTitle("Buyback")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(for: String.self) { itemId in
            BuybackDetailView(buybackId: itemId)
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterHeader
                mainContent
            }
            .navigationTitle("Buyback")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: String.self) { itemId in
                BuybackDetailView(buybackId: itemId)
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        AnimatedSplitView(showDetail: selectedItemId != nil) {
            NavigationStack {
                VStack(spacing: 0) {
                    filterHeader
                    mainContent
                }
                .navigationTitle("Buyback")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if let onBack {
                            Button {
                                onBack()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Settings")
                                }
                            }
                        }
                    }
                }
            }
        } detail: {
            if let itemId = selectedItemId {
                NavigationStack {
                    BuybackDetailView(buybackId: itemId)
                }
                .id(itemId)
            }
        }
    }

    // MARK: - Shared Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            loadingView
        } else if let error = viewModel.error, viewModel.items.isEmpty {
            errorView(error)
        } else if viewModel.items.isEmpty {
            emptyView
        } else if isRegularWidth {
            iPadItemsList
        } else {
            iPhoneItemsList
        }
    }

    // MARK: - Filter Header

    private var filterHeader: some View {
        VStack(spacing: 6) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search IMEI, serial, brand, model...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, _ in
                        viewModel.searchItems()
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchItems()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.platformBackground)
            .cornerRadius(8)

            // Status filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // "All" pill
                    BuybackStatusPill(
                        title: "All",
                        count: viewModel.pagination?.total,
                        isSelected: viewModel.selectedStatus == nil,
                        color: .blue
                    ) {
                        viewModel.selectStatus(nil)
                    }

                    // Per-status pills
                    ForEach(viewModel.statusCounts) { statusCount in
                        let status = BuybackStatus(rawValue: statusCount.status)
                        BuybackStatusPill(
                            title: status?.displayName ?? statusCount.status
                                .replacingOccurrences(of: "_", with: " ")
                                .capitalized,
                            count: statusCount.count,
                            isSelected: viewModel.selectedStatus == statusCount.status,
                            color: buybackStatusColor(statusCount.status)
                        ) {
                            viewModel.selectStatus(statusCount.status)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.platformGroupedBackground)
    }

    // MARK: - iPhone Items List

    private var iPhoneItemsList: some View {
        List {
            ForEach(viewModel.items) { item in
                NavigationLink(value: item.id) {
                    buybackRow(item)
                }
                .task {
                    await viewModel.loadMoreIfNeeded(currentItem: item)
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - iPad Items List

    private var iPadItemsList: some View {
        List {
            ForEach(viewModel.items) { item in
                buybackRow(item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItemId = item.id
                    }
                    .listRowBackground(
                        selectedItemId == item.id
                            ? Color.accentColor.opacity(0.1)
                            : nil
                    )
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: item)
                    }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Row

    private func buybackRow(_ item: BuybackItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Device name + status badge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.deviceDisplayName.isEmpty ? "Unknown Device" : item.deviceDisplayName)
                        .font(.headline)
                    if let identifier = item.primaryIdentifier {
                        Text(identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                BuybackStatusBadge(status: item.status)
            }

            // Row 2: Financial summary
            HStack(spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showPurchasePrice.toggle() }
                } label: {
                    financialCell("Purchase", value: item.formattedPurchaseAmount, blurred: !showPurchasePrice)
                }
                .buttonStyle(.plain)
                financialCell("Refurb", value: item.formattedRefurbishmentCost)
                financialCell("Sell", value: item.formattedSellPrice)
                financialCell("Offer", value: item.formattedSpecialOfferPrice)
            }

            // Row 3: Metadata line
            HStack(spacing: 4) {
                if let date = item.purchaseDate,
                   let formatted = DateFormatters.formatRelativeDate(date) {
                    Text(formatted)
                }
                if let method = item.formattedPaymentMethod {
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Text(method)
                }
                if let location = item.locationName {
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Text(location)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Financial Cell

    private func financialCell(_ label: String, value: String?, blurred: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value ?? "-")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(value != nil ? .primary : .tertiary)
                .blur(radius: blurred ? 4 : 0)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading inventory...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadItems()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Buyback Items", systemImage: "iphone.gen3.slash")
        } description: {
            if viewModel.hasActiveFilters {
                Text("No items match your filters")
            } else {
                Text("Buyback inventory will appear here")
            }
        } actions: {
            if viewModel.hasActiveFilters {
                Button("Clear Filters") {
                    Task {
                        await viewModel.clearFilters()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Status Pill

private struct BuybackStatusPill: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count {
                    Text("\(count)")
                        .fontWeight(.semibold)
                }
            }
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.15) : Color.platformGray6)
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BuybackListView()
}
