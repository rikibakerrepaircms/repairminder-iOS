//
//  MarketplaceBlockedSellersView.swift
//  Repair Minder
//
//  CRUD for a company's blocked-seller list -- hides a Facebook seller's
//  listings from the marketplace feed. Mirrors the web dashboard's blocked
//  sellers panel.
//

import SwiftUI

struct MarketplaceBlockedSellersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var blockedSellers: [BlockedSeller] = []
    @State private var error: String?
    @State private var showAddSheet = false

    private let service = MarketplaceService()

    var body: some View {
        List {
            ForEach(blockedSellers) { seller in
                VStack(alignment: .leading, spacing: 2) {
                    Text(seller.sellerName ?? "Unknown seller").font(.body)
                    Text("Blocked \(seller.blockedAt)").font(.caption).foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button("Unblock") {
                        Task { await unblock(seller) }
                    }
                }
            }
        }
        .navigationTitle("Blocked Sellers")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddBlockedSellerView { newSeller in
                    blockedSellers.append(newSeller)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func load() async {
        do {
            blockedSellers = try await service.listBlockedSellers()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func unblock(_ seller: BlockedSeller) async {
        do {
            try await service.unblockSeller(sellerFbId: seller.sellerFbId)
            blockedSellers.removeAll { $0.id == seller.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Block-a-seller form, presented as a sheet from MarketplaceBlockedSellersView.
/// Note: the backend has no read endpoint to look up a seller by name -- the
/// staff member enters the numeric Facebook seller id directly (visible in
/// the listing detail view or the seller's Facebook profile URL).
private struct AddBlockedSellerView: View {
    @Environment(\.dismiss) private var dismiss
    var onBlocked: (BlockedSeller) -> Void

    @State private var sellerFbId = ""
    @State private var sellerName = ""
    @State private var isSaving = false
    @State private var error: String?

    private let service = MarketplaceService()

    var body: some View {
        Form {
            TextField("Facebook seller id", text: $sellerFbId)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            TextField("Name (optional)", text: $sellerName)
        }
        .navigationTitle("Block Seller")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Block") { Task { await save() } }
                    .disabled(sellerFbId.isEmpty || isSaving)
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func save() async {
        isSaving = true
        do {
            try await service.blockSeller(sellerFbId: sellerFbId, sellerName: sellerName.isEmpty ? nil : sellerName)
            onBlocked(BlockedSeller(sellerFbId: sellerFbId, sellerName: sellerName.isEmpty ? nil : sellerName, blockedAt: ""))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
