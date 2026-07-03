import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AssetImportViewModel: ObservableObject {
    private let service: InventoryServing

    @Published var createMissing = true
    @Published var isImporting = false
    @Published var result: AssetImportCounts?
    @Published var validationErrors: [AssetImportRowError] = []
    @Published var error: String?

    init(service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
    }

    func importFile(data: Data, fileName: String) async {
        isImporting = true; error = nil; result = nil; validationErrors = []
        defer { isImporting = false }
        do {
            let resp = try await service.importAssets(csvData: data, fileName: fileName, createMissing: createMissing)
            result = resp.data
        } catch let APIError.httpError(status, message) where status == 400 {
            // The 400 validation body carries structured row errors.
            if let body = message?.data(using: .utf8),
               let decoded = try? decodeValidation(body) {
                validationErrors = decoded.errors ?? []
                error = decoded.message ?? decoded.error ?? "Validation failed"
            } else {
                error = message ?? "Import failed"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func decodeValidation(_ data: Data) throws -> AssetImportValidationBody {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(AssetImportValidationBody.self, from: data)
    }
}

/// Admin-only CSV import. Picks a `.csv`, uploads it multipart, and reports the
/// imported counts or the per-row validation errors.
struct AssetImportSheet: View {
    @StateObject private var viewModel = AssetImportViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false

    private var isAdmin: Bool { AuthManager.shared.currentUser?.role.isAdmin == true }

    var body: some View {
        NavigationStack {
            Form {
                if !isAdmin {
                    Section { Label("CSV import is admin-only.", systemImage: "lock").foregroundStyle(.secondary) }
                } else {
                    Section {
                        Toggle("Create missing product types", isOn: $viewModel.createMissing)
                        Button { showImporter = true } label: { Label("Choose CSV file", systemImage: "doc.badge.plus") }
                            .disabled(viewModel.isImporting)
                    } footer: {
                        Text("CSV must include a `sku` column. Max 1000 rows.")
                    }
                    if viewModel.isImporting { Section { ProgressView("Importing…") } }
                    if let r = viewModel.result {
                        Section("Imported") {
                            Text("\(r.imported) asset\(r.imported == 1 ? "" : "s") imported")
                            if let pt = r.createdProductTypes, pt > 0 { Text("\(pt) product types created").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if let err = viewModel.error {
                        Section("Error") { Text(err).font(.footnote).foregroundStyle(.red) }
                    }
                    if !viewModel.validationErrors.isEmpty {
                        Section("Validation errors (\(viewModel.validationErrors.count))") {
                            ForEach(viewModel.validationErrors) { e in Text(e.display).font(.caption) }
                        }
                    }
                }
            }
            .navigationTitle("Import CSV")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { return }
                Task { await viewModel.importFile(data: data, fileName: url.lastPathComponent) }
            }
        }
    }
}
