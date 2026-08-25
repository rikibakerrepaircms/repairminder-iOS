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
    @State private var showBulkSell = false
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
        .safeAreaInset(edge: .bottom) {
            if viewModel.isSelecting && !viewModel.selectedIds.isEmpty {
                bulkSellBar
            }
        }
        .sheet(isPresented: $showBulkSell) {
            BulkSellSheet(items: viewModel.selectedItems) { request in
                await viewModel.sellBulk(request)
            }
        }
    }

    // MARK: - Bulk Sell

    /// Only `for_sale` items can be sold; selecting flips the row into a
    /// checkable state and disables ineligible items. Shown when at least
    /// one item is selected.
    private var bulkSellBar: some View {
        HStack {
            Text("\(viewModel.selectedIds.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showBulkSell = true
            } label: {
                Text("Sell (\(viewModel.selectedIds.count))")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("bulk-sell-open")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var selectionToolbar: some ToolbarContent {
        if viewModel.isSelecting {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { viewModel.toggleSelectionMode() }
                    .accessibilityIdentifier("bulk-sell-done")
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button("Select") { viewModel.toggleSelectionMode() }
                    .accessibilityIdentifier("bulk-sell-select")
            }
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
        .toolbar { selectionToolbar }
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
            .toolbar { selectionToolbar }
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
                    selectionToolbar
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

            // Additional filters: storefront status menu + toggle pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Menu {
                        Button("All") {
                            viewModel.selectStorefrontStatus(nil)
                        }
                        Divider()
                        ForEach(BuybackListView.storefrontStatusOptions, id: \.self) { option in
                            Button(BuybackListView.storefrontStatusDisplayName(option)) {
                                viewModel.selectStorefrontStatus(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.storefrontStatus.map(BuybackListView.storefrontStatusDisplayName)
                                ?? "Storefront: All")
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewModel.storefrontStatus != nil ? Color.blue.opacity(0.15) : Color.platformGray6)
                        .foregroundColor(viewModel.storefrontStatus != nil ? .blue : .secondary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.storefrontStatus != nil ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }

                    BuybackStatusPill(
                        title: "Has Sell Price",
                        count: nil,
                        isSelected: viewModel.hasSellPriceOnly,
                        color: .green
                    ) {
                        viewModel.toggleHasSellPriceOnly()
                    }

                    BuybackStatusPill(
                        title: "Missing Images",
                        count: nil,
                        isSelected: viewModel.missingImagesOnly,
                        color: .orange
                    ) {
                        viewModel.toggleMissingImagesOnly()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.platformGroupedBackground)
    }

    // MARK: - Storefront Status Options

    static let storefrontStatusOptions = ["not_started", "draft", "coming_soon", "ready", "live"]

    static func storefrontStatusDisplayName(_ status: String) -> String {
        switch status {
        case "not_started": return "Not Started"
        case "draft": return "Draft"
        case "coming_soon": return "Coming Soon"
        case "ready": return "Ready"
        case "live": return "Live"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - iPhone Items List

    private var iPhoneItemsList: some View {
        List {
            ForEach(viewModel.items) { item in
                itemRow(item)
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

    /// Row wrapper for the iPhone list — navigates to detail normally, or
    /// toggles bulk-sell selection while `isSelecting` is active.
    @ViewBuilder
    private func itemRow(_ item: BuybackItem) -> some View {
        if viewModel.isSelecting {
            Button {
                viewModel.toggleSelection(item)
            } label: {
                selectableRow(item)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isSelectable(item))
        } else {
            NavigationLink(value: item.id) {
                buybackRow(item)
            }
        }
    }

    /// A row with a leading checkmark indicator, dimmed when the item isn't
    /// eligible for bulk-sell (only `for_sale` items can be sold).
    private func selectableRow(_ item: BuybackItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.isSelected(item) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(viewModel.isSelected(item) ? Color.accentColor : .secondary)
            buybackRow(item)
        }
        .opacity(viewModel.isSelectable(item) ? 1 : 0.4)
    }

    // MARK: - iPad Items List

    private var iPadItemsList: some View {
        List {
            ForEach(viewModel.items) { item in
                Group {
                    if viewModel.isSelecting {
                        selectableRow(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleSelection(item)
                            }
                    } else {
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
                    }
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

            /*
              Colour, capacity and battery - the three things that decide what a used
              handset is worth to the next owner, and the ones someone pricing stock
              wants without opening the item.

              Colour was not shown anywhere on this row before; deviceDisplayName is
              brand + model + capacity. Battery is a badge rather than another "·"
              segment because when triaging a shelf the BAND is the useful part, and it
              is the same banding the web row and the device card use, so a handset does
              not change colour between screens.
            */
            if item.colourAndStorage != nil || BatteryHealth.display(item.batteryHealth) != nil {
                HStack(spacing: 6) {
                    if let line = item.colourAndStorage {
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let battery = BatteryHealth.display(item.batteryHealth) {
                        Label("\(battery)%", systemImage: "battery.100")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(BatteryHealth.tint(for: battery))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BatteryHealth.tint(for: battery).opacity(0.12), in: Capsule())
                    }
                }
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
