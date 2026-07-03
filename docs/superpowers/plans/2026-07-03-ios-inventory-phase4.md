# iOS Inventory Phase 4 (Advanced) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. **Implementers run builds/tests in the FOREGROUND (`| tail`), never backgrounded (it stalls the loop), and commit per task. Reviewers are read-only (no builds).**

**Goal:** Recreate the entire remaining web Inventory surface in the iOS app at full parity — bulk multi-select actions, stock analytics, supplier book-in, and buyback salvage — with zero backend changes.

**Architecture:** Extend the Phase 1–3 module (`Features/Staff/Inventory/`, `Core/Models/Inventory*`, `InventoryServing`/`InventoryService`, `APIEndpoint`) following the established conventions (snake_case decode, Int-booleans as `Int?`+computed `Bool`, `request`/`requestVoid`/`requestFull`, `isEmbedded`, `.inventoryAssetDidChange`, pure testable gating helpers, shared `InventoryServingStub`). Sequenced 4a (bulk) → 4b (analytics) → 4c (book-in + CSV import + salvage).

**Tech Stack:** Swift 6 / SwiftUI, XCTest + XCUITest, `iPhone 17 Pro` simulator. Build:
```
xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -30
```
Test: swap `build` → `test -only-testing:"Repair MinderTests" -parallel-testing-enabled NO`.

**Spec:** `docs/superpowers/specs/2026-07-03-ios-inventory-phase4-design.md` — holds the verified backend contracts and the no-deferral checklist. Re-read it per task.

---

## File Structure

**Models (new, `Core/Models/`):**
- `InventoryBulkModels.swift` — bulk-return request/result, bulk-op outcome value type.
- `InventoryStockModels.swift` — stock-summary / hierarchy / low-stock decode models.
- `SupplierOrderModels.swift` — supplier order + lines + extracted-invoice + receive + import models.
- `SalvageModels.swift` — salvage request/response + summary + budget + delete result.

**Networking:**
- `Core/Networking/APIEndpoints.swift` (modify) — new cases (bulk, analytics, supplier-orders, import, salvage).
- `Core/Networking/APIClient.swift` (modify) — add a multipart helper if none exists (for extract-invoice + import).

**Service (modify):**
- `Features/Staff/Inventory/InventoryService.swift` — extend `InventoryServing` + `InventoryService`.
- `Repair MinderTests/InventoryServingStub.swift` — add stubs for every new method.

**4a Views (`Features/Staff/Inventory/Bulk/`):** `BulkActions.swift` (gating), `BulkActionBar.swift`, `BulkSelectionState.swift`, `BulkMoveSheet.swift`, `BulkDeploySheet.swift`, `BulkReturnToSupplierSheet.swift`, `BulkScanSheet.swift`, `BulkProgressView.swift`, `CSVExporter.swift`. Modify `InventoryListView.swift` + `InventoryListViewModel.swift`.

**4b Views (`Features/Staff/Inventory/Stock/`):** `InventoryStockView.swift`, `StockSummaryView.swift` + `StockViewModel.swift`, `AssetHierarchyView.swift`, `LowStockView.swift` + `LowStockBanner.swift`. Modify `InventoryListView.swift` (add `Stock` mode + banner).

**4c Views:** `Features/Staff/Inventory/BookIn/` (`SupplierOrderListView.swift` + VM, `BookInWizardView.swift` + `BookInWizardViewModel.swift`, `OrderDetailsStep.swift`, `LineItemsStep.swift`, `ReceiveItemsStep.swift`, `BookInSuccessStep.swift`, `InvoiceUploadView.swift`, `AssetImportSheet.swift`); `Features/Staff/Buyback/SalvageDeviceCard.swift` + `SalvageViewModel.swift` + `SalvageBudget.swift` (pure). Modify `BuybackDetailView.swift`.

**Tests (`Repair MinderTests/`):** extend existing inventory test files; add `InventoryBulkTests.swift`, `InventoryStockTests.swift`, `BookInTests.swift`, `SalvageTests.swift`. **UI test** `Repair MinderUITests/InventoryBulkUITest.swift`.

Captured real-JSON fixtures live inline in the decode tests (as Phase 3 did).

---

## Conventions every task follows (do not re-derive)
- Models: `Decodable, Identifiable (where it has a stable id), Equatable, Sendable`; camelCase, NO CodingKeys; Int-booleans `Int?` + computed `Bool`; true JSON booleans (`is_low_stock`, `is_child_service`) as `Bool`; costs `Double?`.
- Request structs `Encodable`, every optional `= nil`, field order = labeled call-site order.
- `APIError.httpError(statusCode:message:)` (non-2xx) vs `serverError(message:code:)` (200 success:false); NO `userMessage` → `error.localizedDescription`; map 400/409 by httpError statusCode/message text.
- `request<T>` for JSON POST/PUT/PATCH (response under `data`), `requestVoid` for DELETE, `requestFull<R>` ONLY for envelope siblings of `data`.
- `@MainActor` init trap: `init(api: APIClient? = nil)`.
- Sheets show their OWN inline error; post `.inventoryAssetDidChange` after any asset mutation; distinct `Identifiable` route wrappers; extract row subviews for `ForEach` + nested `if let`.
- Every new `InventoryServing` method gets a stub in `InventoryServingStub`.

---

## 4a — Bulk actions / multi-select

### Task 4a.1: Bulk models
**Files:** Create `Core/Models/InventoryBulkModels.swift`; Test `Repair MinderTests/InventoryBulkTests.swift`.
- [ ] **Failing tests:** (1) encode `BulkReturnToSupplierRequest(assetIds:["a1","a2"], supplierReturnReason:"defective", supplierReturnNotes:"n")` → assert JSON has `asset_ids`, `supplier_return_reason`, `supplier_return_notes`. (2) decode a REAL captured `bulk-return-to-supplier` body into `BulkReturnToSupplierResult` → assert `batches[0].supplierName`, `.count`, `.assets[0].assetTag`, `totalReturned`, `errors`. (Capture the JSON live in the E2E task; until then use the spec's documented shape, then replace with the real capture.)
- [ ] **Implement:** structs per spec §4a. `BulkReturnToSupplierResult{success? , batches:[SupplierReturnBatch], totalReturned:Int, errors:[BulkAssetError]}` decoded from `data`; `SupplierReturnBatch: Identifiable` (use `supplierName ?? UUID` — actually use `id = supplierName ?? ""`); `BulkAssetError{assetId, error}`. Also a client-only `BulkOperationOutcome` value type: `{assetId:String, assetTag:String, success:Bool, message:String?}` for per-item loop progress.
- [ ] Build+test foreground; commit `feat(inventory): Phase 4a bulk models`.

### Task 4a.2: Endpoints — bulk return
**Files:** Modify `Core/Networking/APIEndpoints.swift`.
- [ ] Grep for the enum + `path`/`method`/`queryItems` switches (don't trust line numbers). Add `case bulkReturnToSupplier` → path `/api/assets/bulk-return-to-supplier`, method POST, `requiresAuth` true. (Bulk move/deploy reuse existing `.moveAsset`/`.allocateAsset`/`.deployExternalAsset`.)
- [ ] Build foreground; commit `feat(inventory): bulk-return endpoint`.

### Task 4a.3: Service — bulk return + reuse loops
**Files:** Modify `InventoryService.swift`; `Repair MinderTests/InventoryServingStub.swift`.
- [ ] **Failing test:** VM/service test — mock returns a `BulkReturnToSupplierResult`; assert `bulkReturnToSupplier(assetIds:reason:notes:)` calls `.bulkReturnToSupplier` and returns it.
- [ ] **Implement:** `func bulkReturnToSupplier(assetIds:[String], reason:String, notes:String?) async throws -> BulkReturnToSupplierResult { try await api.request(.bulkReturnToSupplier, body: BulkReturnToSupplierRequest(assetIds:assetIds, supplierReturnReason:reason, supplierReturnNotes:notes)) }`. Add protocol requirement + stub. (Move/deploy loops live in the VMs, calling existing service methods.)
- [ ] Build+test; commit `feat(inventory): bulk-return service method`.

### Task 4a.4: `BulkActions` gating helper (pure)
**Files:** Create `Features/Staff/Inventory/Bulk/BulkActions.swift`; Test in `InventoryBulkTests.swift`.
- [ ] **Failing tests:** `deployableCount(_ assets)` = count of `.status == .inStock`; `returnableAssets(_ assets)` = assets with `status ∈ {inStock,allocated,deployed}` AND non-empty `supplierName`; `invalidReturnCount`; group-by-supplier helper.
- [ ] **Implement** the pure static funcs mirroring web `BulkSupplierReturnModal` validity + `BulkDeployModal` in-stock filter.
- [ ] Build+test; commit `feat(inventory): BulkActions gating`.

### Task 4a.5: Selection state + edit-mode + bulk bar
**Files:** Create `Bulk/BulkSelectionState.swift`, `Bulk/BulkActionBar.swift`; Modify `InventoryListView.swift`, `InventoryListViewModel.swift`.
- [ ] **Failing test:** `BulkSelectionState` (an `ObservableObject` or a `@State struct`): toggle(id) adds/removes; selectAll(ids) selects the current page; clear() empties; `isEditing` flag. Test toggle/selectAll/clear transitions.
- [ ] **Implement:** selection state; `InventoryListView` gains a "Select" toolbar button (Assets mode only) → sets `isEditing`; rows show a leading selection circle when editing (tap toggles instead of navigating); Select-All + Clear toolbar items; `BulkActionBar` floating at the bottom when `selection.count > 0` showing count + buttons (Move / Deploy / Return / Export / Scan). Buttons enabled per `BulkActions`. `.accessibilityIdentifier` on the Select button + bulk-action buttons (leaf controls only).
- [ ] Build foreground; commit `feat(inventory): multi-select edit mode + bulk bar`.

### Task 4a.6: `BulkReturnToSupplierSheet`
**Files:** Create `Bulk/BulkReturnToSupplierSheet.swift`; Test VM behaviour in `InventoryBulkTests.swift`.
- [ ] **Failing test:** a `BulkReturnViewModel` with a mock service — given selected assets (some invalid), exposes `validAssets` grouped by supplier + `invalidCount`; `submit()` calls `bulkReturnToSupplier` with valid ids + reason; surfaces `result.totalReturned`/`errors`; disables submit when no valid assets or no reason.
- [ ] **Implement:** sheet with reason `Picker` (enum: defective/wrong_part/damaged_in_transit/quality_issue/warranty_claim/order_error/other), notes field, per-supplier collapsible groups, invalid-count amber note, inline error, post `.inventoryAssetDidChange` on success. VM extracted for testability.
- [ ] Build+test; commit `feat(inventory): bulk return-to-supplier sheet`.

### Task 4a.7: `BulkMoveSheet` (per-item loop + progress)
**Files:** Create `Bulk/BulkMoveSheet.swift`, `Bulk/BulkProgressView.swift`; Test in `InventoryBulkTests.swift`.
- [ ] **Failing test:** `BulkMoveViewModel.run(locationId:subLocationId:)` loops `moveAsset` per selected id against a mock that fails one id; assert outcomes list has correct success/failure per asset and continues past the failure.
- [ ] **Implement:** location + sub-location pickers (reuse `AssetMoveSheet` picker code/pattern — DO NOT clear a seeded sub-location: default sub-location to nil only when the user changes location; guard against the Phase-2 data-loss bug). `BulkProgressView` shows per-asset progress + a failure list. Post `.inventoryAssetDidChange`.
- [ ] Build+test; commit `feat(inventory): bulk move sheet + progress`.

### Task 4a.8: `BulkDeploySheet` (in-stock subset; order/external loop)
**Files:** Create `Bulk/BulkDeploySheet.swift`; Test in `InventoryBulkTests.swift`.
- [ ] **Failing test:** `BulkDeployViewModel` — order path loops `allocateAsset(body: AllocateRequest(orderId:orderItemId:deploy:false))` per in-stock id; external path loops `deployExternal`; both track per-asset outcomes; only in-stock assets are included.
- [ ] **Implement:** choice screen (Order / External); reuse Phase-2 order search + line-item picker components and the external form; run the loop with progress. Post `.inventoryAssetDidChange`.
- [ ] Build+test; commit `feat(inventory): bulk deploy sheet`.

### Task 4a.9: CSV export (share sheet)
**Files:** Create `Bulk/CSVExporter.swift`; Test in `InventoryBulkTests.swift`.
- [ ] **Failing test:** `CSVExporter.csvString(for: [Asset])` produces a header row `Asset Tag,Name,Status,Category,Location,Sub-Location,Serial Number,SKU,Condition,Cost` + one row per asset with proper quoting/escaping of commas/quotes.
- [ ] **Implement:** pure `csvString` + a `writeTempFile(_:) -> URL`; the bulk bar "Export" action writes the temp `.csv` and presents `UIActivityViewController` (`#if os(iOS)`; Mac uses a save panel or is guarded out).
- [ ] Build+test; commit `feat(inventory): CSV export via share sheet`.

### Task 4a.10: `BulkScanSheet` (camera accumulator)
**Files:** Create `Bulk/BulkScanSheet.swift`; Test VM in `InventoryBulkTests.swift`.
- [ ] **Failing test:** `BulkScanViewModel.onScan(tag:)` resolves via mock `fetchAssetByTag`; adds only `status == .inStock` (others → error entry); dedups already-scanned; remove/clear work.
- [ ] **Implement:** reuse `InventoryScannerSheet` camera; accumulate entries; "Deploy"/"Move" buttons (enabled when readyCount>0) open the existing bulk Deploy/Move sheets with the accumulated in-stock assets. `#if os(iOS)` for camera.
- [ ] Build+test; commit `feat(inventory): bulk camera-scan accumulator`.

**4a checkpoint:** full iOS build green; run the inventory test target; commit any fixups.

---

## 4b — Stock analytics

### Task 4b.1: Stock models + decode tests
**Files:** Create `Core/Models/InventoryStockModels.swift`; Test `Repair MinderTests/InventoryStockTests.swift`.
- [ ] **Failing tests (decode vs REAL captured JSON):** `[StockSummaryItem]` from a real `/stock-summary` body — assert array root, `aggregateInStock`, `isLowStock` is a Bool, recursive `children[0].reorderLevel`. `AssetHierarchyResponse` from real `/hierarchy` — `grouped[0].productType.name`, `.assets[0].assetTag`, `children` optional, `unlinked`. `LowStockResponse` from real `/low-stock` — `all[0].deficit`, `isChildService` Bool, `alerts.parts`, `summary.byCategory.parts`. Capture with an admin token before finalizing (see spec Verification); until captured, use the spec shape then replace.
- [ ] **Implement** the models per spec §4b. `StockSummaryItem: Identifiable {id = productTypeId}`; `children:[StockSummaryItem]?`. `HierarchyAsset: Identifiable`. `LowStockAlert: Identifiable {id = productTypeId}`.
- [ ] Build+test; commit `feat(inventory): Phase 4b stock analytics models`.

### Task 4b.2: Endpoints + service (read-only)
**Files:** Modify `APIEndpoints.swift`, `InventoryService.swift`, `InventoryServingStub.swift`.
- [ ] **Failing test:** service methods return the mocked models.
- [ ] **Implement:** endpoints `stockSummary` GET `/api/assets/stock-summary`, `assetHierarchy(status:)` GET `/api/assets/hierarchy` (status queryItem), `lowStock` GET `/api/assets/low-stock`. Service: `fetchStockSummary() -> [StockSummaryItem]` (data is an array → `request<[StockSummaryItem]>`), `fetchHierarchy(status:String?) -> AssetHierarchyResponse`, `fetchLowStock() -> LowStockResponse`. Protocol + stubs.
- [ ] Build+test; commit `feat(inventory): stock analytics endpoints + service`.

### Task 4b.3: `Stock` segment + `InventoryStockView` container
**Files:** Create `Stock/InventoryStockView.swift`; Modify `InventoryListView.swift` (`InventoryMode` gains `.stock`).
- [ ] **Implement:** add `case stock = "Stock"` to `InventoryMode`; in `content`, when `.stock` render `InventoryStockView` (embedded); a sub-tab `Picker` (Summary / Hierarchy / Low Stock). Search bar hidden or repurposed in Stock mode.
- [ ] Build foreground; commit `feat(inventory): Stock segment + analytics container`.

### Task 4b.4: `StockSummaryView`
**Files:** Create `Stock/StockSummaryView.swift`, `Stock/StockViewModel.swift`; Test VM in `InventoryStockTests.swift`.
- [ ] **Failing test:** `StockViewModel.sorted(by:.inStock, ascending:false)` orders items; `toggleExpand(id)` tracks expansion; load populates items.
- [ ] **Implement:** table-like list (name + mono sku, in-stock/allocated/total/reorder, status glyph red when `inStockCount==0 && reorderLevel>0` else orange when `isLowStock`), sortable headers (name/in_stock/allocated/total/reorder × asc/desc), expandable `children` rows (indented), row tap → set the Assets product-type filter + switch to `.assets` mode. Loading/error(retry)/empty.
- [ ] Build+test; commit `feat(inventory): stock summary view`.

### Task 4b.5: `AssetHierarchyView`
**Files:** Create `Stock/AssetHierarchyView.swift` (+ small VM or inline).
- [ ] **Failing test (VM):** expand-all/collapse-all toggles; `countTotalAssets(group)` sums recursively.
- [ ] **Implement:** group nodes (product-type name, variant badge = children.count, mono sku, category, recursive asset count), expandable; asset leaf rows (tag, name, S/N, status badge) → navigate to asset detail; expand-all/collapse-all; unlinked panel toggle. Optional `status` filter control.
- [ ] Build+test; commit `feat(inventory): asset hierarchy view`.

### Task 4b.6: `LowStockView` + `LowStockBanner`
**Files:** Create `Stock/LowStockView.swift`, `Stock/LowStockBanner.swift`; Modify `InventoryListView.swift`.
- [ ] **Failing test (VM):** load populates `all`; severity = critical when `inStockCount==0` else low; refresh re-fetches.
- [ ] **Implement:** `LowStockView` (full list from `all`: name + parent_name in parens when `isChildService`, mono sku, "N in stock (min: R)", "Need D more", severity colour). `LowStockBanner` — collapsible banner above the Assets list (all modes except when it's empty), badge count, refresh, per-row View → filter Assets. Auto-hide when no alerts.
- [ ] Build+test; commit `feat(inventory): low-stock view + banner`.

**4b checkpoint:** full iOS build green; run inventory tests.

---

## 4c — Book-in + CSV import + Salvage

> Contracts verified against `worker/supplier_order_handlers.js`, `supplier_mapping_handlers.js`, `invoice_extraction_handlers.js`, `buyback_salvage_handlers.js`. **Envelope quirks:** supplier-orders list uses `meta`; supplier-mappings list uses `pagination`; delete-line returns `{success,message}` (no `data`); extract-invoice input errors are bare `{error,...}` (NO `success:false`); create/add-line responses return the bare row (no `lines`/joins). Money = `Double`, counts = `Int`.

### Salvage (independent of book-in — can build first within 4c)

#### Task 4c.1: Salvage models + decode tests
**Files:** Create `Core/Models/SalvageModels.swift`; Test `Repair MinderTests/SalvageTests.swift`.
- [ ] **Failing tests:** encode `SalvageItemRequest(productTypeId:"g1", conditionGrade:"A", locationId:"l1", value:5.0)` → assert `product_type_id`, `condition_grade`, `location_id`, `value`, and screen fields OMITTED when nil. Decode a REAL `POST /api/buyback/:id/salvage` 201 body into `SalvageResponse` → assert `assets[0].sourceType == "salvaged"`, `salvagedAssets[0].lcdWorking` (Int?), `salvageBudget.remaining`. Decode `DeleteSalvageResult` (`revertedTo` optional). Decode the cap-exceeded 400 shape into a small `SalvageBudgetError{ok:Bool?, cap,booked,incoming,remaining:Double?}`.
- [ ] **Implement** per spec §4c. `SalvagedAssetSummary: Identifiable`; `SalvageBudgetInfo{cap,booked,remaining:Double?}`.
- [ ] Build+test; commit `feat(inventory): salvage models`.

#### Task 4c.2: `SalvageBudget` pure helper
**Files:** Create `Features/Staff/Buyback/SalvageBudget.swift`; Test in `SalvageTests.swift`.
- [ ] **Failing tests:** `SalvageBudget.remaining(cap:booked:pending:)`; `overCap(cap:booked:pending:)` = `round2(booked+pending) > round2(cap)`; `canAdd(group:locationId:lcd:glass:)` requires group+location, and (when category contains "screen") lcd/glass non-nil; `isScreen(category:)`.
- [ ] **Implement** the pure static funcs (mirror web `computeSalvageBudget` + `canAdd`). round2 = `(x*100).rounded()/100`.
- [ ] Build+test; commit `feat(buyback): salvage budget helper`.

#### Task 4c.3: Salvage endpoints + service
**Files:** Modify `APIEndpoints.swift`, `InventoryService.swift`, `InventoryServingStub.swift`.
- [ ] **Failing test:** service returns mocked `SalvageResponse` / `DeleteSalvageResult`.
- [ ] **Implement:** endpoints `salvageBuyback(id:)` POST `/api/buyback/{id}/salvage`, `deleteSalvageItem(buybackId:,assetId:)` DELETE `/api/buyback/{buybackId}/salvage/{assetId}`. Service `salvageBuyback(id:, items:[SalvageItemRequest]) -> SalvageResponse` (`request`, nested `data`), `deleteSalvageItem(buybackId:,assetId:) -> DeleteSalvageResult`. Map cap-exceeded: catch `APIError.httpError(400, msg)` where msg contains "exceed" → a friendly over-budget error. Protocol + stub.
- [ ] Build+test; commit `feat(buyback): salvage service`.

#### Task 4c.4: `SalvageDeviceCard` + VM
**Files:** Create `Features/Staff/Buyback/SalvageDeviceCard.swift`, `SalvageViewModel.swift`; Modify `BuybackDetailView.swift`; Test VM in `SalvageTests.swift`.
- [ ] **Failing test:** `SalvageViewModel` — `addToBatch` gated by `SalvageBudget.canAdd`; `book()` calls `salvageBuyback` with staged items, blocks when `overCap`, requires confirm when `salvagedAssets.isEmpty`; `removeSalvaged(assetId)` calls delete; screen-category staging requires lcd/glass.
- [ ] **Implement:** card section on `BuybackDetailView` — budget header (remaining/cap), staging form (inventory-group picker via `fetchGroups`/`listGroups`, grade A/B/C segmented, value, screen LCD/glass Yes-No when category contains "screen", location picker via `fetchLocations`/`fetchSubLocations`, notes), staged batch list w/ remove, Book button (confirm-on-first via alert), booked list w/ per-asset remove. Inline error; refresh buyback via the buyback VM's `onChanged` callback. Reuse the location/group pickers.
- [ ] Build foreground; commit `feat(buyback): salvage device card`.

### Book-in

#### Task 4c.5: Supplier-order + import models + decode tests
**Files:** Create `Core/Models/SupplierOrderModels.swift`; Test `Repair MinderTests/BookInTests.swift`.
- [ ] **Failing tests:** decode REAL `GET /api/supplier-orders` list row (`SupplierOrder` + `lineCount`, `totalCost` Double, `totalItems` Int), REAL `GET /api/supplier-orders/:id` (order + `lines:[SupplierOrderLine]` with `productTypeName`/`productKind` joins + `unitCost`/`lineTotal` Double), REAL `receive` result (`ReceiveItemsResult`), REAL `import` success (`{message (sibling), data:{imported,...}}`) + the `validation_failed` 400 (`AssetImportValidationError`), and an `ExtractedInvoice` (all fields except `lineItems` optional; `lineItems[]` enrichment fields optional). Encode `CreateSupplierOrderRequest`, `SupplierOrderLineRequest`, `ReceiveItemsRequest`/`ReceiveItemInput` (serial_numbers array; is_oem/is_refurbished Int).
- [ ] **Implement** per the verified contracts. `SupplierOrder: Identifiable`; `SupplierOrderLine: Identifiable`; `ExtractedInvoiceLine` enrichment optional; `AssetImportResult{success?,message?,data:AssetImportCounts}` via `requestFull` (message is a sibling of data); `AssetImportValidationError`.
- [ ] Build+test; commit `feat(inventory): book-in + import models`.

#### Task 4c.6: Supplier-order endpoints + multipart client
**Files:** Modify `APIEndpoints.swift`, `APIClient.swift`, `InventoryService.swift`, `InventoryServingStub.swift`.
- [ ] Confirm `APIClient` has no multipart method (grep `multipart`/`boundary`); if absent, add `func requestMultipart<R:Decodable>(_ endpoint:, fields:[String:String], fileField:String, fileName:String, mimeType:String, fileData:Data) async throws -> R` that builds `multipart/form-data`, attaches the auth header, and decodes.
- [ ] Add endpoints: `supplierOrders(page:limit:supplier:status:)`, `supplierOrder(id:)`, `createSupplierOrder`, `updateSupplierOrder(id:)` PATCH, `supplierOrderLines(id:)` POST, `updateSupplierOrderLine(orderId:lineId:)` PUT, `deleteSupplierOrderLine(orderId:lineId:)` DELETE, `receiveSupplierOrder(id:)` POST, `extractInvoice`, `importAssets`, `supplierMappingsBulkLookup`, `supplierMappingsSuppliers` GET `/api/supplier-mappings/suppliers`.
- [ ] Service methods: `listSupplierOrders(...)`, `getSupplierOrder(id:)`, `createSupplierOrder(_:)`, `updateSupplierOrder(id:,fields:)`, `addOrderLine(orderId:,_:)`, `updateOrderLine(orderId:lineId:,_:)`, `deleteOrderLine(orderId:lineId:)`, `receiveItems(orderId:,items:)`, `extractInvoice(fileData:fileName:mime:)`, `importAssets(csvData:createMissing:)` (multipart), `listSuppliers()`. Note delete-line returns `{success,message}` → a small decode or `requestVoid`. Protocol + stubs.
- [ ] Build+test; commit `feat(inventory): supplier-order + import endpoints + multipart client`.

#### Task 4c.7: `SupplierOrderListView` + VM
**Files:** Create `Features/Staff/Inventory/BookIn/SupplierOrderListView.swift` + `SupplierOrderListViewModel.swift`; Modify `InventoryListView.swift` (add "Book In" toolbar entry).
- [ ] **Failing test (VM):** load populates orders; status filter (client-side; default excludes received/cancelled) filters; cancel calls `updateSupplierOrder(status:"cancelled")`.
- [ ] **Implement:** a "Book In" toolbar item on the Inventory list opens `SupplierOrderListView` (pushed). Search (debounced → `supplier` param), status filter popover, rows (order#/ref, supplier, status badge, received/total, total cost, dates), New Order button, Edit, Cancel (confirm → PATCH). Paging via `meta`.
- [ ] Build foreground; commit `feat(inventory): supplier order list`.

#### Task 4c.8: Book-in wizard — Order Details + Invoice upload
**Files:** Create `BookIn/BookInWizardView.swift` + `BookInWizardViewModel.swift`, `BookIn/OrderDetailsStep.swift`, `BookIn/InvoiceUploadView.swift`; Test VM in `BookInTests.swift`.
- [ ] **Failing test (VM):** `submitOrderDetails` calls `createSupplierOrder` (new) or advances (existing); `applyExtraction(_:)` prefills supplier/reference/date + maps line items; stock-in-hand toggle sets the receive-after-lines path.
- [ ] **Implement:** wizard container (step enum: orderDetails/lineItems/receive/success); `OrderDetailsStep` (supplier name + suggestions from `listSuppliers`, reference, order/expected dates, stock-in-hand toggle, notes); `InvoiceUploadView` (`#if os(iOS)` `UIDocumentPicker`/`fileImporter` for PDF/image → `extractInvoice` → prefill; PDFKit preview via `PDFKit`). Disable order fields once the order exists.
- [ ] Build foreground; commit `feat(inventory): book-in order details + invoice upload`.

#### Task 4c.9: Book-in wizard — Line Items
**Files:** Create `BookIn/LineItemsStep.swift`; Test VM in `BookInTests.swift`.
- [ ] **Failing test (VM):** add/update/delete line calls the right service methods; update-line blocked (surfaced) when `quantityReceived>0`; reload after each via `getSupplierOrder`.
- [ ] **Implement:** line list (name, sku, qty, unit cost, category, location); Add Line form; per-line edit (guarded when received>0) + delete; product-type/group search via `fetchProductTypes`/`listGroups`. Submit → advance (or "Receive All" when stock-in-hand).
- [ ] Build foreground; commit `feat(inventory): book-in line items`.

#### Task 4c.10: Book-in wizard — Receive + Success
**Files:** Create `BookIn/ReceiveItemsStep.swift`, `BookIn/BookInSuccessStep.swift`; Test VM in `BookInTests.swift`.
- [ ] **Failing test (VM):** `receive()` builds `ReceiveItemInput` per line (quantity default = ordered−received; serial_numbers array sized to quantity; condition default 'A'; warranty default 12), chunks at 20, calls `receiveItems`, aggregates `created_assets`; post `.inventoryAssetDidChange`.
- [ ] **Implement:** per-line receive controls (qty, condition grade A–F, warranty months, per-unit serial inputs, location/sub-location), group-assign for unmapped lines (reuse `GroupSelectorSheet`/`bulkAssignGroups`), submit → `receive` (chunk 20); Success step (created assets list, Receive More / Done). No label print (excluded).
- [ ] Build foreground; commit `feat(inventory): book-in receive + success`.

#### Task 4c.11: CSV import sheet (admin-gated)
**Files:** Create `BookIn/AssetImportSheet.swift`; Test VM/gate in `BookInTests.swift`.
- [ ] **Failing test:** admin-gate helper hides import for non-admin roles; VM `import(fileData:)` calls `importAssets`, surfaces `imported`/`created_*` on success and the `validation_failed` `errors[]`/`totalErrors` on 400.
- [ ] **Implement:** an "Import CSV" entry (admin-only) near the Book-In list — `fileImporter`/`UIDocumentPicker` for `.commaSeparatedText` → `importAssets(csvData:createMissing:)`; show result summary or the validation-error report. Role from the current session (grep how the app exposes the user's role).
- [ ] Build foreground; commit `feat(inventory): CSV import sheet`.

**4c checkpoint:** full iOS build green; run all inventory tests.

---

## Verification tasks (first-class — not optional)

### Task V.1: Capture real JSON + backfill decode fixtures
Mint an admin token (`repairminder/.claude/rules/api-tokens.md`; admin company `4b63c1e6ade1885e73171e10221cac53`; `User-Agent: curl/8.4.0`). Capture live `/stock-summary`, `/hierarchy`, `/low-stock`, a `bulk-return-to-supplier` (throwaway assets), supplier-order list/detail/receive, a salvage 201, and an import result. Replace any placeholder fixtures in the decode tests with the REAL captures; re-run tests green.

### Task V.2: Live prod E2E of EVERY write (with D1 hard-delete cleanup)
For each write: perform via curl with the admin token → assert the live response decodes into the Swift model (compare field-by-field) → hard-delete via D1. Writes: bulk-return, bulk-move (loop), bulk-deploy (allocate by order id only), supplier-order create+line+receive, CSV import, salvage + delete-salvage. `ZZ-P4-` prefix; verify by `created_at`/prefix; never delete a row you didn't create. Clean up `assets`, `supplier_orders`+`supplier_order_lines`, `asset_group_memberships`, `supplier_*_mappings`, `product_types` created, and revert any buyback flipped to `salvaged`. Confirm 0 `ZZ-P4-` artifacts in admin AND demo companies.

### Task V.3: XCUITest — a Phase-4 write flow
`Repair MinderUITests/InventoryBulkUITest.swift`: seed a demo in-stock asset (D1/API), login (demo, code 123456), Assets → Select → tap the seeded asset → Bulk Return to Supplier → reason → submit → assert back on list. Prime the FAB overlay; tap by asset-tag static text; `.accessibilityIdentifier` on leaf controls. Delete the seed. `XCTSkip` when empty. Run green (`-parallel-testing-enabled NO`).

### Task V.4: Final full-branch review + release bump
Read-only reviewer over the whole branch (correctness, dead plumbing, wrong error-case mapping, data-loss). Fix findings. Bump `CURRENT_PROJECT_VERSION` 007 → 008. Full iOS build green; confirm new files add zero Mac-scheme errors (grep the error output for new file paths).

---

## Self-review notes
- **Spec coverage:** every no-deferral-checklist row maps to a task (4a bulk sheets + scan + export; 4b three analytics views + banner; 4c book-in wizard + import + salvage). Label printing intentionally excluded; bulk-create/next-tag/stats intentionally skipped (no web UI).
- **Type consistency:** service method names match between the service task and the view tasks; request/response model names match the spec. Money is `Double?`, counts `Int`, Int-booleans `Int?`.
- **Multipart:** `extractInvoice`/`importAssets` need the new `requestMultipart` (Task 4c.6) — not the JSON path.
