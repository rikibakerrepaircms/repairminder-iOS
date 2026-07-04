import SwiftUI

struct KioskCartLineRow: View {
    let item: KioskCartItem
    let computed: KioskComputedLine
    let onQuantityChange: (Int) -> Void
    let onEditDiscount: () -> Void
    let onManageAssets: () -> Void
    let onRemove: () -> Void

    private var grossIncVat: Double {
        KioskCartMath.jsRound2(Double(item.quantity) * item.unitPrice * (1 + item.vatRate / 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.description).font(.subheadline.weight(.medium)).lineLimit(2)
                    if let sku = item.productSku { Text(sku).font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer()
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.7))
                }.buttonStyle(.plain)
            }

            HStack {
                HStack(spacing: 0) {
                    Button {
                        if item.quantity > 1 { onQuantityChange(item.quantity - 1) } else { onRemove() }
                    } label: { Image(systemName: "minus").frame(width: 34, height: 34) }
                    Text("\(item.quantity)").font(.body.weight(.medium)).frame(minWidth: 32)
                    Button {
                        if item.selectedAssets.isEmpty {
                            onQuantityChange(item.quantity + 1)
                        } else {
                            onManageAssets()   // serialized: reopen allocation to add the extra unit
                        }
                    } label: { Image(systemName: "plus").frame(width: 34, height: 34) }
                }
                .buttonStyle(.bordered)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    if computed.effectiveDiscount > 0 {
                        Text(money(grossIncVat)).font(.caption2).strikethrough().foregroundStyle(.secondary)
                    }
                    Text(money(computed.lineTotalIncVat)).font(.callout.weight(.bold))
                }
            }

            if !item.selectedAssets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.selectedAssets) { a in
                            Button { onManageAssets() } label: {
                                HStack(spacing: 3) {
                                    Text(a.assetTag ?? a.name).font(.caption2)
                                    if let sub = a.subLocation {
                                        Image(systemName: "mappin").font(.caption2)
                                        Text(sub).font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            } else if item.productTypeId != nil {
                Button { onManageAssets() } label: {
                    Label("Allocate stock", systemImage: "shippingbox").font(.caption2)
                }.buttonStyle(.plain)
            }

            Button { onEditDiscount() } label: {
                if computed.effectiveDiscount > 0 {
                    Label(discountLabel + reasonSuffix, systemImage: "tag.fill").font(.caption2).foregroundStyle(.green)
                } else {
                    Text("Add discount").font(.caption2).foregroundStyle(.blue)
                }
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var discountLabel: String {
        if let pct = item.discountPercent, pct != 0 { return "\(pctText(pct))% off" }
        return "\(money(item.discountAmount ?? 0)) off"
    }
    private var reasonSuffix: String {
        if let r = item.discountReason, !r.isEmpty { return " — \(r)" }
        return ""
    }
    private func pctText(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }
    private func money(_ v: Double) -> String { String(format: "£%.2f", v) }
}
