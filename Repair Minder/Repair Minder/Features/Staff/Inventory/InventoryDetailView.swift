import SwiftUI

struct InventoryDetailView: View {
    let assetId: String
    @StateObject private var viewModel: InventoryDetailViewModel

    init(assetId: String) {
        self.assetId = assetId
        _viewModel = StateObject(wrappedValue: InventoryDetailViewModel(assetId: assetId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.asset == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let asset = viewModel.asset {
                ScrollView { VStack(alignment: .leading, spacing: 16) { sections(asset) }.padding() }
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                    Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Retry") { Task { await viewModel.load() } }.buttonStyle(.borderedProminent)
                }.padding()
            }
        }
        .navigationTitle(viewModel.asset?.assetTag ?? "Asset")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { if viewModel.asset == nil { await viewModel.load() } }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder private func sections(_ a: Asset) -> some View {
        header(a)
        if a.status == .pendingReturn { card("Pending Return") {
            row("Reason", a.supplierReturnReason); row("Notes", a.supplierReturnNotes); row("Initiated", a.supplierReturnInitiatedAt)
        } }
        card("Identification") {
            row("Serial", a.serialNumber); row("SKU", a.sku); row("Category", a.category); row("Product Type", a.productTypeName)
        }
        if !viewModel.groups.isEmpty { card("Inventory Groups") {
            ForEach(viewModel.groups) { g in
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name).font(.subheadline.weight(.medium))
                    if let sku = g.sku { Text(sku).font(.caption).foregroundStyle(.secondary) }
                    if let avg = g.avgCost { Text("Avg cost \(CurrencyFormatter.format(avg))").font(.caption).foregroundStyle(.secondary) }
                    if let inStock = g.inStockCount { Text("In stock: \(inStock)").font(.caption).foregroundStyle(.secondary) }
                    if let min = g.minCost, let max = g.maxCost {
                        Text("Cost \(CurrencyFormatter.format(min))–\(CurrencyFormatter.format(max))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } }
        card("Status & Location") {
            HStack { Text("Status").foregroundStyle(.secondary); Spacer(); AssetStatusBadge(status: a.status) }
            row("Location", a.locationName); row("Sub-location", a.subLocationCode)
            if a.status == .allocated || a.status == .deployed {
                row("Order #", a.checkedOutOrderNumber); row("Device", a.checkedOutDeviceName)
            }
            if let ext = viewModel.externalDeployment?.active {
                row("Deployed to", ext.customerName); row("Reference", ext.externalReference); row("Deployed", ext.deploymentDate)
                row("Deployed by", ext.deployedBy)
                if let history = viewModel.externalDeployment?.history, !history.isEmpty {
                    row("Previous deployments", String(history.count))
                }
            }
        }
        card("Purchase Info") {
            row("Supplier", a.supplierName); row("Order ref", a.supplierOrderReference); row("Purchased", a.purchaseDate)
            row("Cost", a.cost.map { CurrencyFormatter.format($0) }); row("Cost inc VAT", a.costIncVat.map { CurrencyFormatter.format($0) })
        }
        if a.sourceType == "recovered" || a.sourceType == "salvaged" { card("Recovery / Salvage Origin") {
            row("Source", a.sourceType); row("Recovered", a.recoveredAt); row("Condition grade", a.conditionGrade)
            if let lcd = a.lcdWorkingBool { row("LCD working", lcd ? "Yes" : "No") }
            if let glass = a.glassCrackedBool { row("Glass cracked", glass ? "Yes" : "No") }
            row("From buyback", a.recoveredFromBuybackId); row("From order", a.recoveredFromOrderId)
            row("From source asset", a.recoveredFromAssetId); row("From device", a.recoveredFromDeviceId)
            row("Recovered by", a.recoveredBy)
        } }
        if a.checkedOutToBuybackId != nil { card("Buyback Allocation") {
            row("Buyback", a.checkedOutToBuybackId)
        } }
        card("Quality") {
            row("Condition grade", a.conditionGrade)
            row("OEM", a.isOemBool ? "Yes" : "No"); row("Refurbished", a.isRefurbishedBool ? "Yes" : "No")
        }
        card("Warranty") {
            row("Warranty months", a.warrantyMonths.map(String.init)); row("Expires", a.warrantyExpires)
            if let chip = warrantyChip(a.warrantyExpires) {
                Text(chip.text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(chip.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(chip.color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        if let notes = a.notes, !notes.isEmpty { card("Notes") { Text(notes) } }
        if !viewModel.activity.isEmpty { card("Activity") {
            ForEach(viewModel.activity) { act in
                VStack(alignment: .leading, spacing: 2) {
                    Text(act.activityType ?? act.description ?? "Activity").font(.subheadline)
                    if let who = act.performedByName ?? act.performedByEmail { Text(who).font(.caption).foregroundStyle(.secondary) }
                    if let when = act.performedAt { Text(when).font(.caption2).foregroundStyle(.tertiary) }
                }
            }
        } }
    }

    private func header(_ a: Asset) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(a.assetTag).font(.title3.weight(.bold).monospaced()); Spacer(); AssetStatusBadge(status: a.status) }
            Text(a.name).font(.title2.weight(.semibold))
        }
    }

    private func card(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }.font(.subheadline)
        }
    }

    private func warrantyChip(_ expires: String?) -> (text: String, color: Color)? {
        guard let expires, let date = Self.parseDate(expires) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return ("Expired", .red) }
        if days == 0 { return ("Expires today", .orange) }
        return ("\(days) day\(days == 1 ? "" : "s") left", days < 30 ? .orange : .green)
    }
    private static func parseDate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter(); if let d = iso.date(from: s) { return d }
        let f = DateFormatter(); f.calendar = Calendar(identifier: .iso8601); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f.date(from: s)
    }
}
