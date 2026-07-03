import SwiftUI

struct GroupSelectorSheet: View {
    let assetId: String
    let initialSelection: [String]
    let onSave: ([String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var groups: [InventoryGroup] = []
    @State private var search = ""
    @State private var isCreating = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    private let service = InventoryService()

    var body: some View {
        NavigationStack {
            List {
                if let e = errorMessage { Text(e).foregroundStyle(.red) }
                ForEach(groups) { g in
                    Button {
                        if selected.contains(g.id) { selected.remove(g.id) } else { selected.insert(g.id) }
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(g.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(g.id) ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(g.name)
                                if let sku = g.sku, !sku.isEmpty { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text("\(g.inStockCount ?? 0)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("select-group-\(g.sku ?? g.id)")
                }
                if canCreate {
                    Button { Task { await createGroup() } } label: {
                        Label(isCreating ? "Creating…" : "Add new \"\(search)\"", systemImage: "plus")
                    }.disabled(isCreating)
                }
            }
            .searchable(text: $search)
            .task(id: search) { await loadGroups() }
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                        .accessibilityIdentifier("group-selector-save")
                }
            }
            .onAppear { selected = Set(initialSelection) }
        }
    }

    private var canCreate: Bool {
        let t = search.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && !groups.contains { $0.name.lowercased() == t.lowercased() }
    }

    private func loadGroups() async {
        do {
            groups = try await service.listGroups(page: 1, limit: 30, search: search.isEmpty ? nil : search,
                                                   category: nil, hasProducts: nil, unlinkedOnly: nil, sortBy: "name", sortOrder: "asc")
        } catch { errorMessage = error.localizedDescription }
    }

    private func createGroup() async {
        let name = search.trimmingCharacters(in: .whitespaces); guard !name.isEmpty else { return }
        isCreating = true; defer { isCreating = false }
        do {
            let g = try await service.createGroup(GroupFormRequest(name: name, category: "General"))
            selected.insert(g.id); search = ""; await loadGroups()
        } catch { errorMessage = error.localizedDescription }
    }

    private func save() async {
        isSaving = true; defer { isSaving = false }
        await onSave(Array(selected))
        dismiss()
    }
}
