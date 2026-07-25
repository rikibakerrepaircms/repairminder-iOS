//
//  CustomerEnquiryListView.swift
//  Repair Minder
//
//  Created on 25/07/2026.
//

import SwiftUI

/// The signed-in customer's own enquiries.
///
/// The web portal has no equivalent: it arrives by magic link straight onto one
/// enquiry at /s/<token>. The app has no ticket-scoped session, so without this
/// screen a customer holding a sell enquiry logs in and finds nothing.
///
/// Pushed onto an existing NavigationStack - it does not create its own.
struct CustomerEnquiryListView: View {
    @StateObject private var viewModel = CustomerEnquiryListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.enquiries.isEmpty {
                LottieLoadingView(size: 100, message: "Loading enquiries...")
            } else if let error = viewModel.errorMessage, viewModel.enquiries.isEmpty {
                errorView(error)
            } else if viewModel.enquiries.isEmpty {
                emptyView
            } else {
                list
            }
        }
        .navigationTitle("My Enquiries")
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if !viewModel.sellEnquiries.isEmpty {
                Section {
                    ForEach(viewModel.sellEnquiries) { enquiry in
                        NavigationLink(destination: CustomerEnquiryDetailView(ticketId: enquiry.id)) {
                            CustomerEnquiryRow(enquiry: enquiry)
                        }
                    }
                } header: {
                    Text("Devices You Are Selling")
                }
            }

            if !viewModel.otherEnquiries.isEmpty {
                Section {
                    ForEach(viewModel.otherEnquiries) { enquiry in
                        NavigationLink(destination: CustomerEnquiryDetailView(ticketId: enquiry.id)) {
                            CustomerEnquiryRow(enquiry: enquiry)
                        }
                    }
                } header: {
                    Text("Enquiries")
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Enquiries Yet")
                .font(.headline)

            Text("When you get in touch with us or agree to sell a device, the conversation appears here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Row

struct CustomerEnquiryRow: View {
    let enquiry: CustomerEnquirySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Enquiry #\(enquiry.ticketNumber)")
                    .font(.headline)

                Spacer()

                statusBadge
            }

            Text(enquiry.displaySubject)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let created = enquiry.createdAt {
                Text(DateFormatters.formatHumanDate(created))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        let color = statusColor
        return Text(CustomerEnquiryStatus.label(for: enquiry.status))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch enquiry.status {
        case "pending": return .orange
        case "resolved": return .blue
        case "closed": return .gray
        default: return .green
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomerEnquiryListView()
    }
}
