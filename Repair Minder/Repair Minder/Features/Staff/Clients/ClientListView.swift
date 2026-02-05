//
//  ClientListView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

struct ClientListView: View {
    @StateObject private var viewModel = ClientListViewModel()
    @State private var selectedClientId: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.clients.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.clients.isEmpty {
                    errorView(error)
                } else if viewModel.clients.isEmpty {
                    emptyView
                } else {
                    clientsList
                }
            }
            .navigationTitle("Clients")
            .searchable(text: $viewModel.searchText, prompt: "Search clients...")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.searchClients()
            }
            .navigationDestination(item: $selectedClientId) { clientId in
                ClientDetailView(clientId: clientId)
            }
        }
        .task {
            await viewModel.loadClients()
        }
    }

    // MARK: - Subviews

    private var clientsList: some View {
        List {
            ForEach(viewModel.clients) { client in
                ClientRowView(client: client)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedClientId = client.id
                    }
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: client)
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

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            clientAvatar

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(client.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if client.isEmailSuppressed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Text(client.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let phone = client.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(client.formattedTotalSpend)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label("\(client.effectiveOrderCount)", systemImage: "doc.text")
                    Label("\(client.effectiveDeviceCount)", systemImage: "iphone")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

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
