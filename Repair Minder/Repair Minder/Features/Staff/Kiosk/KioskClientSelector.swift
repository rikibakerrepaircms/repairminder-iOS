import SwiftUI

struct KioskClientSelector: View {
    @ObservedObject var viewModel: KioskViewModel
    @State private var showPicker = false

    var body: some View {
        HStack {
            Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
            if let c = viewModel.selectedClient {
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.displayName).font(.subheadline.weight(.medium))
                    if let e = c.email { Text(e).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                Button("Change") { showPicker = true }.font(.caption)
                Button { viewModel.selectedClient = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            } else {
                Text("Guest checkout").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("Add client") { showPicker = true }.font(.caption)
            }
        }
        .sheet(isPresented: $showPicker) {
            KioskClientPickerSheet { ref in
                viewModel.selectedClient = ref
                showPicker = false
            }
        }
    }
}

private struct KioskClientPickerSheet: View {
    let onSelect: (KioskClientRef) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Client] = []
    @State private var isLoading = false
    @State private var newFirst = ""
    @State private var newLast = ""
    @State private var newEmail = ""
    @State private var newPhone = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Find existing") {
                    TextField("Search by email or name", text: $query)
                        .onChange(of: query) { _, v in scheduleSearch(v) }
                    if isLoading { ProgressView() }
                    ForEach(results) { c in
                        Button {
                            onSelect(KioskClientRef(id: c.id, email: c.email,
                                firstName: c.firstName, lastName: c.lastName, phone: c.phone))
                        } label: {
                            VStack(alignment: .leading) {
                                Text(c.displayName)
                                if let e = c.email { Text(e).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                Section("Add new client") {
                    TextField("First name", text: $newFirst)
                    TextField("Last name", text: $newLast)
                    TextField("Email (optional)", text: $newEmail)
                    TextField("Phone (optional)", text: $newPhone)
                    Button("Use this client") {
                        onSelect(KioskClientRef(id: "",
                            email: newEmail.isEmpty ? nil : newEmail,
                            firstName: newFirst.isEmpty ? nil : newFirst,
                            lastName: newLast.isEmpty ? nil : newLast,
                            phone: newPhone.isEmpty ? nil : newPhone))
                    }
                    .disabled(newFirst.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Client")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            isLoading = true; defer { isLoading = false }
            do {
                let resp: ClientSearchResponse = try await APIClient.shared.request(.clientSearch(query: trimmed))
                if !Task.isCancelled { results = resp.clients }
            } catch { results = [] }
        }
    }
}
