//
//  DevicesView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Devices View

/// Navigation target for device detail (iPad split view)
private struct DeviceDetailNavigation: Hashable {
    let orderId: String
    let deviceId: String
}

/// Main device list view with filtering capabilities
struct DevicesView: View {
    var isEmbedded: Bool = false

    @State private var viewModel = DevicesViewModel()
    @State private var boardViewModel = BoardViewModel(scope: "company")
    @State private var showingFilterSheet = false
    @State private var showingScanner = false
    @State private var searchText = ""
    @State private var selectedDeviceNav: DeviceDetailNavigation?
    @AppStorage("devicesViewMode") private var viewMode: String = "list"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isEmbedded {
            embeddedBody
        } else if isRegularWidth {
            iPadBody
        } else {
            iPhoneBody
        }
    }

    // MARK: - Embedded Layout (inside another NavigationStack/SplitView detail pane)

    private var embeddedBody: some View {
        devicesContent(wideRows: false)
            .navigationDestination(for: DeviceListItem.self) { device in
                if let orderId = device.orderId {
                    DeviceDetailView(orderId: orderId, deviceId: device.id)
                } else {
                    ContentUnavailableView(
                        "No Order",
                        systemImage: "doc.questionmark",
                        description: Text("This device is not associated with an order")
                    )
                }
            }
            .navigationDestination(item: $selectedDeviceNav) { nav in
                DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
            }
    }

    // MARK: - iPhone Layout

    private var iPhoneBody: some View {
        NavigationStack {
            devicesContent(wideRows: false)
                .navigationDestination(for: DeviceListItem.self) { device in
                    if let orderId = device.orderId {
                        DeviceDetailView(orderId: orderId, deviceId: device.id)
                    } else {
                        ContentUnavailableView(
                            "No Order",
                            systemImage: "doc.questionmark",
                            description: Text("This device is not associated with an order")
                        )
                    }
                }
                .navigationDestination(item: $selectedDeviceNav) { nav in
                    DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
                }
        }
    }

    // MARK: - iPad Layout

    private var iPadBody: some View {
        AnimatedSplitView(showDetail: selectedDeviceNav != nil) {
            NavigationStack {
                devicesContent(wideRows: true)
            }
        } detail: {
            if let nav = selectedDeviceNav {
                NavigationStack {
                    DeviceDetailView(orderId: nav.orderId, deviceId: nav.deviceId)
                }
                .id("\(nav.orderId)-\(nav.deviceId)")
            }
        }
    }

    // MARK: - Shared Content

    private func devicesContent(wideRows: Bool) -> some View {
        VStack(spacing: 0) {
            // Inline search (matches My Queue; avoids the system .searchable bar
            // reserving a large empty band at the top).
            searchBar

            // Category filter tabs
            categoryTabs

            // Board or list view
            if viewMode == "board" {
                BoardView(viewModel: boardViewModel) { device in
                    if let orderId = device.orderId {
                        selectedDeviceNav = DeviceDetailNavigation(orderId: orderId, deviceId: device.id)
                    }
                }
            } else {
                deviceListContent(wideRows: wideRows)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Single consolidated control: view mode + scan + filters.
                Menu {
                    Picker("View", selection: $viewMode) {
                        Label("List", systemImage: "list.bullet").tag("list")
                        Label("Board", systemImage: "rectangle.3.group").tag("board")
                    }
                    .pickerStyle(.inline)

                    Divider()

                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }

                    Button {
                        showingFilterSheet = true
                    } label: {
                        Label(viewModel.filterState.hasActiveFilters ? "Filters (active)" : "Filters…",
                              systemImage: "line.3.horizontal.decrease.circle")
                    }
                } label: {
                    Image(systemName: viewModel.filterState.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "slider.horizontal.3")
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await viewModel.setSearch(newValue)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingFilterSheet) {
            DeviceFilterSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingScanner) {
            ScannerView(viewModel: viewModel)
        }
        .task {
            if viewModel.devices.isEmpty {
                await viewModel.loadDevices()
            }
            if viewMode == "board" {
                await loadBoard()
            }
        }
        .onChange(of: viewMode) { _, newValue in
            if newValue == "board" {
                Task { await loadBoard() }
            }
        }
        .onChange(of: viewModel.devices) { _, _ in
            if viewMode == "board" {
                let items = viewModel.devices.map { BoardDeviceItem(from: $0) }
                boardViewModel.updateDevices(items)
            }
        }
    }

    // MARK: - Board Loading

    private func loadBoard() async {
        let items = viewModel.devices.map { BoardDeviceItem(from: $0) }
        await boardViewModel.loadBoard(devices: items)
    }

    // MARK: - Category Tabs

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search serial, IMEI, brand, model...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .background(Color.platformGroupedBackground)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkflowCategory.allCases) { category in
                    CategoryTab(
                        category: category,
                        count: countForCategory(category),
                        isSelected: viewModel.filterState.workflowCategory == category
                    ) {
                        Task {
                            await viewModel.setCategory(category)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.platformGroupedBackground)
    }

    private func countForCategory(_ category: WorkflowCategory) -> Int {
        switch category {
        case .all:
            return viewModel.categoryCounts.total
        case .repair:
            return viewModel.categoryCounts.repair ?? 0
        case .buyback:
            return viewModel.categoryCounts.buyback ?? 0
        case .refurb:
            return viewModel.categoryCounts.refurb ?? 0
        case .unassigned:
            return viewModel.categoryCounts.unassigned ?? 0
        }
    }

    // MARK: - Device List

    @ViewBuilder
    private func deviceListContent(wideRows: Bool) -> some View {
        if viewModel.isLoading && viewModel.devices.isEmpty {
            loadingView
        } else if viewModel.isEmpty {
            emptyStateView
        } else if let error = viewModel.error {
            errorView(error)
        } else {
            List {
                ForEach(viewModel.devices) { device in
                    if wideRows {
                        // iPad: use Button to drive split view selection
                        Button {
                            if let orderId = device.orderId {
                                selectedDeviceNav = DeviceDetailNavigation(orderId: orderId, deviceId: device.id)
                            }
                        } label: {
                            DeviceRow(device: device, isWide: true)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            selectedDeviceNav?.deviceId == device.id
                                ? Color.accentColor.opacity(0.1)
                                : nil
                        )
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(currentItem: device)
                            }
                        }
                    } else {
                        // iPhone: use NavigationLink
                        NavigationLink(value: device) {
                            DeviceRow(device: device)
                        }
                        .onAppear {
                            Task {
                                await viewModel.loadMoreIfNeeded(currentItem: device)
                            }
                        }
                    }
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .contentMargins(.top, 0, for: .scrollContent)
        }
    }

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading devices...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(viewModel.emptyMessage, systemImage: "iphone.slash")
        } description: {
            if viewModel.filterState.hasActiveFilters {
                Text("Try adjusting your filters")
            } else {
                Text("Devices will appear here when added to orders")
            }
        } actions: {
            if viewModel.filterState.hasActiveFilters {
                Button("Clear Filters") {
                    Task {
                        await viewModel.clearFilters()
                    }
                }
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error Loading Devices", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Try Again") {
                Task {
                    await viewModel.loadDevices()
                }
            }
        }
    }
}

// MARK: - Category Tab

private struct CategoryTab: View {
    let category: WorkflowCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.displayName)
                    .font(.subheadline.weight(.medium))
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.platformGray5)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.platformBackground)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Device Filter Sheet

struct DeviceFilterSheet: View {
    @Bindable var viewModel: DevicesViewModel
    @Environment(\.dismiss) private var dismiss

    /// Status order shown in the multi-select, matching the web /devices page.
    static let statusFilterOrder: [DeviceStatus] = [
        .deviceReceived, .diagnosing, .readyToQuote, .companyRejected, .awaitingAuthorisation,
        .authorisedSourceParts, .authorisedAwaitingParts, .readyToRepair, .repairing,
        .awaitingRevisedQuote, .repairedQc, .repairedReady, .rejected, .rejectionQc,
        .rejectionReady, .collected, .despatched, .readyToPay, .paymentMade, .addedToBuyback
    ]

    /// Whether a status is currently shown (i.e. NOT in the excluded set).
    private func isStatusShown(_ status: String) -> Bool {
        !viewModel.filterState.excludedStatusSet.contains(status)
    }

    /// Toggle a status in/out of the hidden (excluded) set.
    private func toggleStatus(_ status: String) {
        var set = viewModel.filterState.excludedStatusSet
        if set.contains(status) { set.remove(status) } else { set.insert(status) }
        viewModel.filterState.excludeStatus = set.isEmpty ? nil : set.sorted().joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Status multi-select — mirrors web /devices. Ticked = shown;
                // unticked = hidden. By default the 3 completed statuses are hidden.
                Section {
                    Button("Show All") {
                        viewModel.filterState.excludeStatus = nil
                    }
                    Button("Hide Completed") {
                        viewModel.filterState.excludeStatus = DeviceListFilter.defaultExcludedStatuses
                    }
                } header: {
                    Text("Show devices with status")
                }

                Section {
                    ForEach(Self.statusFilterOrder, id: \.rawValue) { status in
                        Button {
                            toggleStatus(status.rawValue)
                        } label: {
                            HStack {
                                Image(systemName: isStatusShown(status.rawValue) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isStatusShown(status.rawValue) ? Color.accentColor : Color.secondary)
                                Text(status.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                }

                // Device type filter
                if !viewModel.deviceTypes.isEmpty {
                    Section("Device Type") {
                        Picker("Device Type", selection: Binding(
                            get: { viewModel.filterState.deviceTypeId ?? "" },
                            set: { viewModel.filterState.deviceTypeId = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("All").tag("")
                            ForEach(viewModel.deviceTypes) { type in
                                Text(type.name).tag(type.id)
                            }
                        }
                    }
                }

                // Engineer filter
                if !viewModel.engineers.isEmpty {
                    Section("Assigned To") {
                        Picker("Engineer", selection: Binding(
                            get: { viewModel.filterState.engineerId ?? "" },
                            set: { viewModel.filterState.engineerId = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("All").tag("")
                            Text("Unassigned").tag("unassigned")
                            ForEach(viewModel.engineers) { engineer in
                                Text(engineer.name).tag(engineer.id)
                            }
                        }
                    }
                }

                // Location filter
                if !viewModel.locations.isEmpty {
                    Section("Location") {
                        Picker("Location", selection: Binding(
                            get: { viewModel.filterState.locationId ?? "" },
                            set: { viewModel.filterState.locationId = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("All").tag("")
                            ForEach(viewModel.locations) { location in
                                Text(location.name).tag(location.id)
                            }
                        }
                    }
                }

                // Date filter
                Section("Date Range") {
                    Picker("Period", selection: Binding(
                        get: { viewModel.filterState.period },
                        set: { viewModel.filterState.period = $0 }
                    )) {
                        Text("All Time").tag(nil as DatePeriod?)
                        ForEach(DatePeriod.allCases) { period in
                            Text(period.displayName).tag(period as DatePeriod?)
                        }
                    }

                    if viewModel.filterState.period != nil {
                        Picker("Filter By", selection: $viewModel.filterState.dateFilter) {
                            ForEach(DateFilterType.allCases) { filter in
                                Text(filter.displayName).tag(filter)
                            }
                        }
                    }
                }

                // Options
                Section("Options") {
                    Toggle("Show Archived", isOn: $viewModel.filterState.showArchived)

                    Toggle("Awaiting Collection", isOn: Binding(
                        get: { viewModel.filterState.collectionStatus == .awaiting },
                        set: { viewModel.filterState.collectionStatus = $0 ? .awaiting : nil }
                    ))
                }

                // Clear filters
                if viewModel.filterState.hasActiveFilters {
                    Section {
                        Button("Clear All Filters", role: .destructive) {
                            Task {
                                await viewModel.clearFilters()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Task {
                            await viewModel.loadDevices()
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    DevicesView()
}
