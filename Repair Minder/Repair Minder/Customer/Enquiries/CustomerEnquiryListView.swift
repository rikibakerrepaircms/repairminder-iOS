//
//  CustomerEnquiryListView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerEnquiryListView: View {
    @State private var viewModel = CustomerEnquiryListViewModel()
    @State private var showNewEnquiry = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.enquiries.isEmpty {
                    LoadingView(message: "Loading enquiries...")
                } else if let error = viewModel.error, viewModel.enquiries.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadEnquiries() }
                    }
                } else if viewModel.enquiries.isEmpty {
                    ContentUnavailableView {
                        Label("No Enquiries", systemImage: "envelope")
                    } description: {
                        Text("Submit an enquiry to get a repair quote")
                    } actions: {
                        Button("New Enquiry") {
                            showNewEnquiry = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    enquiryList
                }
            }
            .navigationTitle("Enquiries")
            .navigationDestination(for: String.self) { enquiryId in
                CustomerEnquiryDetailView(enquiryId: enquiryId)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewEnquiry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                if viewModel.enquiries.isEmpty {
                    await viewModel.loadEnquiries()
                }
            }
            .sheet(isPresented: $showNewEnquiry) {
                NewEnquiryView()
            }
            .onChange(of: showNewEnquiry) { wasShowing, isShowing in
                // Refresh when sheet closes
                if wasShowing && !isShowing {
                    Task { await viewModel.loadEnquiries() }
                }
            }
        }
    }

    private var enquiryList: some View {
        List(viewModel.enquiries) { enquiry in
            NavigationLink(value: enquiry.id) {
                CustomerEnquiryRow(enquiry: enquiry)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct CustomerEnquiryRow: View {
    let enquiry: CustomerEnquiry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(enquiry.shopName)
                    .font(.headline)

                Spacer()

                CustomerEnquiryStatusBadge(status: enquiry.status)
            }

            Text(enquiry.deviceDisplayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(enquiry.issueDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(enquiry.createdAt.relativeFormatted())
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct CustomerEnquiryStatusBadge: View {
    let status: CustomerEnquiryStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundStyle(status.color)
        .clipShape(Capsule())
    }
}

#Preview {
    CustomerEnquiryListView()
}
