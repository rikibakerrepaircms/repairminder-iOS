//
//  EnquiryListView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryListView: View {
    @StateObject private var viewModel = EnquiryListViewModel()
    @Environment(AppRouter.self) private var router
    @State private var showFilters = false

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats Header
                    EnquiryStatsHeader(stats: viewModel.stats)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    // Filter Chips
                    EnquiryFilterChips(
                        selectedFilter: $viewModel.selectedFilter,
                        counts: viewModel.filterCounts
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    // Content
                    Group {
                        if viewModel.isLoading && viewModel.enquiries.isEmpty {
                            LoadingView(message: "Loading enquiries...")
                        } else if viewModel.enquiries.isEmpty {
                            EnquiryEmptyState(filter: viewModel.selectedFilter)
                        } else {
                            enquiryList
                        }
                    }
                }
            }
            .navigationTitle("Enquiries")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AppRoute.self) { route in
                routeDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(viewModel.hasActiveFilters ? .fill : .none)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                EnquiryFilterSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadEnquiries()
            }
        }
    }

    private var enquiryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.enquiries) { enquiry in
                    EnquiryCard(enquiry: enquiry)
                        .onTapGesture {
                            router.navigate(to: .enquiryDetail(id: enquiry.id))
                        }
                        .contextMenu {
                            EnquiryContextMenu(
                                enquiry: enquiry,
                                onMarkRead: { viewModel.markAsRead(enquiry.id) },
                                onArchive: { viewModel.archive(enquiry.id) }
                            )
                        }
                }

                if viewModel.hasMorePages {
                    ProgressView()
                        .padding()
                        .onAppear {
                            Task { await viewModel.loadMore() }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .enquiryDetail(let id):
            EnquiryDetailView(enquiryId: id)
        case .orderDetail(let id):
            // Navigate to order detail when converted
            Text("Order \(id)")  // Replace with actual OrderDetailView
        default:
            EmptyView()
        }
    }
}

// MARK: - Empty State
struct EnquiryEmptyState: View {
    let filter: EnquiryFilter

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(emptyTitle)
                .font(.headline)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch filter {
        case .all:
            return "envelope.open"
        case .new:
            return "envelope.badge"
        case .pending:
            return "clock"
        case .awaitingCustomer:
            return "person.crop.circle.badge.clock"
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .all:
            return "No Enquiries"
        case .new:
            return "No New Enquiries"
        case .pending:
            return "All Caught Up!"
        case .awaitingCustomer:
            return "No Waiting Enquiries"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .all:
            return "When customers submit enquiries, they'll appear here."
        case .new:
            return "You've reviewed all new enquiries."
        case .pending:
            return "No enquiries are waiting for your reply."
        case .awaitingCustomer:
            return "No enquiries are waiting for customer responses."
        }
    }
}

#Preview {
    EnquiryListView()
        .environment(AppRouter())
}
