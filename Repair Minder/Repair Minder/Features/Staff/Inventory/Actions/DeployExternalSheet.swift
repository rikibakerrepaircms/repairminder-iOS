import SwiftUI

struct DeployExternalSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var customerName = ""
    @State private var externalReference = ""
    @State private var notes = ""
    @State private var deploymentDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Customer name", text: $customerName)
                    TextField("Reference / job number", text: $externalReference)
                }
                Section("Deployment") {
                    DatePicker("Date", selection: $deploymentDate, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                if let err = viewModel.actionError {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Deploy Externally")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { viewModel.actionError = nil; dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Deploy") { Task { await submit() } }.disabled(viewModel.isMutating)
                }
            }
        }
    }

    private func submit() async {
        await viewModel.deployExternal(DeployExternalRequest(
            customerName: customerName.isEmpty ? nil : customerName,
            externalReference: externalReference.isEmpty ? nil : externalReference,
            notes: notes.isEmpty ? nil : notes,
            deploymentDate: DeployExternalRequest.isoDateString(from: deploymentDate)))
        if viewModel.actionError == nil { dismiss() }
    }
}
