import SwiftUI

struct KioskPaymentActions: View {
    let hasItems: Bool
    let balanceDue: Double
    let posProvider: String?
    let processing: Bool
    let onCardPayment: () -> Void
    let onSubmitPayment: (_ method: String, _ amount: Double, _ notes: String?) -> Void

    @State private var showOtherForm = false
    @State private var otherMethod = "card"
    @State private var otherAmountText = ""
    @State private var otherNotes = ""

    private let otherMethods: [(String, String)] = [
        ("card","Card"), ("bank_transfer","Bank Transfer"), ("paypal","PayPal"), ("invoice","Invoice"), ("other","Other")
    ]

    var body: some View {
        if !hasItems {
            Text("Add items to take payment")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .padding()
        } else {
            VStack(spacing: 8) {
                if let posProvider {
                    Button { onCardPayment() } label: {
                        HStack(spacing: 8) {
                            if processing { ProgressView().tint(.white) }
                            else { PosProviderLogo(provider: posProvider, height: 20) }
                            Text("Card — \(money(balanceDue))").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(providerBackground(posProvider), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(processing)
                }

                Button { onSubmitPayment("cash", balanceDue, nil) } label: {
                    HStack(spacing: 8) {
                        if processing { ProgressView().tint(.white) }
                        else { Image(systemName: "banknote.fill") }
                        Text("Cash — \(money(balanceDue))").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(processing)

                HStack(spacing: 8) {
                    secondaryButton(posProvider != nil ? "Manual Card" : "Card", "creditcard") { openOther("card") }
                    secondaryButton("Bank", "building.columns") { openOther("bank_transfer") }
                    secondaryButton("Other", "ellipsis") { openOther("other") }
                }

                if showOtherForm { otherForm }
            }
            .padding()
        }
    }

    private var otherForm: some View {
        VStack(spacing: 10) {
            Picker("Method", selection: $otherMethod) {
                ForEach(otherMethods, id: \.0) { Text($0.1).tag($0.0) }
            }
            #if os(iOS)
            .pickerStyle(.menu)
            #endif
            TextField("Amount (£)", text: $otherAmountText).keyboardDecimalIfIOS()
                .textFieldStyle(.roundedBorder)
            TextField("Notes (optional)", text: $otherNotes)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { showOtherForm = false }.buttonStyle(.bordered)
                Spacer()
                Button("Take Payment") {
                    let amount = Double(otherAmountText) ?? 0
                    guard amount > 0, amount <= balanceDue + 0.001 else { return }
                    onSubmitPayment(otherMethod, amount, otherNotes.isEmpty ? nil : otherNotes)
                    showOtherForm = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!otherAmountIsValid || processing)
            }
            if !otherAmountText.isEmpty && !otherAmountIsValid {
                Text("Enter an amount between £0.01 and \(money(balanceDue)).")
                    .font(.caption2).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var otherAmountIsValid: Bool {
        let amount = Double(otherAmountText) ?? 0
        return amount > 0 && amount <= balanceDue + 0.001
    }

    private func secondaryButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private func openOther(_ method: String) {
        otherMethod = method
        otherAmountText = String(format: "%.2f", balanceDue)
        otherNotes = ""
        showOtherForm = true
    }

    private func providerBackground(_ provider: String) -> AnyShapeStyle {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
            Color(.sRGB, red: r/255, green: g/255, blue: b/255, opacity: 1)
        }
        switch provider {
        case "revolut":
            return AnyShapeStyle(LinearGradient(
                colors: [c(13,89,236), c(0,143,225), c(32,175,255)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        case "square": return AnyShapeStyle(c(62,67,72))
        case "sumup":  return AnyShapeStyle(c(26,76,255))
        case "dojo":   return AnyShapeStyle(c(38,38,38))
        default:       return AnyShapeStyle(c(55,65,81))
        }
    }

    private func money(_ v: Double) -> String { String(format: "£%.2f", v) }
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
