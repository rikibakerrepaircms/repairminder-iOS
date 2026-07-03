import SwiftUI

/// Bulk move: pick a destination location (+ optional sub-location); each selected
/// asset is moved via its own `/move` call, tolerating partial failure.
struct BulkMoveSheet: View {
    @StateObject private var viewModel: BulkMoveViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var locations: [Location] = []
    @State private var subLocations: [AssetSubLocationOption] = []
    @State private var locationId: String?
    @State private var subLocationId: String?

    init(assets: [Asset], onDone: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BulkMoveViewModel(assets: assets))
        self.onDone = onDone
    }

    private var canSubmit: Bool { locationId != nil && !viewModel.isRunning && !viewModel.finished }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    Picker("Location", selection: $locationId) {
                        Text("Select…").tag(String?.none)
                        ForEach(locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    .onChange(of: locationId) { _, new in
                        subLocationId = nil; subLocations = []
                        if let id = new { Task { subLocations = (try? await InventoryService().fetchSubLocations(locationId: id)) ?? [] } }
                    }
                    if !subLocations.isEmpty {
                        Picker("Sub-location", selection: $subLocationId) {
                            Text("None").tag(String?.none)
                            ForEach(subLocations) { Text($0.code ?? $0.description ?? "—").tag(String?.some($0.id)) }
                        }
                    }
                }
                Section("\(viewModel.assets.count) asset\(viewModel.assets.count == 1 ? "" : "s")") {
                    if viewModel.isRunning || viewModel.finished {
                        BulkProgressView(total: viewModel.assets.count, outcomes: viewModel.outcomes, isRunning: viewModel.isRunning)
                    } else {
                        ForEach(viewModel.assets.prefix(20)) { a in
                            Text(a.assetTag).font(.subheadline.monospaced())
                        }
                        if viewModel.assets.count > 20 { Text("+\(viewModel.assets.count - 20) more").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("Move \(viewModel.assets.count)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.finished ? "Done" : "Cancel") { if viewModel.finished { onDone() }; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        guard let locationId else { return }
                        Task { await viewModel.run(locationId: locationId, subLocationId: subLocationId) }
                    }
                    .disabled(!canSubmit)
                }
            }
            .task { locations = (try? await InventoryService().fetchLocations()) ?? [] }
        }
    }
}
