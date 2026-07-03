import SwiftUI

struct AssetMoveSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var locations: [Location] = []
    @State private var subLocations: [AssetSubLocationOption] = []
    @State private var locationId: String?
    @State private var subLocationId: String?
    @State private var seeded = false

    private var changed: Bool { locationId != asset.locationId || subLocationId != asset.subLocationId }
    private var canSubmit: Bool { locationId != nil && changed && !viewModel.isMutating }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    Picker("Location", selection: $locationId) {
                        Text("Select…").tag(String?.none)
                        ForEach(locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    .onChange(of: locationId) { _, new in
                        // Ignore the initial programmatic seed — only clear the sub-location
                        // on a user-driven location change.
                        guard seeded else { return }
                        subLocationId = nil
                        subLocations = []
                        if let id = new { Task { await loadSubs(id) } }
                    }
                    if !subLocations.isEmpty {
                        Picker("Sub-location", selection: $subLocationId) {
                            Text("None").tag(String?.none)
                            ForEach(subLocations) { Text($0.code ?? $0.description ?? "—").tag(String?.some($0.id)) }
                        }
                    }
                }
                if let err = viewModel.actionError {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Move Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { viewModel.actionError = nil; dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") { Task { await submit() } }.disabled(!canSubmit)
                }
            }
            .task {
                locationId = asset.locationId
                subLocationId = asset.subLocationId
                locations = (try? await InventoryService().fetchLocations()) ?? []
                if let id = asset.locationId { await loadSubs(id) }
                seeded = true
            }
        }
    }

    private func loadSubs(_ id: String) async {
        subLocations = (try? await InventoryService().fetchSubLocations(locationId: id)) ?? []
    }
    private func submit() async {
        guard let locationId else { return }
        await viewModel.move(MoveAssetRequest(locationId: locationId, subLocationId: subLocationId))
        if viewModel.actionError == nil { dismiss() }
    }
}
