import Foundation

enum BookInStep: Int, CaseIterable { case orderDetails, lineItems, receive, success }

/// Per-line receive inputs (client-side draft).
struct ReceiveDraft: Equatable {
    var quantity: Int
    var conditionGrade: String = "A"
    var warrantyMonths: Int = 12
    var serials: [String] = []
    var locationId: String?
    var subLocationId: String?
}

@MainActor
final class BookInWizardViewModel: ObservableObject {
    private let service: InventoryServing
    /// Web batches receive items in chunks of 20.
    static let receiveChunkSize = 20

    @Published var step: BookInStep = .orderDetails
    @Published var order: SupplierOrder?

    // Order-details fields
    @Published var supplierName = ""
    @Published var reference = ""
    @Published var orderDate = ""
    @Published var expectedDate = ""
    @Published var stockInHand = false
    @Published var notes = ""
    @Published var suppliers: [SupplierNameOption] = []

    // Lines (loaded from the order) + pending extraction lines (added on create)
    @Published var lines: [SupplierOrderLine] = []
    @Published var pendingLines: [SupplierOrderLineRequest] = []
    /// R2 key of an uploaded/extracted invoice, attached to the order on create.
    @Published var invoiceFileKey: String?

    // Receive
    @Published var drafts: [String: ReceiveDraft] = [:]
    @Published var createdAssets: [Asset] = []

    @Published var isBusy = false
    @Published var error: String?
    @Published var isExisting = false

    init(order: SupplierOrder? = nil, service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
        if let order {
            self.isExisting = true
            seed(from: order)
        }
    }

    private func seed(from order: SupplierOrder) {
        self.order = order
        self.supplierName = order.supplierName
        self.reference = order.supplierOrderReference ?? ""
        self.orderDate = order.orderDate ?? ""
        self.expectedDate = order.expectedDate ?? ""
        self.notes = order.notes ?? ""
        self.lines = order.lines ?? []
    }

    /// Load an existing order by id (edit mode entered from the list).
    func loadExisting(id: String) async {
        isExisting = true; isBusy = true
        defer { isBusy = false }
        do { seed(from: try await service.getSupplierOrder(id: id)) }
        catch { self.error = error.localizedDescription }
    }

    var isEditingExisting: Bool { isExisting }
    var canSubmitOrderDetails: Bool { !supplierName.trimmingCharacters(in: .whitespaces).isEmpty && !isBusy }

    func loadSuppliers() async { suppliers = (try? await service.listSuppliers()) ?? [] }

    /// Upload an invoice file, extract, and prefill. Returns true on success.
    @discardableResult
    func extract(fileData: Data, fileName: String, mimeType: String) async -> Bool {
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            let resp = try await service.extractInvoice(fileData: fileData, fileName: fileName, mimeType: mimeType)
            applyExtraction(resp)
            return true
        } catch {
            self.error = "Invoice extraction failed. You can still enter details manually."
            return false
        }
    }

    func applyExtraction(_ resp: ExtractInvoiceResponse) {
        invoiceFileKey = resp.invoiceFileKey
        let inv = resp.data
        if let s = inv.supplierName, !s.isEmpty { supplierName = s }
        if let r = inv.invoiceReference, !r.isEmpty { reference = r }
        if let d = inv.invoiceDate, !d.isEmpty { orderDate = d }
        pendingLines = inv.lineItems.map {
            SupplierOrderLineRequest(productTypeId: $0.productTypeId, name: $0.name, sku: $0.sku,
                                     category: $0.category, quantityOrdered: $0.quantityValue, unitCost: $0.unitCostValue)
        }
    }

    /// Create the order (with any pending extraction lines) or advance if it already exists.
    func submitOrderDetails() async {
        guard canSubmitOrderDetails else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            if order == nil {
                let body = CreateSupplierOrderRequest(
                    supplierName: supplierName,
                    supplierOrderReference: reference.isEmpty ? nil : reference,
                    orderDate: orderDate.isEmpty ? nil : orderDate,
                    expectedDate: stockInHand || expectedDate.isEmpty ? nil : expectedDate,
                    notes: notes.isEmpty ? nil : notes,
                    invoiceFileKey: invoiceFileKey,
                    lines: pendingLines.isEmpty ? nil : pendingLines)
                order = try await service.createSupplierOrder(body)
                pendingLines = []
            }
            await reloadOrder()
            step = .lineItems
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reloadOrder() async {
        guard let id = order?.id else { return }
        do {
            let full = try await service.getSupplierOrder(id: id)
            order = full
            lines = full.lines ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addLine(_ body: SupplierOrderLineRequest) async {
        guard let id = order?.id else { return }
        isBusy = true; defer { isBusy = false }
        do { _ = try await service.addOrderLine(orderId: id, body: body); await reloadOrder() }
        catch { self.error = error.localizedDescription }
    }

    func updateLine(_ lineId: String, _ body: SupplierOrderLineRequest) async {
        guard let id = order?.id else { return }
        do { _ = try await service.updateOrderLine(orderId: id, lineId: lineId, body: body); await reloadOrder() }
        catch { self.error = error.localizedDescription }
    }

    func deleteLine(_ lineId: String) async {
        guard let id = order?.id else { return }
        do { try await service.deleteOrderLine(orderId: id, lineId: lineId); await reloadOrder() }
        catch { self.error = error.localizedDescription }
    }

    // MARK: Receive

    /// Seed a receive draft per line, defaulting quantity to the remaining amount.
    /// A draft that already exists is clamped down to the line's current `remaining` — the
    /// line's ordered/received counts may have changed since the draft was created (e.g. an
    /// edit to the line, or a previous partial receive), and a stale draft quantity above the
    /// new remaining would allow over-receiving (MF-3).
    func prepareReceive() {
        for line in lines where !line.isFullyReceived {
            if var draft = drafts[line.id] {
                draft.quantity = min(draft.quantity, line.remaining)
                drafts[line.id] = draft
            } else {
                drafts[line.id] = ReceiveDraft(quantity: line.remaining, locationId: line.locationId, subLocationId: line.subLocationId)
            }
        }
        step = .receive
    }

    /// Build the receive inputs from the drafts (only lines with quantity > 0).
    /// Serial numbers are POSITIONAL (indexed per unit) — build exactly `quantity`
    /// slots, preserving index (blank interior slots stay `""`), and only send the
    /// array when at least one serial is non-empty. Never filter out interior blanks
    /// (that would shift later serials onto the wrong unit) and truncate stale entries
    /// left behind if the quantity was lowered after typing.
    func buildReceiveInputs() -> [ReceiveItemInput] {
        lines.compactMap { line in
            guard let d = drafts[line.id], d.quantity > 0 else { return nil }
            let positional = (0..<d.quantity).map { i -> String in
                i < d.serials.count ? d.serials[i].trimmingCharacters(in: .whitespaces) : ""
            }
            let hasAnySerial = positional.contains { !$0.isEmpty }
            return ReceiveItemInput(
                lineId: line.id, quantity: d.quantity,
                serialNumbers: hasAnySerial ? positional : nil,
                warrantyMonths: d.warrantyMonths, conditionGrade: d.conditionGrade,
                locationId: d.locationId, subLocationId: d.subLocationId)
        }
    }

    func receive() async {
        guard let id = order?.id else { return }
        let inputs = buildReceiveInputs()
        guard !inputs.isEmpty else { error = "Set a quantity to receive."; return }
        isBusy = true; error = nil; createdAssets = []
        defer { isBusy = false }
        do {
            for chunk in inputs.chunked(into: Self.receiveChunkSize) {
                let result = try await service.receiveItems(orderId: id, items: chunk)
                createdAssets.append(contentsOf: result.createdAssets)
                order = result.order
            }
            await reloadOrder()
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            step = .success
        } catch {
            self.error = error.localizedDescription
        }
    }

    var hasUnreceived: Bool { lines.contains { !$0.isFullyReceived } }
}

extension Array {
    /// Split into fixed-size chunks (for the receive batching).
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
