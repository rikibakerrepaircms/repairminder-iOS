# iOS Inventory — Phase 3: Inventory Groups (Design Spec)

**Date:** 2026-07-03
**Branch:** `feat/ios-inventory-phase3` (off `main`, after Phase 2 merge `1c4e004` + follow-up `9f2f721`)
**Roadmap:** `docs/superpowers/specs/2026-07-03-ios-inventory-ROADMAP.md` → "Phase 3 — Inventory Groups"
**Predecessors:** Phase 1 (`…-phase1-design.md`, browse), Phase 2 (`…-phase2-design.md`, per-asset writes)

## Two standing mandates (adopted after Phase 2)

1. **NOTHING DEFERRED.** This phase delivers the *entire* web Groups subsystem at full parity — see the No-Deferral Checklist below, which maps every web control to an iOS equivalent. The only omission is a capability iOS physically cannot do; there are none here (Dymo label printing is not part of the Groups subsystem).
2. **EVERYTHING TESTED.** Before merge: unit tests (request encoding + response decoding vs **real captured JSON** + view-model mutations + gating), a **live prod E2E of every write** (perform → assert real response shape → hard-delete cleanup via D1), and at least one **XCUITest** driving a new Groups write flow. See the Verification section.

**Zero backend changes** — all 9 endpoints already exist and every handler has been read (`worker/asset_group_handlers.js`, `worker/product_type_handlers.js`).

---

## Goal

Recreate the web Inventory Groups subsystem in the iOS app at full parity. Web reference components:

- `src/components/assets/InventoryGroupsView.tsx` — groups list (search, category filter, has-products / empty-groups toggles, sortable columns, pagination, row actions view/promote).
- `src/components/assets/InventoryGroupDetailModal.tsx` — group detail (header + Edit + Promote, tabs: Member Assets / Linked Products; add-assets search, remove member).
- `src/components/assets/PromoteToProductModal.tsx` — promote a group to a sellable product.
- `src/components/inventory/GroupSelector.tsx` — multi-select group picker with inline create, used on `AssetDetailPage` to manage an asset's groups (persists via bulk-assign).

Phase 1 already shows an asset's groups **read-only** on `InventoryDetailView` (the "Inventory Groups" card, backed by `AssetGroupSummary`). Phase 3 makes that card **editable** and adds the full Groups browsing/management surface.

---

## UX decisions (locked with the user)

| Decision | Choice |
|---|---|
| Groups entry point | **Segmented `Assets` / `Groups` toggle** at the top of the Inventory list, sharing the search bar (mirrors the web `AssetsPage` view-modes). |
| "Manage Groups" selector on asset detail | **Save button** — collect toggles in the sheet, one `POST /api/assets/:id/groups` bulk-assign on Save. |
| Group metadata editing | **Full edit sheet** — name, SKU, category, subcategory, manufacturer, model number, reorder level/qty, default cost/sell price, preferred supplier, OEM/refurbished — via `PUT /api/product-types/:id`. Full parity with the web Edit button. |
| Create-group entry points | **Inline in the selector sheet only** (matches web GroupSelector). No standalone Create button on the Groups list. |

---

## Backend contracts (verified against handlers — re-verify each against real JSON before trusting the model)

All fields are **snake_case** on the wire; the iOS decoder is `.convertFromSnakeCase`, so Swift models use camelCase with **no explicit CodingKeys**. Int-booleans (`is_oem`, `is_refurbished`, `is_active`, `is_required`) arrive as `Int` (0/1) → model as `Int?` + computed `Bool`. Costs are nullable `REAL`.

### 1. `GET /api/asset-groups` — groups list
Query params: `page, limit, search, category, has_products (true|false), unlinked_only (true), sort_by, sort_order (asc|desc), include_archived`.
- `sort_by` whitelist: `name, sku, category, created_at, updated_at, in_stock_count, total_asset_count, linked_product_count, reorder_level, avg_cost` (anything else → `name`).
- `unlinked_only=true` ⇒ `HAVING total_asset_count = 0` ("empty groups"). `has_products=true` ⇒ `linked_product_count > 0`.
Response: `{ success, data: [group], meta: { page, limit, total, totalPages } }`. Each group row:
```
id, name, sku, category, subcategory, manufacturer, model_number,
reorder_level, reorder_quantity, preferred_supplier_name,
default_cost, default_sell_price, is_oem, is_refurbished, is_active,
created_at, updated_at,
in_stock_count, total_asset_count, linked_product_count,
min_cost, avg_cost, max_cost         // aggregates — list only
```

### 2. `GET /api/asset-groups/:id` — group detail
Response: `{ success, data: { …group…, linked_products: [ { id, name, sku, product_kind, quality_tier, quantity_required } ] } }`.
**Note:** detail SELECT **omits** `min_cost/avg_cost/max_cost` and `is_active` (present only on the list) → those model fields must be **optional**. `linked_products` here is a trimmed subset of the `/products` endpoint. 404 `{success:false,error:'Group not found'}` when missing.

### 3. `GET /api/asset-groups/:id/products` — linked products (full)
Response: `{ success, data: [ { id, name, sku, product_kind, category, default_sell_price, vat_rate, quality_tier, quantity_required, is_required } ] }` (ordered by name). Richer than detail's `linked_products`.

### 4. `GET /api/asset-groups/:id/assets` — member assets (paginated)
Response: `{ success, data: [ a.* + location_name + sub_location_code ], meta:{page,limit,total,totalPages} }`. Rows decode straight into the existing **`Asset`** model. **No `membership_id` on these rows** (see remove-member two-step below).

### 5. `POST /api/asset-groups/memberships` — add membership
Body `{ asset_id, group_id }`. Success **201** `{ success, data: { id, asset_id, group_id, company_id, created_by } }`. **409** `{success:false,error:'Asset is already a member of this group'}` on duplicate. 404 if asset missing, 400 if group invalid.

### 6. `DELETE /api/asset-groups/memberships/:id` — remove membership
Success **200** `{ success: true }` (no `data`). 404 if not found. → `requestVoid`.

### 7. `POST /api/assets/:assetId/groups` — bulk-assign asset↔groups
Body `{ group_ids: [String] }` (empty array clears all). Diffs against the asset's current memberships and **propagates the same add/remove across all sibling assets** matched by SKU (else by lowercased name when no SKU). Success **200**:
```
{ success, data: {
    asset_id, groups_added, groups_removed, assets_affected,
    sibling_match: "sku" | "name" | null,
    sku_value: String | null,
    supplier_mappings_updated
} }
```
**Result is nested under `data`** ⇒ decodes with plain `request<BulkAssignGroupsResult>` — **no `requestFull` needed** (unlike Phase 2's edit/allocate envelope siblings). 400 `{error:'Invalid or non-inventory_item group IDs: …'}` if any id is bad.

### 8. `GET /api/assets/:assetId/groups` — an asset's groups (existing, Phase 1)
Response rows include `membership_id` (already modelled as `AssetGroupSummary.membershipId`). Used to (a) render the detail card and (b) resolve a `membership_id` for remove-from-group.

### 9. `POST /api/asset-groups/promote` — promote group → product
Body `{ group_id, product_name, product_sku?, product_category?, default_sell_price?, sell_price_inc_vat?, vat_rate? }`. Success **201**:
```
{ success, data: {
    product:   { id, name, sku, category, product_kind, default_sell_price, vat_rate },
    component: { id, service_product_id, inventory_product_id, quantity_required, is_required }
} }
```
**409** `{error:'A product with that SKU already exists'}` on SKU clash. Missing SKU ⇒ backend auto-generates `PRD-XXXXXXXX`. `sell_price_inc_vat` (if sent) is converted to ex-VAT server-side.

### 10. `POST /api/product-types` — create group (inline in selector)
Body `{ product_kind: "inventory_item", name, category, sku?, … }`. Success **201** `{ success, data: <full product_types row> }` (decodes into `InventoryGroup`; aggregate fields absent → optional). **GOTCHA:** the handler requires a **non-empty `category`** (`if (!body.name || !body.category)` → 400). The web GroupSelector sends `category: ''`, which is a latent bug. **iOS inline create sends `category: "General"` by default** so the create actually succeeds; the user can refine category later via the full Group Edit sheet. Auto-generates SKU when omitted.

### 11. `PUT /api/product-types/:id` — edit group
Body: the editable product-type fields (name, sku, category, subcategory, manufacturer, model_number, reorder_level, reorder_quantity, default_cost, default_sell_price, preferred_supplier_name, is_oem, is_refurbished). Response `{ success, data: <updated row> }` (verify shape/version against real JSON before trusting; confirm whether it returns the full row or a subset).

---

## iOS architecture

Mirror the Phase 1/2 module structure under `Repair Minder/Repair Minder/Features/Staff/Inventory/`.

### Models — `Core/Models/InventoryGroupModels.swift` (new)
All `Decodable, Identifiable, Equatable, Sendable`; camelCase; no CodingKeys; Int-booleans as `Int?` + computed `Bool`; every optional request-struct property `= nil`; struct field order matches labeled call-site order.

- **`InventoryGroup`** — full list+detail row. `id, name, sku?, category?, subcategory?, manufacturer?, modelNumber?, reorderLevel?, reorderQuantity?, preferredSupplierName?, defaultCost?, defaultSellPrice?, isOem: Int?, isRefurbished: Int?, isActive: Int?, createdAt?, updatedAt?, inStockCount?, totalAssetCount?, linkedProductCount?, minCost?, avgCost?, maxCost?, linkedProducts: [LinkedProduct]?` + computed `isOemBool`/`isRefurbishedBool`. (Aggregates + `linkedProducts` optional because different endpoints populate different subsets.) Also decodes the create/edit response row.
- **`LinkedProduct`** — `id, name, sku?, productKind?, category?, defaultSellPrice?, vatRate?, qualityTier?, quantityRequired?, isRequired: Int?` (superset of detail's `linked_products` and `/products`).
- **`GroupMembership`** — `id, assetId, groupId, companyId?, createdBy?`.
- **`BulkAssignGroupsResult`** — `assetId, groupsAdded, groupsRemoved, assetsAffected, siblingMatch: String?, skuValue: String?, supplierMappingsUpdated`.
- **`PromoteResult`** — `product: PromotedProduct`, `component: PromotedComponent` (nested structs matching §9).
- Request structs: `AddMembershipRequest{assetId, groupId}`, `BulkAssignGroupsRequest{groupIds:[String]}`, `PromoteGroupRequest{groupId, productName, productSku?, productCategory?, defaultSellPrice?, sellPriceIncVat?, vatRate?}`, `GroupFormRequest{name, category, sku?, subcategory?, manufacturer?, modelNumber?, reorderLevel?, reorderQuantity?, defaultCost?, defaultSellPrice?, preferredSupplierName?, isOem?, isRefurbished?, productKind: String = "inventory_item"}` (create + edit; encoder `.convertToSnakeCase`).

Reuse existing `Asset`, `AssetGroupSummary` (has `membershipId`), `AssetGroupListItem` (filter picker). Extend/keep those; do not fork.

### Endpoints — `Core/Networking/APIEndpoints.swift` (add cases)
- Extend `assetGroupsList` with `category, hasProducts, unlinkedOnly, sortBy, sortOrder` (build `queryItems`).
- New: `assetGroup(id)` GET, `assetGroupAssets(id, page, limit)` GET, `assetGroupProducts(id)` GET, `addMembership` POST, `removeMembership(id)` DELETE, `bulkAssignGroups(assetId)` POST, `promoteGroup` POST, `createProductType` POST, `updateProductType(id)` PUT. All `requiresAuth == true`. Verify method groupings + line numbers by grepping (don't trust stale numbers).

### Service — `InventoryService.swift` / `InventoryServing` (extend)
`listGroups(page,limit,search,category,hasProducts,unlinkedOnly,sortBy,sortOrder) -> (groups:[InventoryGroup], hasMore:Bool)` (count-heuristic paging: `hasMore = count == limit`), `getGroup(id) -> InventoryGroup`, `getGroupAssets(id,page,limit) -> (assets:[Asset], hasMore:Bool)`, `getGroupProducts(id) -> [LinkedProduct]`, `addMembership(assetId,groupId) -> GroupMembership`, `removeMembership(id) -> Void`, `bulkAssignGroups(assetId,groupIds) -> BulkAssignGroupsResult`, `promoteGroup(_ req) -> PromoteResult`, `createGroup(_ req) -> InventoryGroup`, `updateGroup(id,_ req) -> InventoryGroup`. Reuse existing `getAssetGroups(assetId) -> [AssetGroupSummary]`.
Use `request<T>(_:body:)` for POST/PUT (incl. bulk-assign — nested `data`), `requestVoid` for DELETE. No `requestFull` needed this phase.
**@MainActor init trap:** keep `init(api: APIClient? = nil)` — never a `@MainActor` `.shared` default-arg.

### Views — `Features/Staff/Inventory/`
- **`InventoryListView`** — add a segmented `Picker` (Assets | Groups) at the top; the search text feeds both modes. Groups mode renders `InventoryGroupsListView` embedded (`isEmbedded` — no own NavigationStack; the More stack provides one).
- **`Groups/InventoryGroupsListView.swift`** + **`InventoryGroupsListViewModel.swift`** — search (shared), category filter, "Has products" + "Empty groups" toggles, sort control (name / in-stock / total / linked / reorder / avg-cost × asc/desc), count-heuristic paging. Row: name + SKU (mono) + category chip, colour-coded in-stock count (green / orange ≤ reorder / red 0), total assets, linked-product count, reorder level. Tap → detail. Trailing-swipe / context action → Promote. Filter-change-during-load coalescing like Phase 2.
- **`Groups/InventoryGroupDetailView.swift`** + **`InventoryGroupDetailViewModel.swift`** — header (name/SKU/category/in-stock/total), toolbar **Edit** + **Promote**, already-linked note when `linkedProductCount > 0`. Segmented tabs **Member Assets** | **Linked Products**. Assets tab: "Add Assets" inline search (in-stock only) → `addMembership` (handle 409 "already a member"); member list with per-row **Remove**; paging. Products tab: linked products list (name, SKU, quality tier, qty). Edit → `GroupEditSheet`; Promote → `PromoteToProductSheet`.
  - **Remove-member two-step** (mirrors web; group-assets rows lack `membership_id`): `getAssetGroups(assetId)` → find the entry whose `id == groupId` → `removeMembership(membershipId)`. Document this in code.
- **`Groups/GroupSelectorSheet.swift`** — opened from a new **Manage** button on the `InventoryDetailView` "Inventory Groups" card (makes the Phase-1 read-only card editable). Loads the asset's current groups (`getAssetGroups`) + the group list (`listGroups`, search-as-you-type). Multi-select toggle rows (checkmark + in-stock count), inline "Add new *X*" footer → `createGroup(GroupFormRequest(name: X, category: "General"))` then select it. **Save** → `bulkAssignGroups(assetId, desiredIds)`; on success post `.inventoryAssetDidChange`, dismiss, and surface the sibling-propagation outcome (`assets_affected > 1` ⇒ "Groups updated across N assets with SKU …/same name", else "Groups updated"). Inline error on failure (a parent `.alert` won't present over a sheet).
- **`Groups/PromoteToProductSheet.swift`** — prefilled `name = group.name`, `sku = "PROD-<group.sku>"` (empty if no SKU), `category = group.category`, `sellPrice = group.defaultSellPrice`. Info panel (in-stock count + "creates a sellable product backed by this stock"), already-linked amber warning. Create → `promoteGroup`; map **409**/SKU errors to an inline SKU field error.
- **`Groups/GroupEditSheet.swift`** — full product-type form (name required, category, SKU, subcategory, manufacturer, model number, reorder level/qty, default cost/sell price, preferred supplier, OEM/refurbished toggles). Save → `updateGroup(id, GroupFormRequest(...))`; refresh detail on success.

### Gating — `Groups/GroupActions.swift` (pure, testable)
- `isAssetAddable(_ asset) -> Bool` = `asset.status == .inStock` (add-asset search is in-stock only, per web).
- `alreadyLinked(_ group) -> Bool` = `(group.linkedProductCount ?? 0) > 0` (drives the amber promote/detail warning; promote is always permitted).
- `stockColor(for group)` helper (green/orange/red) reused by list + detail.

### List invalidation
Every mutation that changes an asset's group membership (bulk-assign, add/remove member) posts `.inventoryAssetDidChange`; the assets list + detail already `.onReceive`-reload. The Groups list VM reloads on the same notification (or on `.onAppear`) so counts stay fresh after a mutation.

---

## No-Deferral Checklist (web control → iOS equivalent)

| Web (component) | iOS |
|---|---|
| Groups list: search | shared search bar in Groups mode |
| Groups list: category filter | category filter control |
| Groups list: "Has products" toggle | `hasProducts` toggle |
| Groups list: "Empty groups" toggle | `unlinkedOnly` toggle |
| Groups list: sortable columns (name/in-stock/total/linked/reorder/avg-cost) | sort control with the same fields + asc/desc |
| Groups list: pagination | count-heuristic paging |
| Groups list: row → view detail | tap row → detail |
| Groups list: row → promote | swipe/context → `PromoteToProductSheet` |
| Groups list: stock colour legend | colour-coded in-stock badge |
| Detail: header (name/SKU/category/in-stock/total) | detail header |
| Detail: Edit (ProductTypeForm) | `GroupEditSheet` (full) |
| Detail: Promote | `PromoteToProductSheet` |
| Detail: already-linked warning | amber note |
| Detail: Member Assets tab + paging | Assets tab + paging |
| Detail: Add Assets (in-stock search) | inline add-assets search → `addMembership` |
| Detail: remove member | per-row Remove (two-step membership lookup) |
| Detail: Linked Products tab | Products tab |
| Promote modal (name/sku/category/sell price + warnings) | `PromoteToProductSheet` |
| GroupSelector: multi-select + chips | `GroupSelectorSheet` toggle list |
| GroupSelector: search | search-as-you-type |
| GroupSelector: inline create | "Add new X" → `createGroup` (category "General") |
| GroupSelector: persistence (bulk-assign + sibling toast) | Save → `bulkAssignGroups` + propagation toast |
| Asset detail read-only groups card (Phase 1) | now editable via **Manage** button |

**Intentional exclusions:** none. (Dymo label printing — the one iOS-can't item — is not part of the Groups subsystem; it lives in Phase 4 bulk/labels and was already noted as iOS-incapable in Phase 2.)

---

## Verification (mandatory — all before merge)

### Unit tests (extend the Phase-2 inventory test files where natural)
- **Encoding:** one test per request struct (`AddMembershipRequest`, `BulkAssignGroupsRequest`, `PromoteGroupRequest`, `GroupFormRequest` create + edit) asserting exact snake_case JSON (incl. empty `group_ids` clears; `product_kind: "inventory_item"`; `category: "General"` default on inline create).
- **Decoding vs REAL captured JSON:** `InventoryGroup` from a real `/api/asset-groups` row **and** a real `/api/asset-groups/:id` detail row (proves the missing-aggregate optionals); `LinkedProduct` from real `/products`; `GroupMembership` from a real 201; `BulkAssignGroupsResult` from a real bulk-assign body; `PromoteResult` from a real 201; created/edited `InventoryGroup` row. Capture the JSON with an admin token (admin company `4b63c1e6ade1885e73171e10221cac53` has groups + assets).
- **View-model mutations:** each service call driven through the VM with a mock `InventoryServing` (add/remove member, bulk-assign incl. sibling toast text, promote incl. 409 mapping, create, edit, list filters/sort). 
- **Gating:** `GroupActions.isAssetAddable`, `alreadyLinked`, `stockColor`.

### Live prod E2E of EVERY write (admin token; admin company has groups)
Order: **create group** (`category:"General"`) → **add membership** (real in-stock asset) → **bulk-assign** (toggle a group set on an asset; assert `groups_added/removed/assets_affected/sibling_match/sku_value`) → **promote** (assert `product`+`component`) → **edit group** (`PUT`, assert updated fields) → **remove membership**. For each: perform, assert the live response decodes into the Swift model exactly, then **clean up**.
- **Cleanup (API delete is SOFT):** hard-delete via D1 — the created `product_types` rows (group + promoted product), their `product_components`, all `asset_group_memberships` created, and any `supplier_name_mappings`/`supplier_sku_mappings` the bulk-assign wrote. Verify by `created_at` before deleting; **never delete a row you didn't create** (test names/SKUs can collide with old real rows). Confirm **zero** artifacts remain in the admin **and** demo companies at the end.

### XCUITest (reuse the Phase-2 harness `InventoryEditActionUITest`)
Drive one Groups write end-to-end in the sim: login via Magic Link (demo `appstore-demo@repairminder.com`, code `123456`, company `demo-company-001`) → open an asset → Inventory Groups card → **Manage** → toggle a group → **Save** → assert back on detail with the group shown. Prime the app-wide FAB overlay with a neutral tap (it swallows the first content tap); tap rows by a precise leaf element (asset-tag static text); put `.accessibilityIdentifier` on leaf controls only (never List/wrapper parents). Seed the demo company with an asset + a group via API/D1, run green, then **delete the seed**. `XCTSkip` gracefully when the demo company has no data (CI-safe).

### Builds
iOS scheme green (`iPhone 17 Pro` sim). Confirm the new files add **zero** errors under the "Repair Minder Mac" scheme (ignore the pre-existing unrelated `Signals/` Diagnostics errors — don't touch them). Run `npx tsc`-equivalent N/A (Swift); run tests with `-parallel-testing-enabled NO` + sim by name/UDID.

### Release
Bump `CURRENT_PROJECT_VERSION` 006 → 007.

---

## Cross-project sync gate

These are the app's **own** calls to endpoints that already exist and are consumed by the web app; **no backend changes**. Confirm each request/response shape against the handler (done above) and keep field names snake_case. No new endpoints, no auth/push/portal/deep-link changes. Sync gate: all "no".

---

## Out of scope (Phase 4)

Bulk multi-select actions, stock stats/summary/hierarchy/low-stock, supplier book-in, salvage. The Phase 3 worker produces the Phase 4 worker prompt at the end (`docs/superpowers/PHASE4-WORKER-PROMPT.md`) carrying both mandates forward.
