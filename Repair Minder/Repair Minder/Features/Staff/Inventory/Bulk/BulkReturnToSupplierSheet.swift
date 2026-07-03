import SwiftUI

/// Bulk return-to-supplier. Only assets that are in_stock/allocated/deployed AND
/// have a supplier are eligible (others are counted + skipped, matching the web modal).
struct BulkReturnToSupplierSheet: View {
    @StateObject private var viewModel: BulkReturnViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(assets: [Asset], onDone: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BulkReturnViewModel(assets: assets))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.invalidCount > 0 {
                    Section {
                        Label("\(viewModel.invalidCount) selected asset\(viewModel.invalidCount == 1 ? " is" : "s are") not eligible (needs a supplier and an active status) and will be skipped.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }

                Section("Reason") {
                    Picker("Reason", selection: $viewModel.reason) {
                        ForEach(SupplierReturnReason.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical).lineLimit(2...4)
                }

                ForEach(viewModel.supplierGroups) { group in
                    Section("\(group.supplier) · \(group.assets.count)") {
                        ForEach(group.assets) { a in
                            HStack {
                                Text(a.assetTag).font(.subheadline.monospaced())
                                Spacer()
                                Text(a.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }

                if let err = viewModel.error {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Return to Supplier")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Return \(viewModel.validAssets.count)") {
                        Task {
                            if await viewModel.submit() { onDone(); dismiss() }
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .overlay { if viewModel.isSubmitting { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)) } }
        }
    }
}
