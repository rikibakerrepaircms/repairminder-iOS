import SwiftUI

struct KioskCartLineRow: View {
    let item: KioskCartItem
    let computed: KioskComputedLine
    let onQuantityChange: (Int) -> Void
    let onEditDiscount: () -> Void
    let onManageAssets: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.description).font(.subheadline.weight(.semibold))
                    if let sku = item.productSku { Text(sku).font(.caption2).foregroundStyle(.secondary) }
                    if computed.effectiveDiscount > 0 {
                        Text("Discount −\(money(computed.effectiveDiscount))")
                            .font(.caption2).foregroundStyle(.green)
                    }
                    if !item.selectedAssets.isEmpty {
                        Text("\(item.selectedAssets.count) asset(s) allocated")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(money(computed.lineTotalIncVat)).font(.callout.weight(.bold))
            }
            HStack(spacing: 12) {
                Stepper(value: Binding(get: { item.quantity },
                                       set: { onQuantityChange($0) }), in: 1...999) {
                    Text("Qty \(item.quantity)").font(.caption)
                }
                .labelsHidden()
                Text("Qty \(item.quantity)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { onEditDiscount() } label: { Image(systemName: "percent") }.buttonStyle(.borderless)
                if item.productTypeId != nil {
                    Button { onManageAssets() } label: { Image(systemName: "shippingbox") }.buttonStyle(.borderless)
                }
                Button(role: .destructive) { onRemove() } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 8)
    }

    private func money(_ v: Double) -> String { String(format: "£%.2f", v) }
}
