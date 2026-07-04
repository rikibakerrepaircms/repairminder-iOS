import SwiftUI

/// Sheet for adding an in-stock inventory asset onto a device as a used part.
///
/// Reuses the Inventory feature's existing scan/lookup pipeline rather than adding
/// a new one: `InventoryScannerSheet` (camera, iOS-only) or manual text entry both
/// yield a raw tag/serial string, which is resolved to an `Asset` (with its UUID)
/// via `InventoryService.fetchAssetByTag` — the same call `InventoryListView` uses
/// for its own scan-to-lookup flow. Once resolved, `onAllocate` is handed the
/// asset's `id` so the caller can allocate it (mirrors `DeployToOrderWizard`, which
/// allocates to an order instead of a device).
struct AddPartSheet: View {
    /// Called with the resolved asset's id. Return nil on success, or an
    /// error message to display (e.g. "asset not in stock").
    let onAllocate: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    private let service: InventoryServing = InventoryService()

    @State private var tagText = ""
    @State private var foundAsset: Asset?
    @State private var lookupError: String?
    @State private var allocateError: String?
    @State private var isLookingUp = false
    @State private var isAllocating = false
    #if os(iOS)
    @State private var showScanner = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Asset tag or serial number", text: $tagText)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .autocorrectionDisabled()
                        .onSubmit { Task { await lookup() } }

                    #if os(iOS)
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Asset Tag", systemImage: "barcode.viewfinder")
                    }
                    #endif

                    Button {
                        Task { await lookup() }
                    } label: {
                        HStack {
                            Text("Look Up")
                            if isLookingUp { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(tagText.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
                } footer: {
                    Text("Scan or enter the tag of an in-stock asset to add it as a used part on this device.")
                }

                if let lookupError {
                    Section {
                        Text(lookupError).font(.callout).foregroundStyle(.orange)
                    }
                }

                if let asset = foundAsset {
                    Section("Found Asset") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(asset.name).font(.subheadline.weight(.medium))
                                Spacer()
                                AssetStatusBadge(status: asset.status)
                            }
                            Text(asset.assetTag)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if asset.status != .inStock {
                            Text("This asset is not in stock (status: \(asset.status.displayName)) and cannot be added.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if let allocateError {
                        Section {
                            Text(allocateError).font(.callout).foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button {
                            Task { await allocate(asset) }
                        } label: {
                            HStack {
                                Text("Add to Device")
                                if isAllocating { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(asset.status != .inStock || isAllocating)
                    }
                }
            }
            .navigationTitle("Add Part")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showScanner) {
                InventoryScannerSheet { tag in
                    showScanner = false
                    tagText = tag
                    Task { await lookup() }
                }
            }
            #endif
        }
    }

    private func lookup() async {
        let parsed = AssetScan.parse(tagText)
        guard !parsed.isEmpty else { return }
        isLookingUp = true
        lookupError = nil
        allocateError = nil
        foundAsset = nil
        do {
            foundAsset = try await service.fetchAssetByTag(parsed)
        } catch {
            lookupError = "No asset found for \"\(parsed)\"."
        }
        isLookingUp = false
    }

    private func allocate(_ asset: Asset) async {
        isAllocating = true
        allocateError = nil
        let result = await onAllocate(asset.id)
        isAllocating = false
        if let result {
            allocateError = result
        } else {
            dismiss()
        }
    }
}
