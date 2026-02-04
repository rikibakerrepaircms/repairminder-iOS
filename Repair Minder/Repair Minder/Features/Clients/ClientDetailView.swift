//
//  ClientDetailView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientDetailView: View {
    let clientId: String
    @StateObject private var viewModel: ClientDetailViewModel
    @Environment(AppRouter.self) var router

    init(clientId: String) {
        self.clientId = clientId
        _viewModel = StateObject(wrappedValue: ClientDetailViewModel(clientId: clientId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.client == nil {
                LoadingView(message: "Loading client...")
            } else if let client = viewModel.client {
                ScrollView {
                    VStack(spacing: 20) {
                        ClientHeader(client: client)

                        ContactActionsView(client: client)

                        ClientStatsCard(client: client)

                        OrderHistorySection(
                            orders: viewModel.orders,
                            hasMore: viewModel.hasMoreOrders,
                            onTapOrder: { orderId in
                                router.navigate(to: .orderDetail(id: orderId))
                            },
                            onLoadMore: {
                                Task { await viewModel.loadMoreOrders() }
                            }
                        )
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle(viewModel.client?.displayName ?? "Client")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        ClientDetailView(clientId: "test-id")
            .environment(AppRouter())
    }
}
