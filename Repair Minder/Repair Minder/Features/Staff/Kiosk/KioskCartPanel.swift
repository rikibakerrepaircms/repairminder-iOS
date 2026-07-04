import SwiftUI

struct KioskCartPanel: View {
    @ObservedObject var viewModel: KioskViewModel
    let onPayCard: () -> Void
    let onSubmitPayment: (_ method: String, _ amount: Double, _ notes: String?) -> Void
    let onEditItemDiscount: (KioskCartItem) -> Void
    let onEditGlobalDiscount: () -> Void
    let onManageAssets: (KioskCartItem) -> Void

    @State private var showCustomForm = false
    @State private var customType = "accessory"
    @State private var customDescription = ""
    @State private var customPriceText = ""

    private let itemTypes: [(String, String, String)] = [
        ("accessory", "Accessory", "bag"),
        ("repair", "Repair", "wrench.and.screwdriver"),
        ("device_sale", "Device", "tag")
    ]

    var body: some View {
        VStack(spacing: 0) {
            KioskClientSelector(viewModel: viewModel)
                .padding(.horizontal).padding(.vertical, 8)
            Divider()
            cartHeader
            if showCustomForm { customForm }
            Divider()
            itemsArea
            Divider()
            footer
        }
    }

    private var cartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Cart").font(.headline)
                Text("\(viewModel.itemCount) item\(viewModel.itemCount == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { withAnimation { showCustomForm.toggle() } } label: {
                Label("Custom Item", systemImage: showCustomForm ? "xmark" : "plus").font(.caption)
            }.buttonStyle(.bordered)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private var customForm: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(itemTypes, id: \.0) { t in
                    Button { customType = t.0 } label: {
                        VStack(spacing: 2) { Image(systemName: t.2); Text(t.1).font(.caption2) }
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .tint(customType == t.0 ? .accentColor : .secondary)
                }
            }
            TextField("Description", text: $customDescription).textFieldStyle(.roundedBorder)
            HStack {
                Text("£").foregroundStyle(.secondary)
                TextField("Price", text: $customPriceText).keyboardDecimalIfIOS().textFieldStyle(.roundedBorder)
                Button("Add") { addCustom() }
                    .buttonStyle(.borderedProminent)
                    .disabled(customDescription.trimmingCharacters(in: .whitespaces).isEmpty || (Double(customPriceText) ?? 0) <= 0)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.quaternary)
    }

    private func addCustom() {
        viewModel.addItem(KioskCartItem(
            description: customDescription.trimmingCharacters(in: .whitespaces),
            quantity: 1,
            unitPrice: Double(customPriceText) ?? 0,
            vatRate: 20,
            itemType: customType))
        customDescription = ""; customPriceText = ""; customType = "accessory"
        withAnimation { showCustomForm = false }
    }

    @ViewBuilder private var itemsArea: some View {
        if viewModel.items.isEmpty {
            ContentUnavailableView("Tap a product to add it", systemImage: "cart")
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.items) { item in
                    KioskCartLineRow(
                        item: item,
                        computed: KioskCartMath.computeLineItem(item),
                        onQuantityChange: { viewModel.setQuantity(item.id, $0) },
                        onEditDiscount: { onEditItemDiscount(item) },
                        onManageAssets: { onManageAssets(item) },
                        onRemove: { viewModel.removeItem(item.id) })
                }
            }
            .listStyle(.plain)
        }
    }

    private var footer: some View {
        let t = viewModel.totals
        return VStack(spacing: 8) {
            VStack(spacing: 4) {
                row("Subtotal", t.subtotal)
                if t.discountTotal > 0 { row("Discount", -t.discountTotal, tint: .green) }
                row("VAT", t.vatTotal)
                HStack { Text("Total").font(.headline); Spacer(); Text(money(t.grandTotal)).font(.headline) }
            }
            .padding(.horizontal).padding(.top, 8)

            globalDiscountButton.padding(.horizontal)

            KioskPaymentActions(
                hasItems: !viewModel.items.isEmpty,
                balanceDue: t.grandTotal,
                posProvider: viewModel.posProvider,
                processing: viewModel.isSubmitting,
                onCardPayment: onPayCard,
                onSubmitPayment: onSubmitPayment)
        }
    }

    private var globalDiscountButton: some View {
        Button { onEditGlobalDiscount() } label: {
            if viewModel.totals.globalDiscount > 0 {
                Label(globalDiscountLabel, systemImage: "tag.fill")
                    .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.green)
            } else {
                Label("Add Discount", systemImage: "tag")
                    .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
        }.buttonStyle(.plain)
    }

    private var globalDiscountLabel: String {
        var base: String
        if let pct = viewModel.globalDiscountPercent, pct != 0 {
            base = "\(pct == pct.rounded() ? String(Int(pct)) : String(pct))% off"
        } else {
            base = "\(money(viewModel.totals.globalDiscount)) off"
        }
        if let r = viewModel.globalDiscountReason, !r.isEmpty { base += " — \(r)" }
        return base
    }

    private func row(_ label: String, _ value: Double, tint: Color? = nil) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(money(value)).foregroundStyle(tint ?? .primary) }
            .font(.subheadline)
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
