import SwiftUI

struct KioskCustomItemSheet: View {
    let onAdd: (KioskCartItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var priceText = ""
    @State private var itemType = "accessory"

    private let types: [(String, String)] = [
        ("accessory", "Accessory"), ("repair", "Repair"), ("device_sale", "Device Sale")
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Description", text: $description)
                TextField("Price (£)", text: $priceText).keyboardDecimalIfIOS()
                Picker("Type", selection: $itemType) {
                    ForEach(types, id: \.0) { Text($0.1).tag($0.0) }
                }
            }
            .navigationTitle("Custom Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(KioskCartItem(
                            description: description.trimmingCharacters(in: .whitespaces),
                            quantity: 1,
                            unitPrice: Double(priceText) ?? 0,
                            vatRate: 20,
                            itemType: itemType))
                        dismiss()
                    }
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder func keyboardDecimalIfIOS() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
