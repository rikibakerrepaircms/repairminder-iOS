//
//  ClientListView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientListView: View {
    @StateObject private var viewModel = ClientListViewModel()
    @Environment(AppRouter.self) var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if viewModel.isLoading && viewModel.clients.isEmpty {
                    LoadingView(message: "Loading clients...")
                } else if viewModel.clients.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No Clients",
                        message: "No clients match your search"
                    )
                } else {
                    clientsList
                }
            }
            .navigationTitle("Clients")
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(for: route)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search name, email, phone...")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.clients.isEmpty {
                    await viewModel.loadClients()
                }
            }
        }
    }

    private var clientsList: some View {
        List {
            ForEach(viewModel.clients) { client in
                ClientListRow(client: client)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.navigate(to: .clientDetail(id: client.id))
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
        case .clientDetail(let id):
            ClientDetailView(clientId: id)
        case .orderDetail(let id):
            OrderDetailView(orderId: id)
        default:
            EmptyView()
        }
    }
}

#Preview {
    ClientListView()
        .environment(AppRouter())
}
