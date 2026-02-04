//
//  OrderListView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderListView: View {
    @StateObject private var viewModel = OrderListViewModel()
    @Environment(AppRouter.self) var router
    @State private var showFilter = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            Group {
                if viewModel.isLoading && viewModel.orders.isEmpty {
                    LoadingView(message: "Loading orders...")
                } else if viewModel.orders.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Orders",
                        message: "No orders match your criteria"
                    )
                } else {
                    ordersList
                }
            }
            .navigationTitle("Orders")
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(for: route)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search orders...")
            .toolbar {
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
                OrderFilterSheet(viewModel: viewModel)
            }
            .task {
                if viewModel.orders.isEmpty {
                    await viewModel.loadOrders()
                }
            }
        }
    }

    private var ordersList: some View {
        List {
            ForEach(viewModel.orders) { order in
                OrderListRow(order: order)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        router.navigate(to: .orderDetail(id: order.id))
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
        case .orderDetail(let id):
            OrderDetailView(orderId: id)
        default:
            EmptyView()
        }
    }
}

#Preview {
    OrderListView()
        .environment(AppRouter())
}
