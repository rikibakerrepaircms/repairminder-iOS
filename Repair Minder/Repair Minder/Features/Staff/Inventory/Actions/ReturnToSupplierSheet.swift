import SwiftUI

struct ReturnToSupplierSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var reason: String = ""
    @State private var notes: String = ""

    private let reasons: [(value: String, label: String)] = [
        ("defective", "Defective / DOA"),
        ("wrong_part", "Wrong Part Sent"),
        ("damaged_in_transit", "Damaged in Transit"),
        ("quality_issue", "Quality Below Standard"),
        ("warranty_claim", "Warranty Claim"),
        ("order_error", "Ordered in Error"),
        ("other", "Other")
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let supplier = asset.supplierName {
                    Section("Supplier") { Text(supplier) }
                } else {
                    Section {
                        Text("This asset has no supplier assigned. You won't be able to track this return.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("Reason") {
                    Picker("Return reason", selection: $reason) {
                        Text("Select…").tag("")
                        ForEach(reasons, id: \.value) { Text($0.label).tag($0.value) }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                if let err = viewModel.actionError {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Return to Supplier")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { viewModel.actionError = nil; dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Return") { Task { await submit() } }
                        .disabled(reason.isEmpty || asset.supplierName == nil || viewModel.isMutating)
                }
            }
        }
    }

    private func submit() async {
        await viewModel.returnToSupplier(
            ReturnToSupplierRequest(supplierReturnReason: reason,
                                    supplierReturnNotes: notes.isEmpty ? nil : notes))
        if viewModel.actionError == nil { dismiss() }
    }
}
