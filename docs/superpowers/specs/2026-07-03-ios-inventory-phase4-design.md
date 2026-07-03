# iOS Inventory — Phase 4: Advanced (Bulk · Analytics · Book-in · Salvage) — Design Spec

**Date:** 2026-07-03
**Branch:** `feat/ios-inventory-phase4` (off `main`, after Phase 3 merge `7773e99`, `CURRENT_PROJECT_VERSION` 007)
**Roadmap:** `docs/superpowers/specs/2026-07-03-ios-inventory-ROADMAP.md` → "Phase 4 — Advanced"
**Worker prompt:** `docs/superpowers/PHASE4-WORKER-PROMPT.md`
**Predecessors:** Phase 1 (browse), Phase 2 (per-asset writes), Phase 3 (Inventory Groups)

Phase 4 is the **widest and FINAL** phase. It recreates the entire remaining web Inventory surface: bulk multi-select actions, stock analytics (summary/hierarchy/low-stock), supplier book-in, and buyback salvage. There is no Phase 5.

## Two standing mandates (adopted after Phase 2)

1. **NOTHING DEFERRED.** Deliver the entire remaining web Inventory surface at full parity. Scope questions were HOW, never WHETHER. The only acceptable exclusion is a capability iOS physically cannot do; the single such exclusion (bulk label printing — a desktop popup-print flow) is called out and **user-confirmed** below. Internal sequencing into 4a/4b/4c is fine; nothing is punted to a later phase (there is none).
2. **EVERYTHING TESTED.** Before merge: unit tests (request encoding + response decoding vs **real captured JSON** + view-model mutations + gating); a **live prod E2E of every write** (perform → assert real response decodes into the Swift model → hard-delete cleanup via D1, since API delete is soft); and at least one **XCUITest** driving a new Phase-4 write flow. See Verification.

**Backend changes expected: ZERO.** All endpoints already exist and are consumed by the web app. Every write/read shape must be re-verified against the handler before coding (`.claude/rules/cross-project-sync.md`).

---

## Locked decisions (from brainstorming)

| Decision | Choice |
|---|---|
| Multi-select entry + bulk toolbar | **Edit-mode + floating bottom bulk bar.** A "Select" toolbar button enters edit-mode (Assets mode only); rows show a selection circle; Select-All + Clear toolbar items; a floating bottom bar shows the count + bulk actions. No shift-range (iOS has no shift key). |
| Analytics placement | **New `Stock` segment** beside `Assets`/`Groups` → a screen with sub-tabs **Summary / Hierarchy / Low Stock**. Low-stock ALSO renders as a collapsible banner above the Assets list (mirrors web, which shows it in every mode except Groups). |
| Book-in entry + scope | **Full 4-step wizard**, entry from the **Inventory toolbar**. Supplier-order list → Order Details → Line Items → Receive → Success. |
| Salvage surface | **`SalvageDeviceCard` section on `BuybackDetailView`** (which already reads the salvage budget). |
| CSV export | **Included** — build the CSV client-side, write a temp `.csv`, present the iOS share sheet. |
| Bulk-scan accumulator | **Included, camera-based** — reuse `InventoryScannerSheet`; accumulate in-stock tags → the same bulk Deploy/Move sheets. (Web uses a hardware keyboard-wedge; iOS uses the camera.) |
| CSV import | **Included** via `UIDocumentPicker` → multipart `POST /api/assets/import` (admin-gated), surfacing the validation-error report. |
| Invoice AI extraction (book-in) | **Included** via document picker + PDFKit → `POST /api/supplier-orders/extract-invoice` prefill. |
| Bulk label printing | **EXCLUDED (user-confirmed).** The web mechanism is a desktop browser popup + `window.print()` of a QR-label grid; consistent with the Phase-2 Dymo-label exclusion. |
| `POST /api/assets/bulk`, `GET /api/assets/next-tag`, `GET /api/assets/stats` | **SKIPPED — no web UI exists** (confirmed unused in `src/`). Not a deferred web feature; building them would be net-new iOS, not parity. Analytics parity comes from stock-summary/hierarchy/low-stock, which ARE rendered on web. |
| Salvage service location | Salvage methods live in **`InventoryService`** (APIClient-based; needs inventory-group + location lookups), called from the buyback detail VM — not the hand-rolled Buyback URLSession. |

---

## Backend contracts (verified against handlers — re-verify each against REAL JSON before trusting the model)

All fields **snake_case** on the wire; iOS decoder is `.convertFromSnakeCase` (no explicit CodingKeys). **Int-booleans** (`is_oem`, `is_refurbished`, `lcd_working`, `glass_cracked`) arrive as `Int` (0/1/null) → `Int?` + computed `Bool`. **True JSON booleans** (`is_low_stock`, `is_child_service`) → `Bool`. Costs/`total_value`/`SUM(...)` are nullable `REAL` → `Double?`. Handlers: `worker/asset_handlers.js`, `worker/supplier_order_handlers.js`, `worker/buyback_salvage_handlers.js`; router in `worker/index.js`.

### 4a — Bulk

**`POST /api/assets/:id/move`** (reuse Phase-2) — looped per asset for bulk move. `{location_id?, sub_location_id?}` → `{success, data: Asset}`.
**`POST /api/assets/:id/allocate`** / **`/deploy-external`** (reuse Phase-2) — looped per asset for bulk deploy. Bulk deploy passes only `status=='in_stock'` assets; allocate body `{order_id, order_item_id, deploy:false}`.

**`POST /api/assets/bulk-return-to-supplier`** — `handleBulkReturnToSupplier`.
- Request: `{ asset_ids: [String] (required, non-empty), supplier_return_reason: String (required), supplier_return_notes?: String }`.
- Response 200: `{ success:true, data: { batches: [{ supplier_name: String, assets: [Asset], count: Int }], total_returned: Int, errors: [{ asset_id: String, error: String }] } }`.
- Only assets with status ∈ `in_stock, allocated, deployed` **and** a non-null `supplier_name` are processed; others land in `errors` (`Asset not found` / `Invalid status: X` / `No supplier assigned`). Sets `status='pending_return'`, clears order/device checkout.
- Errors: 400 `asset_ids array is required` / `Return reason is required`; 401; 500.
- Return-reason enum (from web `BulkSupplierReturnModal`): `defective, wrong_part, damaged_in_transit, quality_issue, warranty_claim, order_error, other`.

**Export CSV** — client-side, no endpoint. Columns (web `handleExportCSV`): `Asset Tag, Name, Status, Category, Location, Sub-Location, Serial Number, SKU, Condition, Cost`.

### 4b — Analytics (all GET, read-only)

**`GET /api/assets/stock-summary`** — `data` is an **ARRAY** of parent/standalone rollups. Each: `{ product_type_id: String, name: String, sku: String?, parent_id: String?, in_stock_count: Int, allocated_count: Int, total_count: Int, reorder_level: Int, is_low_stock: Bool (true JSON bool), aggregate_in_stock: Int, aggregate_allocated: Int, children: [ { product_type_id, name, sku?, parent_id, in_stock_count, allocated_count, total_count, reorder_level, is_low_stock } ] (always present, may be empty) }`. No query params.

**`GET /api/assets/hierarchy`** — query `status?`. `{ success, data: { grouped: [ { product_type: {id, name, parent_id?}, assets: [ {id, asset_tag, name, status, location_name?} ], children: [ { product_type, assets } ] (top-level only; nested child groups omit `children`) } ], unlinked: [ {id, asset_tag, name, status, location_name?} ] } }`. Model `children` as optional.

**`GET /api/assets/low-stock`** — no params. `{ success, data: { alerts: { parts:[Alert], masters:[Alert], services:[Alert] }, all: [Alert] (merged, sorted by deficit desc), summary: { total: Int, by_category: { parts:Int, masters:Int, services:Int } } } }`. **Alert:** `{ product_type_id: String, name: String, sku: String?, category: String?, product_category: String ("parts"|"masters"|"services"), in_stock_count: Int, reorder_level: Int, deficit: Int, preferred_supplier: String?, parent_name: String?, is_child_service: Bool (true JSON bool), parent_id: String? }`.

### 4c — Book-in, CSV import, Salvage

**Supplier-order book-in** (`worker/supplier_order_handlers.js`):
- **`POST /api/supplier-orders`** (create), **`PATCH /api/supplier-orders/:id`** (status incl. cancel), **`GET /api/supplier-orders`** (list; params `page, limit, supplier`), **`GET /api/supplier-orders/:id`** (detail w/ lines), **`POST/PUT/DELETE /api/supplier-orders/:id/lines[/:lineId]`** (line reconcile), **`POST /api/supplier-orders/extract-invoice`** (multipart `invoice`, AI), **`POST /api/supplier-mappings/bulk-lookup`** + supplier-mappings list — **shapes TO BE VERIFIED against the handler in the implementation plan's first 4c task** (my survey confirmed `receive` + `extract-invoice` usage but not the full CRUD/line/mapping response bodies).
- **`POST /api/supplier-orders/:id/receive`** — `handleReceiveItems`. Request `{ items: [ { line_id: String (required; unknown lines skipped), quantity?: Int=1, serial_numbers?: [String] (indexed per unit), unit_cost?: Number, warranty_months?: Int, condition_grade?: String='A', is_oem?, is_refurbished?, location_id?, sub_location_id? } ] (required, non-empty) }`. Response 200 `{ success:true, data: { order: SupplierOrder, created_assets: [Asset], assets_created_count: Int } }`. Web batches items in chunks of **20**. Errors: 400 `Items array required`; 404 `Order not found`; 401; 500. Side effects: creates `quantity` in-stock asset rows per line, auto-links/creates product types + group memberships, updates line `quantity_received` + order status/totals, logs `booked_in`.

**`POST /api/assets/import`** — `handleImportAssets`. **Admin only** (403 `Admin access required` otherwise). `multipart/form-data`: `csv` File (required, ≤2 MB, ≤1000 rows), `createMissing` String `"true"`. Required CSV header column `sku`. Response 200 `{ success:true, message:"Import completed successfully" (sibling of data), data: { imported:Int, created_product_types:Int, created_categories:Int, created_manufacturers:Int } }`. Validation-failure 400 (distinct shape): `{ success:false, error:"validation_failed", message:"CSV validation failed", errors:[ up to 50 row-error objects ], totalErrors:Int }`. Other 400s: `Invalid form data...`, `No CSV file provided...`, `File too large...`, `CSV file is empty...`, `Too many rows...`, `Missing required column: sku`, `No valid rows to import`.

**Salvage** (`worker/buyback_salvage_handlers.js`):
- **`POST /api/buyback/:id/salvage`** — `handleSalvageBuyback`. Request `{ items: [ { product_type_id: String (required; must be a company inventory_item group), location_id: String (required), condition_grade: 'A'|'B'|'C' (required), sub_location_id?: String, lcd_working?: Bool→Int 0/1/null, glass_cracked?: Bool→Int 0/1/null, value?: Number (≥0; empty→0), notes?: String } ] (required, non-empty) }`. Response **201** `{ success:true, data: { assets: [Asset] (source_type='salvaged', recovered_from_buyback_id set), salvaged_assets: [ { id, asset_tag, name, condition_grade?, cost?, location_id?, lcd_working:Int?, glass_cracked:Int?, created_at, location_name? } ] (reduced projection — ALL non-deleted salvage rows), new_status: String, salvage_budget: { cap:Number, booked:Number, remaining:Number } } }`.
  - Cost-cap 400 (distinct shape): `{ success:false, error:"Salvage value would exceed...", salvage_budget: { ok:false, cap, booked, incoming, remaining } }` (sibling of nothing — top-level).
  - Other errors: 400 `At least one salvage item is required` / `Each item needs product_type_id and location_id` / `Each item needs a valid condition_grade (A, B, or C)` / `Salvage value cannot be negative` / `Inventory group not found: X`; 404 `Buyback device not found`; 403 `...locked for VAT reporting...`; 400 `Cannot salvage a sold device.`; 401; 500.
  - Side effect: on FIRST salvage, flips device to `status='salvaged'`, sets `sale_amount=0`, delists from storefront.
- **`DELETE /api/buyback/:id/salvage/:assetId`** — `handleDeleteSalvageItem`. No body. Response 200 `{ success:true, data: { salvaged_assets: [SalvagedAssetSummary], booked: Number, reverted_to: String? } }`. Errors: 404 `Salvage item not found`; 400 `Cannot remove a salvage item that is currently allocated`; 403 VAT-locked; 401; 500. Soft-deletes the asset; reverts device status if it was the last salvage item.

### Raw `Asset` shape
Every `SELECT *` response (bulk-return `assets`, receive `created_assets`, salvage `assets`) returns the full assets row, which decodes into the existing **`Asset`** model. Confirm the model already covers the Phase-4-relevant columns (`source_type`, `recovered_from_buyback_id`, `lcd_working`, `glass_cracked`, `checked_out_to_buyback_id`); add any missing optional fields (they are additive, safe for iPhone/iPad/Mac).

---

## iOS architecture

Mirror the Phase 1–3 module structure under `Repair Minder/Repair Minder/`.

### Models (new files under `Core/Models/`)
- **`InventoryBulkModels.swift`** — `BulkReturnToSupplierRequest{assetIds:[String], supplierReturnReason:String, supplierReturnNotes:String?=nil}`; `BulkReturnToSupplierResult{batches:[SupplierReturnBatch], totalReturned:Int, errors:[BulkAssetError]}`; `SupplierReturnBatch{supplierName:String?, assets:[Asset], count:Int}`; `BulkAssetError{assetId:String, error:String}`. Bulk move/deploy reuse Phase-2 request structs (looped per asset); define a small `BulkOperationOutcome` value type for the progress/partial-failure UI (client-side, not decoded).
- **`InventoryStockModels.swift`** — `StockSummaryItem` (recursive `children:[StockSummaryItem]?`; `isLowStock:Bool`); `AssetHierarchyResponse{grouped:[HierarchyGroup], unlinked:[HierarchyAsset]}`, `HierarchyGroup{productType:HierarchyProductType, assets:[HierarchyAsset], children:[HierarchyGroup]?}`, `HierarchyProductType{id,name,parentId:String?}`, `HierarchyAsset{id, assetTag, name, status, locationName:String?}`; `LowStockResponse{alerts:LowStockBuckets, all:[LowStockAlert], summary:LowStockSummary}`, `LowStockBuckets{parts,masters,services:[LowStockAlert]}`, `LowStockAlert{...isChildService:Bool...}`, `LowStockSummary{total:Int, byCategory:LowStockByCategory}`.
- **`SupplierOrderModels.swift`** — `SupplierOrder`, `SupplierOrderLine`, `ExtractedInvoice` + line item, request structs (`CreateSupplierOrderRequest`, `SupplierOrderLineRequest`, `ReceiveItemsRequest{items:[ReceiveItemInput]}`, `ReceiveItemInput`), `ReceiveItemsResult{order:SupplierOrder, createdAssets:[Asset], assetsCreatedCount:Int}`, `AssetImportResult` + `AssetImportValidationError`. **Field lists finalized after the 4c contract-verification task.**
- **`SalvageModels.swift`** — `SalvageItemRequest{productTypeId, conditionGrade, locationId, subLocationId:String?=nil, lcdWorking:Int?=nil, glassCracked:Int?=nil, value:Double?=nil, notes:String?=nil}`, `SalvageRequest{items:[SalvageItemRequest]}`, `SalvageResponse{assets:[Asset], salvagedAssets:[SalvagedAssetSummary], newStatus:String, salvageBudget:SalvageBudgetInfo}`, `SalvagedAssetSummary{id, assetTag, name, conditionGrade:String?, cost:Double?, locationId:String?, lcdWorking:Int?, glassCracked:Int?, createdAt:String, locationName:String?}`, `SalvageBudgetInfo{cap:Double?, booked:Double?, remaining:Double?}`, `DeleteSalvageResult{salvagedAssets:[SalvagedAssetSummary], booked:Double?, revertedTo:String?}`.

All models `Decodable, Identifiable (where sensible), Equatable, Sendable`; request structs `Encodable` with every optional `= nil` and field order matching labeled call sites.

### Endpoints — `Core/Networking/APIEndpoints.swift`
New cases (verify method groups + line numbers by grepping): `bulkReturnToSupplier` POST; `stockSummary` GET, `assetHierarchy(status:)` GET, `lowStock` GET; `supplierOrders(page,limit,supplier:)` GET, `supplierOrder(id:)` GET, `createSupplierOrder` POST, `updateSupplierOrder(id:)` PATCH, `supplierOrderLines(id:)` POST, `updateSupplierOrderLine(orderId:,lineId:)` PUT, `deleteSupplierOrderLine(orderId:,lineId:)` DELETE, `receiveSupplierOrder(id:)` POST, `extractInvoice` POST (multipart), `supplierMappingsBulkLookup` POST, `supplierMappingsList` GET; `importAssets` POST (multipart); `salvageBuyback(id:)` POST, `deleteSalvageItem(buybackId:,assetId:)` DELETE. All `requiresAuth == true`.

**Multipart:** `extract-invoice` and `import` are `multipart/form-data`, not JSON — the shared `APIClient` JSON path won't serve these. Add a minimal multipart helper (or a dedicated `APIClient` method) that builds the body + boundary and still attaches the auth header. Verify the existing `APIClient` doesn't already have one before adding.

### Service — `InventoryService.swift` / `InventoryServing`
Extend with: `bulkReturnToSupplier(assetIds:, reason:, notes:) -> BulkReturnToSupplierResult`; `fetchStockSummary() -> [StockSummaryItem]`; `fetchHierarchy(status:) -> AssetHierarchyResponse`; `fetchLowStock() -> LowStockResponse`; supplier-order CRUD/lines/receive/extract/mappings; `importAssets(csvData:, createMissing:) -> AssetImportResult`; `salvageBuyback(id:, items:) -> SalvageResponse`; `deleteSalvageItem(buybackId:, assetId:) -> DeleteSalvageResult`. Bulk move/deploy reuse existing `moveAsset`/`allocateAsset`/`deployExternal` in per-item loops (in the VM, so partial-failure tracking is testable). Keep `init(api: APIClient? = nil)` (@MainActor init trap). Add every new method to the shared `InventoryServingStub` test double.

### Views
- **`Features/Staff/Inventory/InventoryListView.swift`** — add `Stock` to `InventoryMode`; add edit-mode (Select/Select-All/Clear toolbar + selection circles + floating bottom bulk bar) gated to Assets mode; render the low-stock banner above the list.
- **`Features/Staff/Inventory/Bulk/`** — `BulkActionBar`, `BulkMoveSheet`, `BulkDeploySheet`, `BulkReturnToSupplierSheet`, `BulkScanSheet`, `BulkProgressView`, `BulkActions` (pure gating helper), `CSVExporter` (build string + temp file + share sheet). Bulk-op view models track per-asset outcomes.
- **`Features/Staff/Inventory/Stock/`** — `InventoryStockView` (sub-tab container) + `StockSummaryView`/`StockSummaryViewModel`, `AssetHierarchyView`/VM, `LowStockView`/VM + `LowStockBanner`. Read-only; row taps cross-navigate to filtered Assets / asset detail.
- **`Features/Staff/Inventory/BookIn/`** — `SupplierOrderListView`/VM, `BookInWizardView` + step views (`OrderDetailsStep`, `LineItemsStep`, `ReceiveItemsStep`, `BookInSuccessStep`), `InvoiceUploadView` (document picker + PDFKit), `AssetImportSheet` (admin-gated document picker → multipart import → validation report).
- **`Features/Staff/Buyback/SalvageDeviceCard.swift`** (+ VM) — on `BuybackDetailView`; staging form, batch, budget compute helper (`SalvageBudget` pure calc — `overCap = round2(booked+pending) > cap`), booked list with per-asset remove. Screen-category detection (group category contains "screen" → LCD/glass required).

### Conventions & gating
Standing rules apply: `APIError.httpError(statusCode:message:)` vs `serverError(message:code:)` (no `userMessage` — use `localizedDescription`; map 400/409 by httpError statusCode/message); sheets show their OWN inline error; post `.inventoryAssetDidChange` after every mutation; distinct `Identifiable` route wrappers to avoid `navigationDestination(item:)` collisions; extract row subviews for `ForEach` closures with nested `if let`; file-system-synchronized Xcode groups (no `.pbxproj` edits). Pure testable gating helpers: `BulkActions` (deployable/returnable counts + validity), `SalvageBudget` (cap math + `canAdd`/screen-required), CSV-import admin gate.

---

## No-Deferral Checklist (web control → iOS equivalent)

### Bulk / multi-select (`AssetsPage.tsx`, `Bulk*Modal.tsx`)
| Web control | iOS |
|---|---|
| Grid/table checkboxes + select-all | Edit-mode selection circles + Select-All toolbar item |
| Shift-click range select | — (iOS has no shift; N/A, not a feature loss) |
| Clear selection / "{n} selected" | Clear toolbar item + count in bulk bar |
| Bulk Move (loop `/move`) | `BulkMoveSheet` → per-asset `/move` + progress |
| Bulk Deploy (in-stock only; order/external) | `BulkDeploySheet` → per-asset `/allocate` \| `/deploy-external` |
| Bulk Return to Supplier | `BulkReturnToSupplierSheet` → `bulk-return-to-supplier` |
| Bulk Export CSV (client blob) | `CSVExporter` → temp file → share sheet |
| Bulk Print Labels (popup print) | **EXCLUDED (signed off)** |
| Bulk scan accumulator (hardware wedge) | `BulkScanSheet` (camera) → same Deploy/Move sheets |

### Analytics (`StockSummaryView`, `AssetHierarchyView`, `LowStockPanel`)
| Web control | iOS |
|---|---|
| Summary view (sortable, expand children, row→filter) | `StockSummaryView` (sort, expand, row→filtered Assets) |
| Hierarchy view (expand/collapse all, unlinked panel, asset→detail) | `AssetHierarchyView` |
| Low-stock banner (collapse, refresh, view→filter) | `LowStockBanner` + `LowStockView` |
| View-mode toggle | `Stock` segment + sub-tabs |

### Book-in (`BookInPage.tsx`, `BookInForm`, `ReceiveItemsForm`)
| Web control | iOS |
|---|---|
| Supplier-order list (search, status filter, pagination) | `SupplierOrderListView` |
| New/Edit/Cancel order | wizard create/edit + Cancel (`PATCH status:cancelled`) |
| Invoice PDF upload + AI extract + preview | `InvoiceUploadView` (document picker + `extract-invoice` + PDFKit) |
| Order Details form (supplier datalist, dates, stock-in-hand, notes) | `OrderDetailsStep` |
| Line Items reconcile (add/update/delete lines, product/group match) | `LineItemsStep` |
| Receive (qty, condition, warranty, serials, location, group assign) | `ReceiveItemsStep` → `receive` (chunk 20) |
| Success (created assets, receive more/done) | `BookInSuccessStep` (no label print) |
| CSV import (Settings, admin) | `AssetImportSheet` (admin-gated document picker → `import`) |

### Salvage (`SalvageDeviceCard.tsx`)
| Web control | iOS |
|---|---|
| Budget header (remaining/cap) | budget header |
| Configure item (group, grade A/B/C, value, screen LCD/glass, location, notes) | staging form |
| Add-to-batch / staged list / remove | staged batch UI |
| Book (budget-capped, confirm-on-first) | Book → `salvage` (cap-guarded, confirm) |
| Booked assets list + per-asset remove | list → `DELETE .../salvage/:assetId` |

**Intentional exclusions:** bulk label printing only (desktop popup-print; iOS-can't parity to the QR-label-grid mechanism; user-confirmed). Non-parity skips (no web UI): `POST /api/assets/bulk`, `GET /api/assets/next-tag`, `GET /api/assets/stats`.

---

## Sequencing (all land in `feat/ios-inventory-phase4`)

- **4a — Bulk / multi-select.** Models + endpoints + service, edit-mode + bulk bar, 4 bulk sheets + scan accumulator + CSV export, `BulkActions` gating. Depends on Phase-2 move/deploy.
- **4b — Analytics.** Read-only models + 3 endpoints + service, `Stock` segment + 3 sub-views + low-stock banner. Independent of 4a.
- **4c — Book-in + CSV import + Salvage.** Starts with a **contract-verification task** for supplier-order CRUD/lines/mappings/extract-invoice. Then supplier-order subsystem + wizard; CSV import sheet; salvage card on Buyback detail. Largest sub-phase.

---

## Verification (mandatory — all before merge)

### Unit tests
- **Encoding:** one test per request struct (`BulkReturnToSupplierRequest`, `ReceiveItemsRequest`/`ReceiveItemInput`, `CreateSupplierOrderRequest`, `SupplierOrderLineRequest`, `SalvageRequest`/`SalvageItemRequest`) asserting exact snake_case (incl. Int-boolean encoding, screen fields nil-omitted).
- **Decoding vs REAL captured JSON:** `BulkReturnToSupplierResult`, `StockSummaryItem` (array + recursive children + `is_low_stock` Bool), `AssetHierarchyResponse`, `LowStockResponse` (`is_child_service` Bool), `ReceiveItemsResult`, `SupplierOrder`/`SupplierOrderLine`, `ExtractedInvoice`, `AssetImportResult` + validation-error 400, `SalvageResponse` (incl. cap-exceeded 400 shape), `DeleteSalvageResult`. Capture with an admin token (admin company `4b63c1e6ade1885e73171e10221cac53` has data).
- **View-model mutations:** every write via a mock `InventoryServing` (bulk return incl. batches/errors surfacing; bulk move/deploy incl. partial-failure tracking; receive; import incl. validation-error report; salvage add/book/remove incl. budget/cap + screen-required). Analytics VMs (load/sort/expand/filter-navigation).
- **Gating:** `BulkActions` (deployable/returnable/validity), `SalvageBudget` (cap math, `canAdd`, screen-required), CSV-import admin gate.

### Live prod E2E of EVERY write (admin token; admin company has data)
Perform → assert the live response decodes into the Swift model exactly → clean up. Writes: **bulk-return-to-supplier**, **bulk move** (loop), **bulk deploy** (loop; allocate by order id only, no line item → no `order_parts`, as in Phase 2), **supplier-order create + line add + receive** (book-in), **CSV import**, **salvage + delete-salvage**. Use a `ZZ-P4-` name/tag/reference prefix; verify by `created_at`/prefix; **never delete a row you didn't create**.
- **Cleanup (API delete is SOFT):** hard-delete via D1 — created `assets` (incl. salvaged + received + bulk-created-by-receive), `supplier_orders` + `supplier_order_lines`, `asset_group_memberships`, `supplier_name_mappings`/`supplier_sku_mappings`, `product_types` created by import/receive, and revert any buyback device flipped to `salvaged`. Confirm **zero** `ZZ-P4-` artifacts remain in admin AND demo companies at the end. Prefer non-destructive shapes; for bulk-return use throwaway assets.

### XCUITest (reuse `InventoryGroupsUITest`/`InventoryEditActionUITest` harness)
Drive ≥1 new Phase-4 write end-to-end in the sim: Magic-Link login (demo `appstore-demo@repairminder.com`, code `123456`, company `demo-company-001`) → e.g. Assets → Select → pick a seeded in-stock asset → Bulk Return to Supplier → reason → submit → assert back on the list. Prime the FAB overlay with a neutral tap; tap by precise leaf element (asset-tag static text); `.accessibilityIdentifier` on leaf controls only. Seed the demo company via API/D1, run green, then delete the seed. `XCTSkip` when empty (CI-safe).

### Builds & release
iOS scheme green (`iPhone 17 Pro`, `-parallel-testing-enabled NO`). New files add **zero** errors under "Repair Minder Mac" (ignore pre-existing `Signals/` Diagnostics errors — grep the error output for new file paths). Bump `CURRENT_PROJECT_VERSION` **007 → 008**.

### Final full-branch review
A read-only reviewer over the whole branch before merge (Phase 3's final review caught a data-loss bug, dead parity plumbing, and a wrong-error-case mapping). Take findings seriously.

---

## Cross-project sync gate

These are the app's OWN calls to endpoints that already exist and are consumed by the web app; **no backend changes, no new endpoints, no auth/push/portal/deep-link changes.** Confirm each request/response shape against the handler (done above + the 4c verification task) and keep field names snake_case. If the Asset model needs additive optional fields (`source_type`, `recovered_from_buyback_id`, `lcd_working`, `glass_cracked`, `checked_out_to_buyback_id`) they affect iPhone/iPad/Mac (shared model) — additive, non-breaking. Sync gate: all "no".

---

## Handoff (this is the LAST phase)

- Append a "Phase 4 complete" note to the roadmap (commits, what shipped, live-E2E + XCUITest results, new gotchas, confirmed exclusions) and add an "Inventory feature COMPLETE" closeout (no Phase 5 heading to flip).
- Add memory `project_ios_inventory_phase4` (link `[[project_ios_inventory_phase3]]`); update `MEMORY.md`. Note the iOS Inventory full-parity recreation is complete across all 4 phases.
- Merge to `main` and `git push origin main`. No next-phase prompt to produce.
