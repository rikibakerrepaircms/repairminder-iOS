import SwiftUI

struct KioskCashPaymentSheet: View {
    let balanceDue: Double
    let onSubmit: (_ method: String, _ amount: Double, _ notes: String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var method = "cash"
    @State private var amountText: String
    @State private var notes = ""

    private let methods: [(String, String)] = [
        ("cash", "Cash"), ("card", "Manual Card"), ("bank_transfer", "Bank Transfer"),
        ("paypal", "PayPal"), ("invoice", "Invoice"), ("other", "Other")
    ]

    init(balanceDue: Double, onSubmit: @escaping (String, Double, String?) -> Void) {
        self.balanceDue = balanceDue
        self.onSubmit = onSubmit
        _amountText = State(initialValue: String(format: "%.2f", balanceDue))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Method", selection: $method) {
                    ForEach(methods, id: \.0) { Text($0.1).tag($0.0) }
                }
                TextField("Amount (£)", text: $amountText).keyboardDecimalIfIOS()
                TextField("Notes (optional)", text: $notes)
                HStack { Text("Balance due"); Spacer(); Text(String(format: "£%.2f", balanceDue)).foregroundStyle(.secondary) }
            }
            .navigationTitle("Take Payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") {
                        let amount = Double(amountText) ?? balanceDue
                        onSubmit(method, amount, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                    .disabled((Double(amountText) ?? 0) <= 0)
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
