//
//  MarketplaceListingDetailView.swift
//  Repair Minder
//
//  Full listing view: photo, description, seller, status actions + notes,
//  and "Open in Facebook" -- the same platformOpenMarketplaceListing(_:) path
//  a marketplace-listing push notification tap uses, so in-app and
//  notification-triggered opens behave identically.
//

import SwiftUI

struct MarketplaceListingDetailView: View {
    let listing: MarketplaceListing
    /// Called with the freshly-saved status after a successful PATCH, so the
    /// presenting feed view can update its in-memory copy.
    var onStatusChanged: (MarketplaceListingStatus) -> Void

    @State private var notes: String
    @State private var currentStatus: String?
    @State private var isSaving = false
    @State private var error: String?

    private let service = MarketplaceService()

    init(listing: MarketplaceListing, onStatusChanged: @escaping (MarketplaceListingStatus) -> Void) {
        self.listing = listing
        self.onStatusChanged = onStatusChanged
        self._notes = State(initialValue: listing.notes ?? "")
        self._currentStatus = State(initialValue: listing.status)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AsyncImage(url: listing.photoURL.flatMap(URL.init(string:))) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.gray.opacity(0.15).frame(height: 220)
                }
                .frame(maxHeight: 260)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(listing.title ?? "Untitled listing").font(.title3).fontWeight(.semibold)
                    Text(listing.priceFormatted ?? "No price").font(.headline).foregroundStyle(.blue)
                    if let city = listing.city {
                        Label(city, systemImage: "location")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let condition = listing.condition {
                        Text("Condition: \(condition)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let sellerName = listing.sellerName {
                        Text("Seller: \(sellerName)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let description = listing.description, !description.isEmpty {
                        Text(description).font(.body).padding(.top, 4)
                    }
                }
                .padding(.horizontal)

                Button {
                    if let url = URL(string: listing.listingURL) {
                        platformOpenMarketplaceListing(url)
                    }
                } label: {
                    Label("Open in Facebook", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                statusButtons
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes").font(.subheadline).fontWeight(.medium)
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        .onChange(of: notes) { _, _ in scheduleSave() }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Listing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private var statusButtons: some View {
        HStack(spacing: 8) {
            statusButton(title: "Contacted", value: "contacted")
            statusButton(title: "Purchased", value: "purchased")
            statusButton(title: "Ignore", value: "ignored")
        }
    }

    private func statusButton(title: String, value: String) -> some View {
        Button {
            Task { await setStatus(currentStatus == value ? nil : value) }
        } label: {
            Text(title)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(currentStatus == value ? .blue : .gray)
        .disabled(isSaving)
    }

    private func setStatus(_ value: String?) async {
        isSaving = true
        do {
            let updated = try await service.setListingStatus(id: listing.id, status: value, notes: notes)
            currentStatus = updated.status
            onStatusChanged(updated)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    /// Notes are saved on every edit via TextEditor's onChange -- debouncing
    /// isn't implemented here (YAGNI: notes edits are infrequent, and every
    /// existing PATCH is idempotent), a save simply re-sends the current
    /// status alongside the latest notes text.
    private func scheduleSave() {
        Task { await setStatus(currentStatus) }
    }
}
