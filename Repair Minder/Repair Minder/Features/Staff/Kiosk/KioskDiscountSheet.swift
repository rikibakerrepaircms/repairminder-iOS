import SwiftUI

struct KioskDiscountValue {
    var percent: Double?
    var amount: Double?
    var reason: String?
}

struct KioskDiscountSheet: View {
    let title: String
    @State private var mode: Mode
    @State private var percentText: String
    @State private var amountText: String
    @State private var reason: String
    let onSave: (KioskDiscountValue) -> Void
    private let hasExisting: Bool
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable { case percent = "Percent", amount = "Amount" }

    init(title: String, initial: KioskDiscountValue, onSave: @escaping (KioskDiscountValue) -> Void) {
        self.title = title
        self.onSave = onSave
        self.hasExisting = initial.percent != nil || initial.amount != nil
        _mode = State(initialValue: initial.percent != nil ? .percent : .amount)
        _percentText = State(initialValue: initial.percent.map { String($0) } ?? "")
        _amountText = State(initialValue: initial.amount.map { String($0) } ?? "")
        _reason = State(initialValue: initial.reason ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)

                if mode == .percent {
                    TextField("Percent", text: $percentText).keyboardTypeNumberIfIOS()
                } else {
                    TextField("Amount (£)", text: $amountText).keyboardTypeNumberIfIOS()
                }
                TextField("Reason (required)", text: $reason)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply(); dismiss() }.disabled(!canApply)
                }
                if hasExisting {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Remove") { onSave(KioskDiscountValue()); dismiss() }
                    }
                }
            }
        }
    }

    private var canApply: Bool {
        guard !reason.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let value = mode == .percent ? Double(percentText) : Double(amountText)
        return (value ?? 0) > 0
    }

    private func apply() {
        let reasonValue = reason.trimmingCharacters(in: .whitespaces).isEmpty ? nil : reason
        if mode == .percent {
            onSave(KioskDiscountValue(percent: Double(percentText), amount: nil, reason: reasonValue))
        } else {
            onSave(KioskDiscountValue(percent: nil, amount: Double(amountText), reason: reasonValue))
        }
    }
}

private extension View {
    @ViewBuilder func keyboardTypeNumberIfIOS() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
