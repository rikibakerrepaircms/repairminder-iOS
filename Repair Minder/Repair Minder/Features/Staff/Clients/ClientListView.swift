//
//  ClientListView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

struct ClientListView: View {
    var isEmbedded: Bool = false
    var onBack: (() -> Void)? = nil

    @StateObject private var viewModel = ClientListViewModel()
    @State private var selectedClientId: String?
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

    // MARK: - Embedded Layout (inside another NavigationSplitView detail pane)

    private var embeddedBody: some View {
        clientsContent(wideRows: false)
            .navigationDestination(item: $selectedClientId) { clientId in
                ClientDetailView(clientId: clientId)
            }
    }

    // MARK: - iPhone Layout

    private var iPhoneBody: some View {
        NavigationStack {
            clientsContent(wideRows: false)
                .navigationDestination(item: $selectedClientId) { clientId in
                    ClientDetailView(clientId: clientId)
                }
        }
    }

    // MARK: - iPad Layout

    private var iPadBody: some View {
        AnimatedSplitView(showDetail: selectedClientId != nil) {
            NavigationStack {
                clientsContent(wideRows: true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
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
            if let clientId = selectedClientId {
                NavigationStack {
                    ClientDetailView(clientId: clientId)
                }
            } else {
                ContentUnavailableView(
                    "Select a Client",
                    systemImage: "person.crop.circle",
                    description: Text("Choose a client from the list to view their details.")
                )
            }
        }
    }

    // MARK: - Shared Content

    private func clientsContent(wideRows: Bool) -> some View {
        Group {
            if viewModel.isLoading && viewModel.clients.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.clients.isEmpty {
                errorView(error)
            } else if viewModel.clients.isEmpty {
                emptyView
            } else {
                clientsList(wideRows: wideRows)
            }
        }
        .navigationTitle("Clients")
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search clients...")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.searchClients()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.loadClients()
        }
    }

    // MARK: - Subviews

    private func clientsList(wideRows: Bool) -> some View {
        List {
            ForEach(viewModel.clients) { client in
                if wideRows {
                    Button {
                        selectedClientId = client.id
                    } label: {
                        ClientRowView(client: client)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedClientId == client.id
                            ? Color.accentColor.opacity(0.1)
                            : nil
                    )
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: client)
                    }
                } else {
                    ClientRowView(client: client)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedClientId = client.id
                        }
                        .task {
                            await viewModel.loadMoreIfNeeded(currentItem: client)
                        }
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
        .listStyle(.insetGrouped)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading clients...")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.loadClients()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Clients", systemImage: "person.2")
        } description: {
            if !viewModel.searchText.isEmpty {
                Text("No clients match your search")
            } else {
                Text("Clients will appear here")
            }
        }
    }
}

// MARK: - Client Row View

struct ClientRowView: View {
    let client: Client
    var isWide: Bool = false

    var body: some View {
        if isWide {
            wideLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name + avatar row
            HStack(spacing: 10) {
                clientAvatar

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(client.displayName)
                            .font(.headline)

                        if client.isEmailSuppressed {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }

                    if let group = client.groupDisplayName {
                        Text(group)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Contact info
            VStack(alignment: .leading, spacing: 2) {
                Label(client.email, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let phone = client.phone, !phone.isEmpty {
                    Label(phone, systemImage: "phone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats + spend row
            HStack {
                HStack(spacing: 12) {
                    Label("\(client.effectiveOrderCount) order\(client.effectiveOrderCount == 1 ? "" : "s")", systemImage: "doc.text")
                    Label("\(client.effectiveDeviceCount) device\(client.effectiveDeviceCount == 1 ? "" : "s")", systemImage: "iphone")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text(client.formattedTotalSpend)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Wide Layout (iPad)

    private var wideLayout: some View {
        HStack(spacing: 16) {
            clientAvatar

            // Name + group
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(client.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if client.isEmailSuppressed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                if let group = client.groupDisplayName {
                    Text(group)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 140, alignment: .leading)

            // Email
            Label {
                Text(client.email)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "envelope")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minWidth: 160, alignment: .leading)

            // Phone
            if let phone = client.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 110, alignment: .leading)
            }

            Spacer()

            // Stats
            HStack(spacing: 12) {
                Label("\(client.effectiveOrderCount)", systemImage: "doc.text")
                Label("\(client.effectiveDeviceCount)", systemImage: "iphone")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Total spend
            Text(client.formattedTotalSpend)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Avatar

    private var clientAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            Text(client.initials)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 44, height: 44)
    }
}

#Preview {
    ClientListView()
}
