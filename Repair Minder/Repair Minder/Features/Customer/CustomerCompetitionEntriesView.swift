//
//  CustomerCompetitionEntriesView.swift
//  Repair Minder
//
//  Created on 06/07/2026.
//

import SwiftUI

/// Customer-facing list of the logged-in customer's giveaway/competition entries,
/// with self-service withdrawal (emails a confirmation link; the entry itself is
/// only removed once that link is clicked).
/// Consumes GET /api/customer/marketing/entries and the withdraw-request endpoint
/// via `CustomerMarketingService`.
@MainActor
struct CustomerCompetitionEntriesView: View {
    @State private var entries: [CustomerCompetitionEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pendingWithdraw: CustomerCompetitionEntry?
    @State private var showWithdrawnNotice = false

    var body: some View {
        Group {
            if isLoading && entries.isEmpty {
                loadingView
            } else if let errorMessage, entries.isEmpty {
                errorView(errorMessage)
            } else if entries.isEmpty {
                emptyView
            } else {
                entryList
            }
        }
        .navigationTitle("My Entries")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog(
            "Withdraw this entry?",
            isPresented: Binding(
                get: { pendingWithdraw != nil },
                set: { if !$0 { pendingWithdraw = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Yes, email me a link", role: .destructive) {
                if let entry = pendingWithdraw {
                    Task { await withdraw(entry) }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingWithdraw = nil
            }
        } message: {
            Text("We will email you a link to confirm. Your entry stays until you click it.")
        }
        .alert("Check your email", isPresented: $showWithdrawnNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("If that entry is eligible to withdraw, we have emailed you a link to confirm.")
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.campaignName)
                    .font(.headline)

                if let prize = entry.prize {
                    Text("Prize: \(prize)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if entry.isWinner {
                    Text("Winner")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.green)
                }

                Button("Withdraw entry", role: .destructive) {
                    pendingWithdraw = entry
                }
                .font(.caption)
            }
            .padding(.vertical, 4)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Loading View

    private var loadingView: some View {
        LottieLoadingView(size: 100, message: "Loading entries...")
    }

    // MARK: - Error View

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
                Task { await load() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Entries Yet")
                .font(.headline)

            Text("You have not entered any competitions yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Networking

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await CustomerMarketingService.shared.fetchEntries()
        } catch {
            errorMessage = "Could not load your entries."
        }
        isLoading = false
    }

    private func withdraw(_ entry: CustomerCompetitionEntry) async {
        pendingWithdraw = nil
        try? await CustomerMarketingService.shared.requestWithdrawal(campaignId: entry.campaignId)
        showWithdrawnNotice = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomerCompetitionEntriesView()
    }
}
