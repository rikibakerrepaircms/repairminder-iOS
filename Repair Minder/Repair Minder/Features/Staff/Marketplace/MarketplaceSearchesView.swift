//
//  MarketplaceSearchesView.swift
//  Repair Minder
//
//  CRUD for a company's saved Facebook Marketplace searches (term, location,
//  radius, poll interval, enabled toggle) -- mirrors
//  MarketplaceSearchesPanel.tsx on the web dashboard.
//

import SwiftUI

struct MarketplaceSearchesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searches: [MarketplaceSearch] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showAddSheet = false

    private let service = MarketplaceService()

    var body: some View {
        List {
            ForEach(searches) { search in
                searchRow(search)
            }
        }
        .navigationTitle("Saved Searches")
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
                AddMarketplaceSearchView { newSearch in
                    searches.append(newSearch)
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

    private func searchRow(_ search: MarketplaceSearch) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(search.searchTerm).font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { search.isEnabled },
                    set: { newValue in Task { await toggle(search, enabled: newValue) } }
                ))
                .labelsHidden()
            }
            Text("\(search.locationLabel) · \(search.radiusKm)km · every \(search.pollIntervalMinutes)m")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                Task { await delete(search) }
            }
        }
    }

    private func load() async {
        isLoading = true
        do {
            searches = try await service.listSearches()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func toggle(_ search: MarketplaceSearch, enabled: Bool) async {
        do {
            let updated = try await service.updateSearch(id: search.id, request: UpdateMarketplaceSearchRequest(enabled: enabled))
            if let index = searches.firstIndex(where: { $0.id == search.id }) {
                searches[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ search: MarketplaceSearch) async {
        do {
            try await service.deleteSearch(id: search.id)
            searches.removeAll { $0.id == search.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Add-search form, presented as a sheet from MarketplaceSearchesView.
private struct AddMarketplaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (MarketplaceSearch) -> Void

    @State private var searchTerm = ""
    @State private var locationLabel = ""
    @State private var fbLocationId = ""
    @State private var radiusKm = 10
    @State private var pollIntervalMinutes = 15
    @State private var isSaving = false
    @State private var error: String?

    private let service = MarketplaceService()

    var body: some View {
        Form {
            Section("Search") {
                TextField("Search term (e.g. iphone 13)", text: $searchTerm)
                TextField("Location label (e.g. Haverhill)", text: $locationLabel)
                TextField("Facebook location id", text: $fbLocationId)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            Section("Polling") {
                Stepper("Radius: \(radiusKm)km", value: $radiusKm, in: 1...100)
                Stepper("Every \(pollIntervalMinutes) minutes", value: $pollIntervalMinutes, in: 5...120, step: 5)
            }
        }
        .navigationTitle("New Search")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(searchTerm.isEmpty || locationLabel.isEmpty || fbLocationId.isEmpty || isSaving)
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
            let created = try await service.createSearch(CreateMarketplaceSearchRequest(
                searchTerm: searchTerm, locationLabel: locationLabel, fbLocationId: fbLocationId,
                radiusKm: radiusKm, pollIntervalMinutes: pollIntervalMinutes
            ))
            onCreated(created)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
