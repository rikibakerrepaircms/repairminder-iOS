# iOS Inventory Section — Phase 1 Design (Foundation + Full Browse)

**Date:** 2026-07-03
**Status:** Approved design — ready for implementation plan
**Repo:** `repairminder-iOS` (source root: `Repair Minder/Repair Minder/`)
**Platforms:** iPhone, iPad, Mac (shared SwiftUI target; scanner is iOS-only)

---

## 1. Context & end goal

The web dashboard has a large **Inventory / Assets** section (routes `/assets`, `/assets/:id`) backed by `/api/assets*` and `/api/asset-groups*`. The end goal is **full parity** in the iOS app, delivered in four sequenced phases:

- **Phase 1 (this spec)** — Foundation + full browse: models, API layer, the opt-in `Inventory` tab, the asset **list** (search + full filter set + status + pagination + scan-to-find), and the asset **detail** (all read sections + activity timeline + groups + external deployment). Read-only.
- **Phase 2** — Per-asset write actions (edit, move, deploy/allocate, status change, delete, return-to-supplier + resolve, external deploy/return).
- **Phase 3** — Inventory Groups (groups list, group detail, assign-to-group, create group, promote-to-product).
- **Phase 4** — Advanced (bulk actions, stock-summary / hierarchy / low-stock views, book-in / supplier-orders, salvage).

Each later phase plugs into the models/list/detail built here and gets its own spec → plan → build.

## 2. Scope

**In scope (Phase 1):**
- Swift models for Asset, asset status, activity, asset-group summary, external deployment.
- API layer: 6 inventory GETs + 2 new supporting read endpoints (categories, asset-groups list). Reuse existing locations / sub-locations / product-types endpoints.
- `FeatureTab.inventory` opt-in tab + More-overflow plumbing (using the `isEmbedded` pattern).
- Inventory **list** screen: rows, status pills, debounced search, **full web-parity filter set**, infinite-scroll pagination, pull-to-refresh, scan-to-find.
- Inventory **detail** screen: full read parity (all sections) + 3 sub-resource reads.

**Explicitly deferred (NOT Phase 1):** any write/mutation, Inventory Groups management UI, promote-to-product, bulk actions, stock-summary/hierarchy views, book-in, salvage, CSV import/export. (Phases 2–4.)

**Non-goals:** no backend changes; no new iOS permission gating (feature availability is TabBarConfig + server-side 403 enforcement).

## 3. Architecture & module layout

New module `Features/Staff/Inventory/`, mirroring the existing **Buyback** module (closest analog):

| File | Role |
|---|---|
| `InventoryListView.swift` | List UI. `isEmbedded`/size-class branches; owns a `NavigationStack` only when NOT embedded (avoids the double-stack bug fixed 2026-07-03). |
| `InventoryDetailView.swift` | Detail UI. `@StateObject` VM from `assetId`; `.task` loads detail + 3 sub-resources. |
| `InventoryListViewModel.swift` | load / loadMore / refresh / debounced search / filter state. |
| `InventoryDetailViewModel.swift` | `loadDetail()` + parallel sub-resource loads + `refresh()`. |
| `AssetStatusHelpers.swift` | `assetStatusColor(_:)` + `AssetStatusBadge` view. |
| `AssetFilterSheet.swift` | Filter sheet (category / location / sub-location / product type / group / toggles). |
| `Core/Models/Inventory.swift` | Codable models (Asset, responses, sub-resources). |
| `Core/Models/InventoryEnums.swift` | `AssetStatus` (+ `UnknownDefaultable`). |

**Networking:** use the shared **`APIClient`** (`request` / `requestWithPagination`) — the app standard (Orders/Devices/Clients). Do NOT copy Buyback's hand-rolled `URLSession` (the codebase outlier). Decoder is `.convertFromSnakeCase` + `.iso8601` globally.

## 4. Data models

Conventions (repo rules): `Decodable, Identifiable, Equatable, Sendable` (list item also `Hashable`); **no explicit snake_case `CodingKeys`**; SQLite booleans decoded as `Int?` + computed `== 1`; unknown enum strings fall back via `UnknownDefaultable`; reuse the shared `Pagination` struct.

### `Asset` (one struct for list + detail; union of fields, all optional except `id`, `assetTag`, `name`, `status`)
Covers the assets-table columns plus joined fields returned by the API. Key fields:
`id, companyId, productTypeId, assetTag, serialNumber, name, sku, category, manufacturer, modelNumber, supplierName, supplierOrderReference, purchaseDate, cost, costIncVat, warrantyMonths, warrantyExpires, conditionGrade, isOem(Int?), isRefurbished(Int?), locationId, subLocationId, status(AssetStatus), checkedOutToOrderId, checkedOutToDeviceId, checkedOutAt, checkedOutBy, deployedAt, returnedAt, returnReason, returnCondition, supplierReturnReason, supplierReturnNotes, supplierReturnInitiatedAt, supplierReturnResolvedAt, supplierReturnResolution, replacementAssetId, notes, createdAt, updatedAt, sourceType, recoveredFromAssetId, recoveredFromBuybackId, recoveredFromOrderId, recoveredFromDeviceId, recoveredBy, recoveredAt, lcdWorking(Int?), glassCracked(Int?), enablePartRecovery(Int?)`
Joined/computed from API: `productTypeName, productTypeSku, locationName, subLocationCode, subLocationDescription, checkedOutOrderNumber, checkedOutDeviceName, checkedOutToBuybackId, createdByEmail, updatedByEmail, checkedOutByEmail, groupNames(String?), groupIds(String?)`.

**Quirks (must handle):**
- `groupNames` / `groupIds` are **comma-joined strings**, not arrays → computed `groupNamesList: [String]`, `groupIdsList: [String]`.
- Int-booleans: `isOem, isRefurbished, lcdWorking, glassCracked, enablePartRecovery` → `Int?` + computed `Bool` accessors.
- Money fields (`cost`, `costIncVat`) are nullable REALs → `Double?`, formatted via `CurrencyFormatter`.

### `AssetStatus` enum (`UnknownDefaultable`)
`inStock, allocated, reserved, deployed, used, returned, damaged, sold, pendingReturn` (+ `.unknown` fallback, excluded from `allCases`). Display label + colour in `AssetStatusHelpers`.

### List pagination — count heuristic (no custom envelope)
The assets list returns `{ success, data: [Asset], meta: {...} }` — pagination under `meta`, not `pagination`. Rather than a custom envelope, decode `data` as `[Asset]` via the standard `APIClient.request<[Asset]>` (the `APIResponse<T>` decoder ignores the unknown `meta` key) and drive infinite scroll with the heuristic **`hasMore = (returnedCount == pageSize)`**. Trade-off: no "N total / page X of Y" display, which infinite scroll doesn't need. This keeps every inventory call on the standard `APIClient` with zero custom decoding.

### Sub-resource models
- `AssetActivity` (activity-log row: id, action/type, description, user, timestamp — mirror web `AssetActivity`).
- `AssetGroupSummary` (from `/api/assets/:id/groups`): `id, name, sku, category, membershipId, minCost?, avgCost?, maxCost?, inStockCount`.
- `ExternalDeployment` (from `/api/assets/:id/external-deployment?include_history=true`): `active: ExternalDeploymentRecord?`, `history: [ExternalDeploymentRecord]?`. Record: `id, assetId, customerName?, externalReference?, notes?, deploymentDate?, status, returnedAt?, deployedBy?, createdAt`.

## 5. API layer

Add to `APIEndpoint` (`Core/Networking/APIEndpoints.swift`) — all GET, all `requiresAuth = true` (default), company-scoped server-side:

**Inventory (new):**
- `inventoryList(page, limit, status?, category?, locationId?, subLocationId?, productTypeId?, groupId?, hasGroups?, hasProducts?, search?, sortBy?, sortOrder?)` → `/api/assets`
- `inventoryDetail(id)` → `/api/assets/{id}`
- `inventoryByTag(tag)` → `/api/assets/tag/{tag}`
- `inventoryActivity(id, limit?)` → `/api/assets/{id}/activity`
- `inventoryAssetGroups(id)` → `/api/assets/{id}/groups`
- `inventoryExternalDeployment(id)` → `/api/assets/{id}/external-deployment?include_history=true`

**Supporting reads (new, backend routes already exist):**
- `productTypeCategories` → `/api/product-types/categories` (category filter source)
- `assetGroupsList(page, limit, search?)` → `/api/asset-groups` (group filter source; foundational for Phase 3)

**Reused (already on iOS):** `.locations`, `.locationSubLocations(locationId:)`, `.productTypes(search:)`, plus `Location` model.

**No backend changes required.**

## 6. Tab / navigation integration

- `Core/Models/TabBarConfig.swift`: add `case inventory` to `FeatureTab` with `label = "Inventory"`, `icon = "shippingbox.fill"`, `fallbackOrder` after `.devices`. Default tabs unchanged → Inventory is **opt-in** (appears in More overflow until the user adds it). 
- `Repair_MinderApp.swift` `StaffMainView.tabContent(for:)`: add `case .inventory: NavigationStack { InventoryListView() }` (optionally with a deep-link `navigationDestination` — defer deep links unless backend sends inventory links).
- `Features/Settings/SettingsView.swift`: add `SettingsDestination.inventory`, map it in `SettingsDestination.from(_:)`, and in `destinationView` render `InventoryListView(isEmbedded: true)`. Add the iPad split-view `onBack` branch to match Buyback/Clients if desired.
- **`isEmbedded` contract:** `embeddedBody` must NOT create its own `NavigationStack` (the Settings stack provides it); the standalone iPhone layout owns one. This is the exact pattern that fixes the double-stack hang.

## 7. List screen

**Rows:** asset tag (mono, bold) · `AssetStatusBadge` · name · category · location (`locationName / subLocationCode`) · up to 2 group chips (from `groupNamesList`, "+N") · cost (`CurrencyFormatter`). Allocation hint (order #/device) when `allocated`/`deployed`.

**Status pills** (horizontal scroll): All / In stock / Allocated / Reserved / Deployed / Pending return / Returned / Damaged / Sold. Filter-only (no counts in Phase 1).

**Search:** debounced 300 ms → `search` param (matches tag/name/serial/sku server-side).

**Filter sheet (`AssetFilterSheet`) — full web-list parity:**
- Category (picker sourced from `productTypeCategories`)
- Location (picker from `.locations`) → when set, Sub-location picker (from `.locationSubLocations`)
- Product Type (searchable picker from `.productTypes(search:)`)
- Group (searchable picker from `assetGroupsList`)
- "Unassigned (no groups)" toggle → `hasGroups=false`
- "No products" toggle → `hasProducts=false`
- Clear-all. Active-filter count badge on the toolbar filter button.

**Pagination:** `pageSize = 24`, `loadMoreIfNeeded(currentItem:)` appends the next page while `hasMore` (i.e. the last page returned exactly `pageSize` rows). Pull-to-refresh reloads page 1. No total-count display.

**Scan-to-find (`#if os(iOS)` only):** toolbar scan button → reuse the existing device camera scanner → on capture call `inventoryByTag(tag)` → push `InventoryDetailView`. On not-found, show a lookup-failed alert. Hidden on Mac (`#if os(macOS)` → no scan button).

**States:** loading (skeleton/spinner when `isLoading && items.isEmpty`), error (message + retry), empty ("No inventory items" / "No matches").

## 8. Detail screen (full read parity, read-only)

Single scroll. `InventoryDetailViewModel` fires, on `.task`, the main `inventoryDetail(id)` plus (in parallel) `inventoryActivity`, `inventoryAssetGroups`, `inventoryExternalDeployment`. Sections render only when their data is present:

1. **Header** — asset tag (mono) + copy, `AssetStatusBadge`, name.
2. **Pending-Return banner** — when `status == pendingReturn` (reason/notes/initiated date).
3. **Identification** — serial, SKU, category, product type (name; link deferred to Phase 2 nav).
4. **Inventory Groups** — from `inventoryAssetGroups` (name, SKU, in-stock, min/avg/max cost).
5. **Status & Location** — status, location, sub-location; when allocated/deployed: order # + device; **External Deployment** block from `inventoryExternalDeployment` (customer, reference, deployed date/by, history count).
6. **Purchase Info** — supplier, order ref, purchase date, cost, cost inc VAT.
7. **Recovery / Salvage Origin** — when `sourceType` is recovered/salvaged (buyback/source/order links as text, condition grade, lcd/glass, recovered date).
8. **Buyback Allocation** — when `checkedOutToBuybackId` set.
9. **Quality** — condition grade, is OEM, is refurbished.
10. **Warranty** — months, expires, computed status chip (days left / expired).
11. **Notes**.
12. **Activity** — timeline from `inventoryActivity`.

**States:** loading spinner; error with retry; sub-resource failures degrade gracefully (section hidden, main detail still shows). Pull-to-refresh re-runs all loads.

## 9. Cross-platform

- Shared models/services/views compile on iPhone, iPad, Mac.
- Scanner is iOS-only (`#if os(iOS)`); Mac shows the list/detail without the scan button.
- iPad: list uses the existing `AnimatedSplitView` detail-pane pattern (mirror Buyback/Clients) rather than a phone push.

## 10. Testing

- **Unit (decode) tests:** feed captured JSON for list (`meta` pagination + comma-string group fields + Int-bools), detail, activity, groups, external-deployment; assert the quirks decode correctly.
- **XCUITest smoke:** reuse the login-via-Magic-Link + navigate harness from the 2026-07-03 bug fix (build with `ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO`, fresh `-clonedSourcePackagesDirPath`): add Inventory to the tab bar (or open from More) → list loads → open an asset → detail loads. Screenshot each step.
- `npx tsc`-equivalent for Swift: ensure the project builds for the simulator before completion.

## 11. Apple-sync / backend

Phase 1 is **read-only against existing endpoints** → **no backend or web changes ship**. Per the cross-project rule: response shapes were verified against `worker/asset_handlers.js` / `asset_group_handlers.js` / `location_handlers.js`; the only contract subtleties captured above are the `meta` pagination key, comma-joined `group_names`/`group_ids`, Int-booleans, and nullable REAL costs.

## 12. Open items (resolve during planning/implementation)

- Confirm exact JSON of `/api/assets/:id/activity` rows to finalize `AssetActivity` fields.
- Confirm the `productTypes` list item shape used for the product-type filter picker (id/name/sku).
- Decide whether to show group **chips as tappable** in Phase 1 (tapping a group → filtered list) or plain text (recommend plain text; group navigation is Phase 3).
