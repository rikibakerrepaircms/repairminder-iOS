# iOS Inventory Section — Phase 2 Design (Per-Asset Write Actions)

**Date:** 2026-07-03
**Status:** Approved design — ready for implementation plan
**Repo:** `repairminder-iOS` (source root: `Repair Minder/Repair Minder/`)
**Platforms:** iPhone, iPad, Mac (shared SwiftUI target; scanner/camera stays iOS-only — no camera use in Phase 2)
**Depends on:** Phase 1 (merged to `main`, browse-only) — this phase EXTENDS the Phase-1 module, it does not rewrite it.

---

## 1. Context & goal

Phase 1 shipped the read-only Inventory section (list + detail). Phase 2 adds every **single-asset mutation** from the web dashboard's `AssetDetailPage`, surfaced as a toolbar + contextual actions on `InventoryDetailView`, plus one guarded list-row swipe action. All endpoints already exist on the backend — **Phase 2 ships with ZERO backend changes** (each request/response was contract-verified against `worker/asset_handlers.js`).

**Web reference:** `repairminder/src/pages/AssetDetailPage.tsx` + `src/components/modals/{AssetReturnModal,AssetMoveModal,DeployAssetModal,DeployToOrderModal,DeployExternalModal}.tsx` + `src/services/inventoryApi.ts`.

## 2. Scope

**In scope (Phase 2):**
- Edit fields (`PUT /assets/:id`) with SKU/category-propagation warning + post-save count feedback.
- Move (`POST /assets/:id/move`).
- Deploy — **full parity**: a chooser → (a) **To-Order wizard** (order search → line-item select → confirm → optional pulled-part recovery) via `POST /assets/:id/allocate`, and (b) External deploy via `POST /assets/:id/deploy-external`.
- Return to stock from external (`POST /assets/:id/return-external`).
- Return to supplier (`POST /assets/:id/return-to-supplier`).
- Resolve supplier return (`POST /assets/:id/resolve-supplier-return`) — surfaced on the detail **pending-return banner**.
- Delete (`DELETE /assets/:id`) — guarded.
- Fold in the Phase-1 follow-up: fix the `guard !isLoading` silent-drop in `InventoryListViewModel`.

**Explicitly deferred:**
- **Status change** (`PATCH /assets/:id/status`) — the web detail page has NO status control (status is read-only there; changes flow only through allocate/deploy/return). We match web and omit it. The endpoint is left for a later phase / the scanner flow.
- A dedicated Returns-list screen (web `/assets/returns`) — Resolve is handled inline on the detail banner instead.
- Inventory Groups management, promote-to-product, bulk actions, book-in, salvage (Phases 3–4).
- Order tap-through / deep-linking from the "ready to repair" / "view order" prompts — we show them as informational only.

**Non-goals:** no backend changes; no new permission gating (server-side 403 + existing TabBarConfig).

## 3. Action set & gating rules (verified against `AssetDetailPage.tsx`)

`isAllocated = status == .allocated || status == .deployed` (the web derived flag).

| Action | Endpoint | Enable when | Surface | Disabled hint |
|---|---|---|---|---|
| **Edit** | `PUT /assets/:id` | always | Toolbar menu → `AssetEditSheet` | — |
| **Move** | `POST /move` | always | Toolbar menu → `AssetMoveSheet` | — |
| **Deploy** | `POST /allocate` \| `/deploy-external` | `status == .inStock` | Toolbar menu → `DeployChooserSheet` | hidden unless in stock |
| **Return to supplier** | `POST /return-to-supplier` | `status ∈ {inStock,allocated,deployed}` AND `supplierName != nil` AND `status != .pendingReturn` | Toolbar menu → `ReturnToSupplierSheet` | "Return already in progress" / "No supplier assigned" / "Cannot return asset with this status" (priority order) |
| **Resolve return** | `POST /resolve-supplier-return` | `status == .pendingReturn` | Pending-return banner (credit / replacement) | — |
| **Return to stock** | `POST /return-external` | `status == .deployed` AND active external deployment present | Button in Status & Location card | shown only when eligible |
| **Delete** | `DELETE /assets/:id` | disabled when `isAllocated` | Toolbar menu → confirm dialog + list swipe | "Cannot delete allocated assets" |
| ~~Status change~~ | — | **omitted** | — | matches web |

The toolbar is a SwiftUI `Menu` (ellipsis in `.primaryAction`) listing Edit / Move / Deploy / Return to Supplier / Delete with the disabled states above. Return-to-stock and Resolve are rendered contextually (inside the Status card / pending-return banner), matching where the web page places them.

## 4. Deploy wizard (full parity)

`DeployChooserSheet` presents two options (mirrors web `DeployAssetModal`):

**To Order — `DeployToOrderWizard`** (state machine: `search → selectLineItem → confirm → done`):
- `search`: query `.orders(page:1, limit:10, ..., search:)`; list orders (ticket number, client, status).
- select order → load `.orderItems(orderId:)`; empty-items → "No line items — add one first" with a note (no deep create in Phase 2).
- `selectLineItem`: pick an `OrderItem` (optional `order_item_id` — used server-side to derive the device).
- `confirm`: allocation summary. If `asset.enablePartRecoveryBool`, render `PartRecoveryForm` (condition grade A/B/C required, location picker required, optional sub-location/notes/lcd_working/glass_cracked).
- Submit `allocate(order_id, order_item_id?, deploy:false, recovery?)`.
- `done`: success screen; when the response includes `recovered_asset`, show a "Pulled Part Recovered" card (no print-label in Phase 2 — display only).

**External — `DeployExternalSheet`** (mirrors `DeployExternalModal`):
- Fields: Customer Name (optional), External Reference (optional), Deployment Date (defaults to today, `yyyy-MM-dd`), Notes (optional). Empty strings coerced to `nil`.
- Submit `deploy-external(...)`.

A small `@MainActor DeployViewModel` owns order search + line-item loading and the allocate/deploy calls. Reuses existing `Order` / `OrderItem` models.

## 5. Networking additions

### 5.1 `APIEndpoint` cases (`Core/Networking/APIEndpoints.swift`)
Add: `updateAsset(id:)` (PUT), `moveAsset(id:)` (POST), `allocateAsset(id:)` (POST), `deployExternalAsset(id:)` (POST), `returnExternalAsset(id:)` (POST), `returnToSupplierAsset(id:)` (POST), `resolveSupplierReturn(id:)` (POST), `deleteAsset(id:)` (DELETE). Paths per the table in §3. Add each to the correct `method` group; `requiresAuth` defaults to `true`. No query items. **No status endpoint.**

### 5.2 Encodable request structs (`Core/Models/InventoryWriteModels.swift`)
camelCase fields; the shared encoder is `.convertToSnakeCase`, so no explicit CodingKeys. Only send fields the handler accepts:
- `UpdateAssetRequest`: `serialNumber, name, sku, category, manufacturer, modelNumber, supplierName, supplierOrderReference, purchaseDate, cost, costIncVat, warrantyMonths, warrantyExpires, conditionGrade, isOem(Int?), isRefurbished(Int?), locationId, subLocationId, notes` — all optional; the sheet sends the editable subset (see §6.1). `isOem`/`isRefurbished` encoded as Int 0/1.
- `MoveAssetRequest`: `locationId, subLocationId?`.
- `AllocateRequest`: `orderId?, deviceId?, orderItemId?, deploy: Bool, recovery: RecoveryInput?`. `RecoveryInput`: `conditionGrade, locationId, subLocationId?, notes?, lcdWorking(Int?), glassCracked(Int?)`.
- `DeployExternalRequest`: `customerName?, externalReference?, notes?, deploymentDate?`.
- `ReturnExternalRequest`: `deploymentId, returnToStock: Bool?, notes?`.
- `ReturnToSupplierRequest`: `supplierReturnReason, supplierReturnNotes?`.
- `ResolveReturnRequest`: `resolution (String: "credit_received"|"replacement_received"), replacementAssetId?, notes?`.

### 5.3 Response decoding
Backend returns a full `assets` row (`SELECT *`) under `data` for most writes → decodes straight into the **existing `Asset`** via `request<Asset>`. Custom shapes (`Core/Models/InventoryWriteModels.swift`):
- `EditAssetResponse { success: Bool, data: Asset, skuUpdatedCount: Int? }` — SKU-propagation count (envelope sibling of `data`).
- `AllocateResponse { success: Bool, data: Asset, promptReadyToRepair: Bool?, allocatedParts: [AllocatedPart]?, device: AllocateDevice?, recoveredAsset: RecoveredAsset? }`.
  - `AllocatedPart { id, assetName, assetTag, sourceStatus }`; `AllocateDevice { id, status, displayName }`; `RecoveredAsset` = the `Asset` fields plus optional joined `productTypeName, locationName, subLocationCode` (already present on `Asset`, so `RecoveredAsset` can just be `Asset`).
- `DeployExternalData { asset: Asset, deployment: ExternalDeploymentRecord }` — nested UNDER `data`, so `request<DeployExternalData>` works (reuses Phase-1 `ExternalDeploymentRecord`).
- Delete → `requestVoid` (`{success, message}`; message ignored).

### 5.4 `APIClient` helper (one additive method)
`sku_updated_count`, `prompt_ready_to_repair`, `prompt_view_order` are **siblings of `data`** in the envelope; the shared `APIResponse<T>` only decodes `success/data/pagination/error/code` and silently drops them. Add ONE additive method:
```swift
func requestFull<R: Decodable>(_ endpoint: APIEndpoint, body: Encodable? = nil) async throws -> R
```
It performs the request and decodes the whole top-level body as `R` (no `.data` unwrap), reusing the existing request build + error handling. Used only by **Edit** (`EditAssetResponse`) and **Allocate** (`AllocateResponse`). Every other write uses the existing `request`/`requestVoid`. This keeps the shared envelope untouched.

## 6. Detail & list wiring

### 6.1 `AssetEditSheet` (mirrors web `EditFormData`)
Editable inputs (web parity): `serial_number` (text), `sku` (text), `category` (text + suggestions from `fetchCategories()`), `condition_grade` (picker: A/B/C/D/F + none), `is_oem` (toggle), `is_refurbished` (toggle), `warranty_months` (number), `notes` (textarea). `name` is carried through unchanged (web renders no visible name input in edit mode). Fields seed from the current asset; empty → omitted.
**SKU-propagation warning** shown under Category when `asset.sku != nil && editedCategory != asset.category`: _"This will update all assets with SKU: {sku}"_ (amber). After save, if `skuUpdatedCount > 0`, toast _"Category also applied to N other asset(s) with the same SKU"_; else _"Asset updated"_.

### 6.2 `InventoryDetailViewModel` — mutation methods
One method per action. Each calls the service, then (matching web's optimistic behaviour) sets `asset` from the response's `data`, re-runs the activity + external-deployment sub-loads, and clears/sets a `banner`/`toast` message. Failures set `actionError` (surfaced via `.alert`). After any successful mutation, post `Notification.Name.inventoryAssetDidChange`. Delete triggers a `didDelete` flag so the view can pop.

### 6.3 List invalidation
Add `Notification.Name.inventoryAssetDidChange`. `InventoryListViewModel` observes it and sets `needsReload`; the list re-runs `loadAssets()` on next appear (cheap, decoupled — no callback threading through navigation).

### 6.4 Swipe action
`InventoryListView` rows get a **trailing swipe → Delete**, rendered only when the row is deletable (`status ∉ {allocated, deployed}`), with a confirmation dialog. On success it removes the row locally and posts the change notification. No mutating leading swipe (Move/Deploy need pickers, which belong in sheets).

## 7. Phase-1 follow-up fix: coalesce filter changes during load

`InventoryListViewModel.loadAssets()` currently `guard !isLoading { return }`, silently dropping a status/search/filter change made while a load is in flight. Replace with coalescing: if called while `isLoading`, set `pendingReload = true` and return; when the in-flight load finishes, if `pendingReload`, clear it and load again (loop until clean). Add a regression test that mutates the query mid-load and asserts the final list reflects the latest query.

## 8. Testing

- **Unit — request encoding:** one test per request struct; assert snake_case keys and Int-boolean coercion (`is_oem`/`is_refurbished`, recovery `lcd_working`/`glass_cracked`), and that omitted optionals are absent.
- **Unit — response decoding against REAL JSON:** capture live responses with an admin token (rule `repairminder/.claude/rules/api-tokens.md`, admin company `4b63c1e6ade1885e73171e10221cac53` which HAS assets) for Edit, Move, Allocate, Deploy-external, Return-to-supplier; assert `EditAssetResponse.skuUpdatedCount`, `AllocateResponse` (prompt/parts/device/recovered), `DeployExternalData.{asset,deployment}` decode. This is the lesson from the Phase-1 `checked_out_order_number` crash — synthetic JSON is not enough.
- **Unit — view models:** mutation methods drive a mock `InventoryServing`; assert `asset` updates, notification posts, error path sets `actionError`. Plus the §7 coalescing test.
- **Runtime smoke:** seed an asset via `POST /api/assets` (admin token), exercise Edit → Move → Delete against it, then clean up (leave the account tidy). Capture the live Edit response to back the decode test. Deploy-to-order is decode-verified against a real `allocate` response where available; if a full order can't be seeded at runtime, report that honestly rather than claim it was driven end-to-end.
- **Build:** iOS (`iPhone 17 Pro` sim) green; confirm new files compile under the Mac scheme too (do NOT touch the pre-existing unrelated Diagnostics build errors).

## 9. Module layout

New under `Features/Staff/Inventory/Actions/`:
`AssetEditSheet.swift`, `AssetMoveSheet.swift`, `DeployChooserSheet.swift`, `DeployToOrderWizard.swift`, `DeployExternalSheet.swift`, `PartRecoveryForm.swift`, `ReturnToSupplierSheet.swift`, `DeployViewModel.swift`.
New model file: `Core/Models/InventoryWriteModels.swift` (request + custom response structs).
Extended (not rewritten): `InventoryService.swift` (+8 write methods on `InventoryServing`), `InventoryDetailView.swift` (toolbar/banner/sheets), `InventoryDetailViewModel.swift` (mutation methods), `InventoryListView.swift` (swipe), `InventoryListViewModel.swift` (coalescing + notification observer), `Core/Networking/APIEndpoints.swift` (+8 cases), `Core/Networking/APIClient.swift` (+`requestFull`).

## 10. Apple-sync / backend

All eight endpoints exist and were contract-verified against `worker/asset_handlers.js`. Every response field is snake_case; Int-booleans (`is_oem`, `is_refurbished`, `lcd_working`, `glass_cracked`) decode as `Int?`; `sku_updated_count` is `Int`; `prompt_ready_to_repair` / `prompt_view_order` are `Bool`. Delete blocks with **400** (not 409) when `checked_out_to_order_id`/`checked_out_to_device_id` is set. **No backend or web changes ship.** Per the cross-project rule: these are the app's own write calls against existing endpoints; the sync gate answers are all "no new/changed backend contract."

## 11. Open items (resolve during planning/implementation)

- Confirm the live `allocate` response's `allocated_parts` / `device` shapes against a real allocated order when capturing JSON (fall back to the handler's documented shape if no seed-able order is available).
- Confirm the `OrderItem` fields shown in the wizard line-item picker (label/price) against the real `.orderItems` response.
- Decide the exact toast/banner presentation component (reuse whatever Buyback/Orders detail already uses for inline success/error, or a lightweight `@Published var toast`).
