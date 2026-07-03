import SwiftUI

/// Resolve a supplier return as "replacement received", optionally linking an in-stock
/// replacement asset (mirrors the web ReplacementLinkModal: search in-stock by tag/name,
/// select one, then "Link & Resolve" or "Resolve Without Link").
struct ResolveReplacementSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Asset] = []
    @State private var selectedId: String?
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    private let service = InventoryService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Original: \(asset.assetTag)").font(.footnote.monospaced()).foregroundStyle(.secondary)
                }
                Section("Search for replacement asset (optional)") {
                    TextField("Search by asset tag or name…", text: $query)
                        .onChange(of: query) { _, _ in scheduleSearch() }
                    if searching { ProgressView() }
                    else if !query.isEmpty && results.isEmpty {
                        Text("No in-stock assets found").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(results) { r in
                        Button {
                            selectedId = r.id
                            query = r.assetTag
                            results = []
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.assetTag).font(.subheadline.monospaced())
                                    Text(r.name).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedId == r.id { Image(systemName: "checkmark").foregroundStyle(.blue) }
                            }
                        }
                    }
                }
                Section {
                    Text("You can skip linking a replacement asset and add it later if needed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let err = viewModel.actionError {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Link Replacement")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.actionError = nil; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu("Resolve") {
                        Button("Link & Resolve") { Task { await resolve(link: true) } }
                            .disabled(selectedId == nil)
                        Button("Resolve Without Link") { Task { await resolve(link: false) } }
                    }
                    .disabled(viewModel.isMutating)
                }
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(q)
        }
    }

    private func runSearch(_ q: String) async {
        guard q.count >= 2 else { results = []; return }
        searching = true
        let found = (try? await service.fetchAssets(
            page: 1, pageSize: 10,
            filters: AssetQuery(status: "in_stock", search: q))) ?? []
        // Don't offer the asset being resolved as its own replacement.
        results = found.filter { $0.id != asset.id }
        searching = false
    }

    private func resolve(link: Bool) async {
        await viewModel.resolveReturn(ResolveReturnRequest(
            resolution: "replacement_received",
            replacementAssetId: link ? selectedId : nil,
            notes: nil))
        if viewModel.actionError == nil { dismiss() }
    }
}
