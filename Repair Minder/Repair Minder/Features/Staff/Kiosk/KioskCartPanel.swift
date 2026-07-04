import SwiftUI

struct KioskCartPanel: View {
    @ObservedObject var viewModel: KioskViewModel
    let onPayCard: () -> Void
    let onSubmitPayment: (_ method: String, _ amount: Double, _ notes: String?) -> Void
    let onEditItemDiscount: (KioskCartItem) -> Void
    let onEditGlobalDiscount: () -> Void
    let onManageAssets: (KioskCartItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            clientBar
            Divider()
            if viewModel.items.isEmpty {
                ContentUnavailableView("Cart is empty", systemImage: "cart",
                    description: Text("Add products to start a sale."))
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
            Divider()
            totalsAndPay
        }
    }

    private var clientBar: some View {
        KioskClientSelector(viewModel: viewModel)
            .padding(.horizontal).padding(.vertical, 8)
    }

    private var totalsAndPay: some View {
        let t = viewModel.totals
        return VStack(spacing: 10) {
            row("Subtotal", t.subtotal)
            if t.discountTotal > 0 { row("Discount", -t.discountTotal, tint: .green) }
            row("VAT", t.vatTotal)
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(money(t.grandTotal)).font(.headline)
            }
            Button { onEditGlobalDiscount() } label: {
                Label(t.globalDiscount > 0 ? "Edit order discount" : "Add order discount",
                      systemImage: "percent").font(.caption)
            }.buttonStyle(.borderless)

            KioskPaymentActions(
                hasItems: !viewModel.items.isEmpty,
                balanceDue: viewModel.totals.grandTotal,
                posProvider: viewModel.posProvider,
                processing: false,
                onCardPayment: onPayCard,
                onSubmitPayment: onSubmitPayment)
        }
        .padding()
    }

    private func row(_ label: String, _ value: Double, tint: Color? = nil) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(money(value)).foregroundStyle(tint ?? .primary)
        }.font(.subheadline)
    }

    private func money(_ v: Double) -> String { String(format: "£%.2f", v) }
}
