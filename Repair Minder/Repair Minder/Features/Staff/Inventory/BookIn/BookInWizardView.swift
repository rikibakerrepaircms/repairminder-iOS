import SwiftUI

/// The 4-step book-in wizard: Order Details → Line Items → Receive → Success.
struct BookInWizardView: View {
    @StateObject private var viewModel = BookInWizardViewModel()
    let orderId: String?
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(orderId: String?, onFinished: @escaping () -> Void) {
        self.orderId = orderId
        self.onFinished = onFinished
    }

    var body: some View {
        Group {
            switch viewModel.step {
            case .orderDetails: OrderDetailsStep(viewModel: viewModel)
            case .lineItems: LineItemsStep(viewModel: viewModel)
            case .receive: ReceiveItemsStep(viewModel: viewModel)
            case .success: BookInSuccessStep(viewModel: viewModel, onDone: { onFinished(); dismiss() })
            }
        }
        .navigationTitle(stepTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.loadSuppliers()
            if let orderId { await viewModel.loadExisting(id: orderId) }
        }
    }

    private var stepTitle: String {
        switch viewModel.step {
        case .orderDetails: return "Order Details"
        case .lineItems: return "Line Items"
        case .receive: return "Receive"
        case .success: return "Booked In"
        }
    }
}

// MARK: - Step 1: Order details (+ invoice upload)

private struct OrderDetailsStep: View {
    @ObservedObject var viewModel: BookInWizardViewModel

    var body: some View {
        Form {
            #if os(iOS)
            if !viewModel.isEditingExisting {
                Section("Invoice (optional)") {
                    InvoiceUploadView(viewModel: viewModel)
                }
            }
            #endif
            Section("Supplier") {
                TextField("Supplier name", text: $viewModel.supplierName)
                    .disabled(viewModel.isEditingExisting)
                if !viewModel.suppliers.isEmpty && viewModel.supplierName.isEmpty {
                    ForEach(viewModel.suppliers.prefix(5)) { s in
                        Button(s.supplierName) { viewModel.supplierName = s.supplierName }.font(.caption)
                    }
                }
                TextField("Reference", text: $viewModel.reference)
            }
            Section("Dates") {
                TextField("Order date (YYYY-MM-DD)", text: $viewModel.orderDate)
                Toggle("Stock in hand", isOn: $viewModel.stockInHand)
                if !viewModel.stockInHand {
                    TextField("Expected date (YYYY-MM-DD)", text: $viewModel.expectedDate)
                }
            }
            Section("Notes") {
                TextField("Notes", text: $viewModel.notes, axis: .vertical).lineLimit(2...4)
            }
            if !viewModel.pendingLines.isEmpty {
                Section("\(viewModel.pendingLines.count) line\(viewModel.pendingLines.count == 1 ? "" : "s") from invoice") {
                    ForEach(Array(viewModel.pendingLines.enumerated()), id: \.offset) { _, line in
                        Text("\(line.name) × \(line.quantityOrdered ?? 1)").font(.caption)
                    }
                }
            }
            if let err = viewModel.error { Section { Text(err).font(.footnote).foregroundStyle(.red) } }
        }
        .safeAreaInset(edge: .bottom) {
            Button { Task { await viewModel.submitOrderDetails() } } label: {
                HStack { Spacer(); Text(viewModel.isEditingExisting ? "Continue" : "Create Order"); Spacer() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmitOrderDetails)
            .padding()
            .accessibilityIdentifier("bookin-create-order")
        }
    }
}

// MARK: - Step 2: Line items

private struct LineItemsStep: View {
    @ObservedObject var viewModel: BookInWizardViewModel
    @State private var newName = ""
    @State private var newQty = "1"
    @State private var newCost = "0"
    @State private var editingLine: SupplierOrderLine?

    var body: some View {
        Form {
            Section("Lines") {
                if viewModel.lines.isEmpty { Text("No lines yet — add one below.").font(.caption).foregroundStyle(.secondary) }
                ForEach(viewModel.lines) { line in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(line.name).font(.subheadline)
                            Text("qty \(line.quantityOrdered) · recv \(line.quantityReceived) · \(CurrencyFormatter.format(line.unitCost ?? 0))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if line.quantityReceived == 0 {
                            Button { editingLine = line } label: { Image(systemName: "pencil") }.buttonStyle(.plain)
                            Button(role: .destructive) { Task { await viewModel.deleteLine(line.id) } } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Section("Add line") {
                TextField("Name", text: $newName)
                HStack {
                    TextField("Qty", text: $newQty)
                    TextField("Unit cost", text: $newCost)
                }
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                Button("Add line") {
                    Task {
                        await viewModel.addLine(SupplierOrderLineRequest(name: newName, quantityOrdered: Int(newQty) ?? 1, unitCost: Double(newCost) ?? 0))
                        newName = ""; newQty = "1"; newCost = "0"
                    }
                }.disabled(newName.isEmpty)
            }
            if let err = viewModel.error { Section { Text(err).font(.footnote).foregroundStyle(.red) } }
        }
        .safeAreaInset(edge: .bottom) {
            Button { viewModel.prepareReceive() } label: {
                HStack { Spacer(); Text(viewModel.stockInHand ? "Receive All" : "Continue to Receive"); Spacer() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.lines.isEmpty)
            .padding()
        }
        .sheet(item: $editingLine) { line in
            LineEditSheet(line: line) { body in
                Task { await viewModel.updateLine(line.id, body); editingLine = nil }
            }
        }
    }
}

/// Edit an unreceived line's name / quantity / unit cost (web allows this only when
/// `quantity_received == 0`; the backend enforces the same guard).
private struct LineEditSheet: View {
    let line: SupplierOrderLine
    let onSave: (SupplierOrderLineRequest) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var qty: String
    @State private var cost: String
    // Product-type link (web `BookInForm` parity). The backend already auto-links a
    // line's product type on receive via SKU/name mapping, so this is optional —
    // it just lets staff correct/set it up front from the line editor.
    @State private var productTypeId: String?
    @State private var productTypeQuery: String
    @State private var productTypeOptions: [ProductTypeOption] = []

    init(line: SupplierOrderLine, onSave: @escaping (SupplierOrderLineRequest) -> Void) {
        self.line = line; self.onSave = onSave
        _name = State(initialValue: line.name)
        _qty = State(initialValue: String(line.quantityOrdered))
        _cost = State(initialValue: String(line.unitCost ?? 0))
        _productTypeId = State(initialValue: line.productTypeId)
        _productTypeQuery = State(initialValue: line.productTypeName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Quantity", text: $qty)
                TextField("Unit cost", text: $cost)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                Section("Product Type (optional)") {
                    TextField("Search product types…", text: $productTypeQuery)
                        .onChange(of: productTypeQuery) { _, q in Task { await searchProductTypes(q) } }
                    ForEach(productTypeOptions) { pt in
                        Button {
                            productTypeId = pt.id
                            productTypeQuery = pt.name
                            productTypeOptions = []
                        } label: {
                            HStack {
                                Text(pt.name)
                                Spacer()
                                if productTypeId == pt.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if productTypeId != nil {
                        Button("Clear product type", role: .destructive) {
                            productTypeId = nil; productTypeQuery = ""
                        }
                    }
                }
            }
            .navigationTitle("Edit Line")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(SupplierOrderLineRequest(productTypeId: productTypeId, name: name, quantityOrdered: Int(qty) ?? line.quantityOrdered, unitCost: Double(cost) ?? line.unitCost))
                        dismiss()
                    }.disabled(name.isEmpty)
                }
            }
        }
    }

    private func searchProductTypes(_ query: String) async {
        guard !query.isEmpty else { productTypeOptions = []; return }
        productTypeOptions = (try? await InventoryService().fetchProductTypes(search: query)) ?? []
    }
}

// MARK: - Step 3: Receive

private struct ReceiveItemsStep: View {
    @ObservedObject var viewModel: BookInWizardViewModel

    var body: some View {
        Form {
            ForEach(viewModel.lines.filter { !$0.isFullyReceived }) { line in
                Section(line.name) {
                    ReceiveLineEditor(line: line, draft: bindingFor(line.id))
                }
            }
            if let err = viewModel.error { Section { Text(err).font(.footnote).foregroundStyle(.red) } }
        }
        .safeAreaInset(edge: .bottom) {
            Button { Task { await viewModel.receive() } } label: {
                HStack { Spacer(); if viewModel.isBusy { ProgressView() } else { Text("Receive Stock") }; Spacer() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBusy)
            .padding()
            .accessibilityIdentifier("bookin-receive")
        }
    }

    private func bindingFor(_ id: String) -> Binding<ReceiveDraft> {
        Binding(
            get: { viewModel.drafts[id] ?? ReceiveDraft(quantity: 0) },
            set: { viewModel.drafts[id] = $0 })
    }
}

private struct ReceiveLineEditor: View {
    let line: SupplierOrderLine
    @Binding var draft: ReceiveDraft
    @State private var locations: [Location] = []
    @State private var subLocations: [AssetSubLocationOption] = []
    @State private var seeded = false

    var body: some View {
        Stepper("Quantity: \(draft.quantity)", value: $draft.quantity, in: 0...max(line.remaining, 1))
        Picker("Condition", selection: $draft.conditionGrade) {
            ForEach(["A", "B", "C", "D", "F"], id: \.self) { Text($0).tag($0) }
        }
        Stepper("Warranty: \(draft.warrantyMonths) mo", value: $draft.warrantyMonths, in: 0...60, step: 3)
        // Defensive: even if `draft.quantity` is momentarily stale above `remaining` (e.g. a
        // draft carried over from before the order's receipts changed), never render more
        // serial fields than units left to receive.
        if serialCount > 0 {
            ForEach(0..<serialCount, id: \.self) { i in
                TextField("Serial \(i + 1) (optional)", text: serialBinding(i))
            }
        }
        Picker("Location", selection: $draft.locationId) {
            Text("Default").tag(String?.none)
            ForEach(locations) { Text($0.name).tag(String?.some($0.id)) }
        }
        .onChange(of: draft.locationId) { _, new in
            // Ignore the initial programmatic seed — only clear the sub-location
            // on a user-driven location change (matches AssetMoveSheet's pattern).
            guard seeded else { return }
            draft.subLocationId = nil
            subLocations = []
            if let id = new { Task { await loadSubs(id) } }
        }
        .task {
            locations = (try? await InventoryService().fetchLocations()) ?? []
            // Default the picker from the line's own location (draft is seeded with it in
            // `prepareReceive()`), loading the option list so the draft's existing
            // sub-location (also seeded from the line) resolves to a real row.
            if let id = draft.locationId ?? line.locationId { await loadSubs(id) }
            seeded = true
        }
        if !subLocations.isEmpty {
            Picker("Sub-location", selection: $draft.subLocationId) {
                Text("None").tag(String?.none)
                ForEach(subLocations) { Text($0.code ?? $0.description ?? "—").tag(String?.some($0.id)) }
            }
        }
    }

    private func loadSubs(_ id: String) async {
        subLocations = (try? await InventoryService().fetchSubLocations(locationId: id)) ?? []
    }

    private var serialCount: Int { min(draft.quantity, line.remaining) }

    private func serialBinding(_ i: Int) -> Binding<String> {
        Binding(
            get: { i < draft.serials.count ? draft.serials[i] : "" },
            set: { val in
                while draft.serials.count <= i { draft.serials.append("") }
                draft.serials[i] = val
            })
    }
}

// MARK: - Step 4: Success

private struct BookInSuccessStep: View {
    @ObservedObject var viewModel: BookInWizardViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
            Text("\(viewModel.createdAssets.count) asset\(viewModel.createdAssets.count == 1 ? "" : "s") booked in").font(.headline)
            List {
                ForEach(viewModel.createdAssets) { a in
                    VStack(alignment: .leading) {
                        Text(a.assetTag).font(.subheadline.monospaced())
                        if let sn = a.serialNumber { Text(sn).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .listStyle(.plain)
            HStack {
                if viewModel.hasUnreceived {
                    Button("Receive More") { viewModel.receiveMore() }.buttonStyle(.bordered)
                }
                Button("Done") { onDone() }.buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
