import XCTest
@testable import Repair_Minder

final class BookInTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase
        return try JSONSerialization.jsonObject(with: try e.encode(value)) as! [String: Any]
    }

    // MARK: - Decoding (real prod capture 2026-07-03 + verified handler shapes)

    func testSupplierOrderListRowDecodes() throws {
        let json = #"""
        {"id":"61200aeb","company_id":"4b63c1e6","order_number":"PO000013","supplier_name":"Headlane Limited",
         "supplier_order_reference":"INV/196819","status":"pending","order_date":"2026-01-26","expected_date":"2026-01-27",
         "received_date":null,"total_items":2,"total_received":0,"total_cost":32.6,"notes":null,
         "created_at":"2026-02-02T01:50:35.818Z","updated_at":"2026-02-02T01:50:35.880Z","invoice_file_key":null,"line_count":1}
        """#
        let o = try decode(SupplierOrder.self, json)
        XCTAssertEqual(o.orderNumber, "PO000013")
        XCTAssertEqual(o.totalItems, 2)
        XCTAssertEqual(o.totalCost, 32.6)       // Double
        XCTAssertEqual(o.lineCount, 1)
        XCTAssertEqual(o.remainingCount, 2)
        XCTAssertNil(o.lines)
    }

    func testSupplierOrderDetailWithLinesDecodes() throws {
        let json = #"""
        {"id":"o1","order_number":"PO1","supplier_name":"S","status":"partial","total_items":3,"total_received":1,"total_cost":30.0,
         "lines":[{"id":"l1","supplier_order_id":"o1","product_type_id":"pt1","name":"Screen","sku":"SCR-1","category":"Screens",
            "quantity_ordered":3,"quantity_received":1,"unit_cost":10.0,"line_total":30.0,"location_id":"loc1","sub_location_id":null,
            "product_type_name":"Screen PT","product_kind":"inventory_item"}]}
        """#
        let o = try decode(SupplierOrder.self, json)
        XCTAssertEqual(o.lines?.count, 1)
        let line = o.lines!.first!
        XCTAssertEqual(line.quantityOrdered, 3)
        XCTAssertEqual(line.quantityReceived, 1)
        XCTAssertEqual(line.unitCost ?? 0, 10.0)   // Double? decodes the present value
        XCTAssertEqual(line.remaining, 2)
        XCTAssertFalse(line.isFullyReceived)
        XCTAssertEqual(line.productTypeName, "Screen PT")
    }

    func testReceiveResultDecodes() throws {
        let json = #"""
        {"order":{"id":"o1","supplier_name":"S","status":"received","total_items":2,"total_received":2,"total_cost":20.0},
         "created_assets":[{"id":"a1","asset_tag":"AST1","name":"Screen","status":"in_stock"},
                           {"id":"a2","asset_tag":"AST2","name":"Screen","status":"in_stock"}],
         "assets_created_count":2}
        """#
        let r = try decode(ReceiveItemsResult.self, json)
        XCTAssertEqual(r.assetsCreatedCount, 2)
        XCTAssertEqual(r.createdAssets.count, 2)
        XCTAssertEqual(r.order.status, "received")
    }

    func testImportSuccessDecodes() throws {
        let json = #"{"success":true,"message":"Import completed successfully","data":{"imported":5,"created_product_types":2,"created_categories":1,"created_manufacturers":0}}"#
        let r = try decode(AssetImportResponse.self, json)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.data?.imported, 5)
        XCTAssertEqual(r.data?.createdProductTypes, 2)
    }

    func testImportValidationBodyDecodes() throws {
        // Real worker shape (asset_handlers.js validateImportRow): {row, field, message}.
        let json = #"""
        {"success":false,"error":"validation_failed","message":"CSV validation failed",
         "errors":[{"row":3,"field":"sku","message":"SKU is required"},{"row":5,"field":"status","message":"Invalid status"}],"totalErrors":2}
        """#
        let b = try decode(AssetImportValidationBody.self, json)
        XCTAssertEqual(b.error, "validation_failed")
        XCTAssertEqual(b.totalErrors, 2)
        XCTAssertEqual(b.errors?.count, 2)
        XCTAssertEqual(b.errors?.first?.display, "Row 3 (sku): SKU is required")
    }

    /// NTH: the worker's import validation rows carry `{row, field, message}` — never a
    /// bare `sku`/`error` pair. Confirm the model decodes the real contract.
    func testImportRowErrorDecodesFieldAndMessage() throws {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        let e = try d.decode(AssetImportRowError.self, from: #"{"row":3,"field":"sku","message":"required"}"#.data(using: .utf8)!)
        XCTAssertEqual(e.field, "sku")
        XCTAssertTrue(e.display.contains("Row 3"))
    }

    func testExtractInvoiceResponseDecodes() throws {
        let json = #"""
        {"success":true,"invoice_file_key":"invoices/x.pdf","file_type":"pdf",
         "data":{"supplier_name":"Acme","invoice_reference":"INV-9","invoice_date":"2026-07-01",
           "subtotal":20.0,"vat":4.0,"total":24.0,"confidence":0.9,"extraction_method":"claude",
           "line_items":[{"name":"Screen","sku":"SCR","quantity":2,"unit_cost":10.0,"category":"Screens",
              "mapping_found":true,"product_type_id":"pt1","mapped_product_name":"Screen PT"}]}}
        """#
        let r = try decode(ExtractInvoiceResponse.self, json)
        XCTAssertEqual(r.invoiceFileKey, "invoices/x.pdf")
        XCTAssertEqual(r.data.supplierName, "Acme")
        XCTAssertEqual(r.data.lineItems.count, 1)
        let line = r.data.lineItems.first!
        XCTAssertEqual(line.quantityValue, 2)
        XCTAssertEqual(line.mappingFound, true)
        XCTAssertEqual(line.productTypeId, "pt1")
    }

    // MARK: - Encoding

    func testCreateSupplierOrderRequestEncodes() throws {
        let req = CreateSupplierOrderRequest(supplierName: "Acme", supplierOrderReference: "INV-1",
                                             lines: [SupplierOrderLineRequest(name: "Screen", quantityOrdered: 3, unitCost: 10.0)])
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["supplier_name"] as? String, "Acme")
        XCTAssertEqual(dict["supplier_order_reference"] as? String, "INV-1")
        let lines = dict["lines"] as? [[String: Any]]
        XCTAssertEqual(lines?.first?["quantity_ordered"] as? Int, 3)
        XCTAssertNil(dict["notes"])   // nil omitted
    }

    /// The line editor's product-type link (NTH-8) round-trips through the same
    /// `SupplierOrderLineRequest` used by add/update-line — the worker's
    /// `handleUpdateOrderLine`/`handleAddOrderLine` already read `body.product_type_id`.
    func testSupplierOrderLineRequestEncodesProductTypeId() throws {
        let req = SupplierOrderLineRequest(productTypeId: "pt1", name: "Screen", quantityOrdered: 3, unitCost: 10.0)
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["product_type_id"] as? String, "pt1")
    }

    func testReceiveItemInputEncodesSerialsAndIntBooleans() throws {
        let req = ReceiveItemsRequest(items: [
            ReceiveItemInput(lineId: "l1", quantity: 2, serialNumbers: ["SN1", "SN2"],
                             warrantyMonths: 12, conditionGrade: "A", isOem: 1, isRefurbished: 0, locationId: "loc1")
        ])
        let dict = try encodeToDict(req)
        let item = (dict["items"] as? [[String: Any]])?.first
        XCTAssertEqual(item?["line_id"] as? String, "l1")
        XCTAssertEqual(item?["quantity"] as? Int, 2)
        XCTAssertEqual(item?["serial_numbers"] as? [String], ["SN1", "SN2"])
        XCTAssertEqual(item?["condition_grade"] as? String, "A")
        XCTAssertEqual(item?["is_oem"] as? Int, 1)
        XCTAssertEqual(item?["is_refurbished"] as? Int, 0)
    }

    func testCancelOrderEncodesStatus() throws {
        let dict = try encodeToDict(UpdateSupplierOrderRequest(status: "cancelled"))
        XCTAssertEqual(dict["status"] as? String, "cancelled")
        XCTAssertNil(dict["supplier_name"])
    }

    // MARK: - Wizard + list view models

    @MainActor
    final class BookInSpy: InventoryServingStub {
        var created: CreateSupplierOrderRequest?
        var receivedChunks: [[ReceiveItemInput]] = []
        var cancelledId: String?
        var deletedId: String?
        var lineCount = 2
        override func createSupplierOrder(_ body: CreateSupplierOrderRequest) async throws -> SupplierOrder {
            created = body
            return SupplierOrder(id: "o1", supplierName: body.supplierName, status: "pending")
        }
        override func getSupplierOrder(id: String) async throws -> SupplierOrder {
            var o = SupplierOrder(id: id, supplierName: "S", status: "pending")
            o.lines = (0..<lineCount).map { SupplierOrderLine(id: "l\($0)", name: "Line\($0)", quantityOrdered: 3, quantityReceived: 0, unitCost: 5) }
            return o
        }
        override func receiveItems(orderId: String, items: [ReceiveItemInput]) async throws -> ReceiveItemsResult {
            receivedChunks.append(items)
            let assets = items.map { Asset(id: $0.lineId, assetTag: "AST\($0.lineId)", name: "n", status: .inStock) }
            return ReceiveItemsResult(order: SupplierOrder(id: orderId, supplierName: "S", status: "received"), createdAssets: assets, assetsCreatedCount: assets.count)
        }
        override func updateSupplierOrder(id: String, body: UpdateSupplierOrderRequest) async throws -> SupplierOrder {
            if body.status == "cancelled" { cancelledId = id }
            return SupplierOrder(id: id, supplierName: "S", status: body.status ?? "pending")
        }
        override func deleteSupplierOrder(id: String) async throws {
            deletedId = id
        }
    }

    @MainActor
    func testSubmitOrderDetailsCreatesAndAdvances() async {
        let spy = BookInSpy()
        let vm = BookInWizardViewModel(service: spy)
        vm.supplierName = "Acme"; vm.reference = "INV-1"
        await vm.submitOrderDetails()
        XCTAssertEqual(spy.created?.supplierName, "Acme")
        XCTAssertEqual(vm.order?.id, "o1")
        XCTAssertEqual(vm.lines.count, 2)          // reloaded
        XCTAssertEqual(vm.step, .lineItems)
    }

    @MainActor
    func testApplyExtractionPrefillsAndStagesLines() {
        let vm = BookInWizardViewModel(service: BookInSpy())
        let resp = ExtractInvoiceResponse(success: true, data: ExtractedInvoice(
            supplierName: "Acme", invoiceReference: "INV-9", invoiceDate: "2026-07-01",
            lineItems: [ExtractedInvoiceLine(name: "Screen", quantity: 2, unitCost: 10)]), invoiceFileKey: nil, fileType: nil)
        vm.applyExtraction(resp)
        XCTAssertEqual(vm.supplierName, "Acme")
        XCTAssertEqual(vm.reference, "INV-9")
        XCTAssertEqual(vm.pendingLines.count, 1)
        XCTAssertEqual(vm.pendingLines.first?.quantityOrdered, 2)
    }

    @MainActor
    func testReceiveBuildsInputsAndChunks() async {
        let spy = BookInSpy(); spy.lineCount = 45   // > chunk size 20
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        XCTAssertEqual(vm.drafts.count, 45)
        await vm.receive()
        // 45 inputs -> chunks of 20 -> 3 receive calls (20,20,5)
        XCTAssertEqual(spy.receivedChunks.map(\.count), [20, 20, 5])
        XCTAssertEqual(vm.createdAssets.count, 45)
        XCTAssertEqual(vm.step, .success)
    }

    @MainActor
    func testReceiveSerialsArePositionalNotFiltered() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.drafts["l0"]?.quantity = 3
        // interior blank (unit 1 has no serial) + a stale 4th entry after quantity was lowered
        vm.drafts["l0"]?.serials = ["S0", "", "S2", "STALE"]
        let inputs = vm.buildReceiveInputs()
        // Exactly `quantity` positional slots; interior blank preserved; stale entry truncated.
        XCTAssertEqual(inputs.first?.serialNumbers, ["S0", "", "S2"])
    }

    @MainActor
    func testReceiveOmitsSerialsWhenAllBlank() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.drafts["l0"]?.quantity = 2   // no serials typed
        XCTAssertNil(vm.buildReceiveInputs().first?.serialNumbers)
    }

    @MainActor
    func testReceiveSkipsZeroQuantityLines() async {
        let spy = BookInSpy(); spy.lineCount = 2
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.drafts["l0"]?.quantity = 0
        let inputs = vm.buildReceiveInputs()
        XCTAssertEqual(inputs.count, 1)   // only l1
        XCTAssertEqual(inputs.first?.lineId, "l1")
    }

    // MARK: - NTH-8: receive step sub-location picker

    /// The receive step's sub-location picker writes into `ReceiveDraft.subLocationId`;
    /// confirm that value survives into the built `ReceiveItemInput` the worker's
    /// `POST /api/supplier-orders/:id/receive` reads `sub_location_id` from.
    @MainActor
    func testReceiveInputCarriesChosenSubLocation() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.drafts["l0"]?.subLocationId = "sub-42"
        let inputs = vm.buildReceiveInputs()
        XCTAssertEqual(inputs.first?.subLocationId, "sub-42")
    }

    // MARK: - MF-3: receive quantity must cap at `remaining`, not `quantityOrdered`

    func testReceiveLineRemaining() {
        let line = SupplierOrderLine(id: "l1", name: "Screen", quantityOrdered: 10, quantityReceived: 4)
        XCTAssertEqual(line.remaining, 6)
    }

    /// A draft can go stale relative to the current `remaining` (e.g. the order line's
    /// quantity/receipts changed underneath it while a receive draft already existed).
    /// Re-preparing the receive step must clamp any such draft down to the new `remaining`
    /// rather than leaving it able to over-receive.
    @MainActor
    func testPrepareReceiveClampsStaleDraftAboveRemaining() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        XCTAssertEqual(vm.drafts["l0"]?.quantity, 3)   // initial: full remaining (ordered 3, received 0)

        // Simulate the line's remaining shrinking (ordered 10, received 4 -> remaining 6)
        // while the existing draft is still stuck at a stale 99.
        vm.lines[0].quantityOrdered = 10
        vm.lines[0].quantityReceived = 4
        vm.drafts["l0"]?.quantity = 99

        vm.prepareReceive()
        XCTAssertEqual(vm.drafts["l0"]?.quantity, 6)
    }

    // MARK: - NTH-9: "Receive More" must reseed drafts + buildReceiveInputs must hard-clamp

    /// The success screen's "Receive More" button used to set `step = .receive` directly,
    /// bypassing `prepareReceive()` — so a stale draft quantity above the (possibly changed)
    /// `remaining` would sail straight through to `receive()`. `receiveMore()` must reseed
    /// drafts exactly like `prepareReceive()` does.
    @MainActor
    func testReceiveMoreReseedsDraftsToRemaining() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        XCTAssertEqual(vm.drafts["l0"]?.quantity, 3)   // initial: full remaining (ordered 3, received 0)

        // Simulate landing on the success screen after a partial receive, with the line's
        // remaining having shrunk while a stale draft quantity is left behind.
        vm.step = .success
        vm.lines[0].quantityOrdered = 10
        vm.lines[0].quantityReceived = 4   // remaining now 6
        vm.drafts["l0"]?.quantity = 99

        vm.receiveMore()

        XCTAssertEqual(vm.step, .receive)
        XCTAssertEqual(vm.drafts["l0"]?.quantity, 6)
    }

    /// Belt-and-suspenders: even if a draft's quantity is above `remaining` when
    /// `buildReceiveInputs()` runs (UI clamp bypassed, stale state, or any other path),
    /// the built input must never exceed `remaining` — and the positional serial slots
    /// must be capped to the same count (first `remaining` slots, index-aligned).
    @MainActor
    func testBuildReceiveInputsClampsQuantityToRemaining() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.lines[0].quantityReceived = 1   // remaining now 2 (ordered 3, received 1)
        vm.drafts["l0"]?.quantity = 8       // force above remaining, bypassing the Stepper bound
        vm.drafts["l0"]?.serials = ["S0", "S1", "S2", "S3", "S4", "S5", "S6", "S7"]

        let inputs = vm.buildReceiveInputs()

        XCTAssertEqual(inputs.first?.quantity, 2)
        XCTAssertEqual(inputs.first?.serialNumbers, ["S0", "S1"])
    }

    // MARK: - Receive per-line cost + OEM/refurb flags (parity with worker's item.unit_cost/is_oem/is_refurbished)

    /// `prepareReceive()` seeds each draft's `unitCost` from the line's own cost so the
    /// receive form starts pre-filled with a sensible value the user can override.
    @MainActor
    func testPrepareReceiveDefaultsUnitCostFromLine() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        XCTAssertEqual(vm.drafts["l0"]?.unitCost, 5)   // BookInSpy line unitCost
    }

    /// The receive step must actually carry unit cost + OEM/refurb overrides through to the
    /// built `ReceiveItemInput` — the worker's receive handler reads `item.unit_cost`,
    /// `item.is_oem`, and `item.is_refurbished` per line (supplier_order_handlers.js).
    @MainActor
    func testReceiveInputCarriesCostAndFlags() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.drafts["l0"]?.unitCost = 12.5
        vm.drafts["l0"]?.isOem = true
        vm.drafts["l0"]?.isRefurbished = false

        let inputs = vm.buildReceiveInputs()

        XCTAssertEqual(inputs.first?.unitCost, 12.5)
        XCTAssertEqual(inputs.first?.isOem, 1)
        XCTAssertEqual(inputs.first?.isRefurbished, 0)
    }

    /// Keep the MF-3 clamp + positional-serial invariant intact alongside the new fields —
    /// clamping quantity must not disturb the per-line cost/flag overrides.
    @MainActor
    func testReceiveInputCostFlagsSurviveQuantityClamp() async {
        let spy = BookInSpy(); spy.lineCount = 1
        let vm = BookInWizardViewModel(order: SupplierOrder(id: "o1", supplierName: "S", status: "pending"), service: spy)
        await vm.reloadOrder()
        vm.prepareReceive()
        vm.lines[0].quantityReceived = 1   // remaining now 2 (ordered 3, received 1)
        vm.drafts["l0"]?.quantity = 8       // force above remaining
        vm.drafts["l0"]?.serials = ["S0", "S1", "S2", "S3", "S4", "S5", "S6", "S7"]
        vm.drafts["l0"]?.unitCost = 7.25
        vm.drafts["l0"]?.isRefurbished = true

        let inputs = vm.buildReceiveInputs()

        XCTAssertEqual(inputs.first?.quantity, 2)
        XCTAssertEqual(inputs.first?.serialNumbers, ["S0", "S1"])
        XCTAssertEqual(inputs.first?.unitCost, 7.25)
        XCTAssertEqual(inputs.first?.isRefurbished, 1)
    }

    @MainActor
    func testSupplierListStatusFilterAndCancel() async {
        let spy = BookInSpy()
        let vm = SupplierOrderListViewModel(service: spy)
        // Order "1" has received items, so `cancel` must PATCH-cancel it (not hard-delete).
        vm.orders = [SupplierOrder(id: "1", supplierName: "A", status: "pending", totalReceived: 1),
                     SupplierOrder(id: "2", supplierName: "B", status: "received"),
                     SupplierOrder(id: "3", supplierName: "C", status: "cancelled")]
        XCTAssertEqual(vm.filtered.map(\.id), ["1"])       // default hides received/cancelled
        vm.toggleStatus("received")
        XCTAssertEqual(Set(vm.filtered.map(\.id)), ["1", "2"])
        await vm.cancel(vm.orders[0])
        XCTAssertEqual(spy.cancelledId, "1")
        XCTAssertNil(spy.deletedId)
    }

    // MARK: - Task 19: cancel deletes empty orders, matching web (worker's DELETE hard-deletes
    // only when `total_received == 0`; otherwise it just PATCHes to cancelled).

    @MainActor
    func testCancelDeletesEmptyOrder() async {
        let spy = BookInSpy()
        let vm = SupplierOrderListViewModel(service: spy)
        let order = SupplierOrder(id: "empty1", supplierName: "A", status: "pending", totalReceived: 0)
        let result = await vm.cancel(order)
        XCTAssertTrue(result)
        XCTAssertEqual(spy.deletedId, "empty1")
        XCTAssertNil(spy.cancelledId)
    }

    @MainActor
    func testCancelCancelsNonEmptyOrder() async {
        let spy = BookInSpy()
        let vm = SupplierOrderListViewModel(service: spy)
        let order = SupplierOrder(id: "partial1", supplierName: "A", status: "partial", totalReceived: 2)
        let result = await vm.cancel(order)
        XCTAssertTrue(result)
        XCTAssertEqual(spy.cancelledId, "partial1")
        XCTAssertNil(spy.deletedId)
    }

    /// A list row with no `total_received` in the payload (nil, not 0) must still be treated
    /// as empty and hard-deleted — mirrors the worker's `order.total_received > 0` check where
    /// SQLite's default is `0`, never NULL.
    @MainActor
    func testCancelTreatsNilTotalReceivedAsEmpty() async {
        let spy = BookInSpy()
        let vm = SupplierOrderListViewModel(service: spy)
        let order = SupplierOrder(id: "nilreceived1", supplierName: "A", status: "pending")
        let result = await vm.cancel(order)
        XCTAssertTrue(result)
        XCTAssertEqual(spy.deletedId, "nilreceived1")
        XCTAssertNil(spy.cancelledId)
    }
}
