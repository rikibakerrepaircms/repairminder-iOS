import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct InventoryDetailView: View {
    let assetId: String
    @StateObject private var viewModel: InventoryDetailViewModel

    @State private var showEdit = false
    @State private var showMove = false
    @State private var showDeploy = false
    @State private var showReturnSupplier = false
    @State private var showResolveReplacement = false
    @State private var showDeleteConfirm = false
    @State private var showManageGroups = false
    @State private var copiedTag = false
    @Environment(\.dismiss) private var dismiss

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
        .toolbar { if let asset = viewModel.asset { toolbarMenu(asset) } }
        .sheet(isPresented: $showEdit) { if let a = viewModel.asset { AssetEditSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showMove) { if let a = viewModel.asset { AssetMoveSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showDeploy) { if let a = viewModel.asset { DeployChooserSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showReturnSupplier) { if let a = viewModel.asset { ReturnToSupplierSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showResolveReplacement) { if let a = viewModel.asset { ResolveReplacementSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showManageGroups) {
            GroupSelectorSheet(
                assetId: assetId,
                initialSelection: viewModel.groups.map(\.id)
            ) { desired in await viewModel.manageGroups(groupIds: desired) }
        }
        .confirmationDialog("Delete asset \(viewModel.asset?.assetTag ?? "")? This cannot be undone.",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Action failed", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } })) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError ?? "") }
        .overlay(alignment: .bottom) {
            if let msg = viewModel.groupActionMessage {
                Text(msg)
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        viewModel.groupActionMessage = nil
                    }
            }
        }
        .onChange(of: viewModel.didDelete) { _, deleted in if deleted { dismiss() } }
    }

    @ToolbarContentBuilder private func toolbarMenu(_ a: Asset) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                Button { showMove = true } label: { Label("Move", systemImage: "arrow.left.arrow.right") }
                if AssetActions.canDeploy(a) {
                    Button { showDeploy = true } label: { Label("Deploy", systemImage: "paperplane") }
                }
                Button { showReturnSupplier = true } label: {
                    if let reason = AssetActions.returnToSupplierDisabledReason(a) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Return to Supplier")
                                Text(reason).font(.caption2)
                            }
                        } icon: { Image(systemName: "arrow.uturn.backward") }
                    } else {
                        Label("Return to Supplier", systemImage: "arrow.uturn.backward")
                    }
                }
                .disabled(!AssetActions.canReturnToSupplier(a))
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                    .disabled(!AssetActions.canDelete(a))
            } label: { Image(systemName: "ellipsis.circle").accessibilityIdentifier("asset-actions-menu") }
        }
    }

    private func copyTag(_ tag: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = tag
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(tag, forType: .string)
        #endif
        copiedTag = true
        Task { try? await Task.sleep(nanoseconds: 2_000_000_000); copiedTag = false }
    }

    @ViewBuilder private func sections(_ a: Asset) -> some View {
        header(a)
        if let n = viewModel.lastSkuUpdatedCount {
            Text("Category also applied to \(n) other asset\(n == 1 ? "" : "s") with the same SKU")
                .font(.caption).foregroundStyle(.blue)
                .task { try? await Task.sleep(nanoseconds: 4_000_000_000); viewModel.lastSkuUpdatedCount = nil }
        }
        if viewModel.readyToRepairPrompt {
            Label("This asset's order is ready to repair.", systemImage: "wrench.and.screwdriver")
                .font(.caption).foregroundStyle(.blue)
                .task { try? await Task.sleep(nanoseconds: 5_000_000_000); viewModel.readyToRepairPrompt = false }
        }
        if a.status == .pendingReturn { card("Pending Return") {
            row("Reason", a.supplierReturnReason); row("Notes", a.supplierReturnNotes); row("Initiated", a.supplierReturnInitiatedAt)
            HStack {
                Button("Credit Received") {
                    Task { await viewModel.resolveReturn(ResolveReturnRequest(resolution: "credit_received", replacementAssetId: nil, notes: nil)) }
                }.buttonStyle(.bordered)
                Button("Replacement Received") { showResolveReplacement = true }
                    .buttonStyle(.bordered)
            }
            .disabled(viewModel.isMutating)
            .padding(.top, 4)
        } }
        card("Identification") {
            row("Serial", a.serialNumber); row("SKU", a.sku); row("Category", a.category); row("Product Type", a.productTypeName)
        }
        card("Inventory Groups") {
            if viewModel.groups.isEmpty {
                Text("No groups assigned").font(.caption).foregroundStyle(.secondary)
            } else {
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
            }
            Button { showManageGroups = true } label: { Label("Manage", systemImage: "square.and.pencil") }
                .buttonStyle(.bordered).padding(.top, 4)
                .accessibilityIdentifier("manage-groups")
        }
        card("Status & Location") {
            HStack { Text("Status").foregroundStyle(.secondary); Spacer(); AssetStatusBadge(status: a.status) }
            row("Location", a.locationName); row("Sub-location", a.subLocationCode)
            if a.status == .allocated || a.status == .deployed {
                row("Order #", a.checkedOutOrderNumber.map(String.init)); row("Device", a.checkedOutDeviceName)
            }
            if let ext = viewModel.externalDeployment?.active {
                row("Deployed to", ext.customerName); row("Reference", ext.externalReference); row("Deployed", ext.deploymentDate)
                row("Deployed by", ext.deployedBy)
                if let history = viewModel.externalDeployment?.history, !history.isEmpty {
                    row("Previous deployments", String(history.count))
                }
                if AssetActions.canReturnToStock(a, hasActiveExternalDeployment: true) {
                    Button("Return to Stock") {
                        Task { await viewModel.returnToStock(
                            ReturnExternalRequest(deploymentId: ext.id, returnToStock: true, notes: nil)) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isMutating)
                    .padding(.top, 4)
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
            HStack(spacing: 6) {
                Text(a.assetTag).font(.title3.weight(.bold).monospaced())
                Button { copyTag(a.assetTag) } label: {
                    Image(systemName: copiedTag ? "checkmark" : "doc.on.doc").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(copiedTag ? .green : .secondary)
                .accessibilityLabel("Copy asset tag")
                Spacer()
                AssetStatusBadge(status: a.status)
            }
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
