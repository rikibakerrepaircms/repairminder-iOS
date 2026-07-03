# iOS Inventory — Full-Parity Roadmap (Phases 1-4)

**Goal:** recreate the web dashboard's Inventory/Assets section (`/assets`, `/assets/:id`) in the iOS app at full parity, delivered in four sequenced phases. Each phase plugs into the Phase-1 foundation and gets its own spec → plan → subagent-driven build.

**Repos:** iOS `repairminder-iOS/repairminder-iOS` (source root `Repair Minder/Repair Minder/`); backend `repairminder/worker` (`asset_handlers.js`, `asset_group_handlers.js`, `location_handlers.js`/`sub_location_handlers.js`, `product_type_handlers.js`, `buyback_salvage_handlers.js`). **All Inventory endpoints already exist on the backend** — every phase is expected to ship with ZERO backend changes (verify each write's request/response against the handler before coding, per `.claude/rules/cross-project-sync.md`).

**Web reference:** `repairminder/src/pages/AssetsPage.tsx`, `AssetDetailPage.tsx`, `src/components/assets/*`, `src/components/inventory/GroupSelector.tsx`, `src/services/inventoryApi.ts`, `src/services/assetGroupsApi.ts`.

---

## Cross-phase conventions (learned in Phase 1 — do not re-derive)

- **Networking:** shared `APIClient` (`request<T>` / `requestVoid`), NOT Buyback's hand-rolled URLSession. Add write endpoints to `APIEndpoint` (case + `path` + `method` group + `queryItems` + default `requiresAuth==true`). For POST/PUT/PATCH, pass an `Encodable` body to `request(_:body:)`; the encoder is `.convertToSnakeCase`.
- **Models:** `Decodable, Identifiable, Equatable, Sendable`; NO explicit snake_case `CodingKeys` (global `.convertFromSnakeCase`); Int-booleans as `Int?` + computed `Bool`; enums use `UnknownDefaultable`. Reuse the existing `Asset` model — write responses return an updated `a.*` row that decodes straight into `Asset`.
- **`@MainActor` init trap:** never use `@MainActor`-isolated singletons (`APIClient.shared`, `InventoryService()`) as a **default-arg value**. Use `init(x: T? = nil) { self.x = x ?? T.shared }`. (SwiftUI `View` stored-property defaults are fine — Views are MainActor-isolated.)
- **Navigation:** feature views use the `isEmbedded` pattern — `embeddedBody` must NOT create its own `NavigationStack` (the More tab provides one). Detail is pushed via `navigationDestination(item: $selectedAssetId)`.
- **Reused infra:** `Location` + `.locations`/`.locationSubLocations`/`.productTypes` endpoints; `AssetSubLocationOption` (id/code/description — NOT the clashing `SubLocationOption` in DeviceDetail.swift); `CurrencyFormatter.format`; `AnimatedSplitView`; the scanner's `CameraPreviewView`.
- **Backend quirks:** assets-list pagination is under `meta` (we ignore it, use `hasMore = count == pageSize`); `group_names`/`group_ids` are comma-joined strings; categories endpoint returns `{categories:[{category,count}], suggested:[]}`; `asset_activity_log` columns are `activity_type`/`performed_at`; **`checked_out_order_number` is an Int** (the linked order's ticket_number), NOT a String — got this wrong in P1 and it crashed the list decode on any allocated asset.
- **Decode verification (LEARNED THE HARD WAY):** the empty demo account hid a real decode bug (an allocated asset's Int order-number vs a String? field) until the user hit it on real data. ALWAYS decode-test against REAL captured JSON: `curl` a live `/api/assets?limit=100` with an admin token (see `repairminder/docs/REFERENCE-test-tokens/CLAUDE.md` + `.claude/rules/api-tokens.md`), audit every field's JSON type against the Swift model, and add a fixture test — don't rely on synthetic JSON or the empty demo account.
- **Verification:** unit-test model decode against captured JSON; verify each write endpoint's exact request/response shape against the worker handler; build iOS (`iPhone 17 Pro` sim) AND note the Mac scheme (it has PRE-EXISTING unrelated Diagnostics build errors — don't try to fix those); browse/mutation smoke via XCUITest reusing the Magic-Link demo login (`appstore-demo@repairminder.com`, static 2FA `123456`). NOTE: the Apple Review Demo Shop company has **zero assets**, so runtime-verifying anything data-dependent (detail, edits) needs a seeded asset or a real account.
- **Known follow-ups to fold in:** (1) filter-change-during-load is silently dropped in `InventoryListViewModel` (`guard !isLoading`) — fix opportunistically; (2) detail screen never runtime-verified with data.

---

## Phase 1 — Foundation + Full Browse ✅ SHIPPED 2026-07-03 (merged to `main`, 1.0.6/005)

**Delivered:** models (`Core/Models/Inventory.swift`, `InventoryEnums.swift`), `Features/Staff/Inventory/` (InventoryService, list+detail view models, list view, filter sheet, self-contained AVFoundation scanner, detail view, status helpers), 8 read endpoints, opt-in `FeatureTab.inventory` (overflow-only). Browse-only: status pills + full filter set (category/location/sub-location/product-type/group/unassigned/no-products) + search + count-heuristic paging + scan-to-find + detail with all read sections + activity/groups/external-deployment. 12 unit tests; iOS+Mac build clean; browse smoke passes.

**Endpoints used (all GET):** `/api/assets`, `/api/assets/:id`, `/api/assets/tag/:tag`, `/api/assets/:id/activity`, `/api/assets/:id/groups`, `/api/assets/:id/external-deployment`, `/api/product-types/categories`, `/api/asset-groups` (+ reused `/api/locations`, `/api/locations/:id/sub-locations`, `/api/product-types`).

**Key files:** `InventoryService.swift` (`InventoryServing` protocol — extend it per phase), `InventoryListView.swift`/`InventoryDetailView.swift` (add actions here), `InventoryListViewModel.swift`/`InventoryDetailViewModel.swift`.

**Post-merge fixes (already on `main`):**
- `fix(inventory): Swift 6 — InventoryService.init avoids @MainActor .shared default arg` — `init(api: APIClient? = nil)` (default-arg couldn't reference `@MainActor` `.shared`).
- `fix(inventory): checked_out_order_number is Int, not String` — the real `/api/assets` decode crashed on any allocated/deployed asset (invisible on the empty demo account; user hit it on real data). Now `Int?` + regression test.

Current `main` tip for this feature is at/after commit `2df09af`.

---

## Phase 2 — Per-Asset Write Actions ✅ SHIPPED 2026-07-03 (merged to `main`, merge commit `1c4e004`)

**Delivered:** every single-asset mutation from web `AssetDetailPage`, on `InventoryDetailView`. Spec: `docs/superpowers/specs/2026-07-03-ios-inventory-phase2-design.md`; plan: `docs/superpowers/plans/2026-07-03-ios-inventory-phase2.md`. **Zero backend changes.**

- **Actions:** Edit (PUT, with SKU/category-propagation warning + `sku_updated_count` toast), Move (POST /move), Deploy chooser → **full To-Order wizard** (order search → line-item → confirm → optional `PartRecoveryForm`, via /allocate) + External deploy (/deploy-external), Return-to-Stock (/return-external), Return-to-Supplier (/return-to-supplier) + Resolve on the pending-return banner (/resolve-supplier-return, credit/replacement), guarded Delete (DELETE). Toolbar `Menu` + contextual controls; guarded trailing swipe-delete on list rows. Gating mirrors web exactly.
- **Decision (differs from the table below):** **status-change (PATCH /status) was intentionally OMITTED** to match web (web detail has no status control — status changes flow through allocate/deploy/return). Resolve lives on the detail banner (no separate Returns screen). Smart prompts are informational only (SKU-count toast + ready-to-repair note; no order deep-linking).
- **Networking:** added `APIClient.requestFull<R>` (+ private `performRequestData`) to capture envelope-sidecar fields (`sku_updated_count`, `prompt_ready_to_repair`) that the shared `APIResponse<T>` drops. Everything else uses `request`/`requestVoid`. New `Core/Models/InventoryWriteModels.swift` (request + custom response structs + `.inventoryAssetDidChange` name). Extended `InventoryServing`/`InventoryService`, `InventoryDetailView(Model)`, `InventoryListView(Model)`, `APIEndpoints`.
- **Phase-1 follow-up folded in:** `InventoryListViewModel.loadAssets()` now coalesces a filter/search change made during an in-flight load (was dropped by `guard !isLoading`), with a deterministic gated test.
- **List invalidation:** any mutation posts `.inventoryAssetDidChange`; the list's `.onReceive` reloads.

**Commits (on `main` via merge `1c4e004`):** `5e9d957` request structs, `36995aa` response structs, `76ffed7` endpoints, `41425d0` requestFull, `32847aa` service methods, `083aa77` detail-VM + coalescing, `020f0db` write-action UI, `31afc38` review fixes.

**Verification:** iOS build green (iPhone 17 Pro); **22 inventory unit tests pass** (encode + decode-against-real-contract + VM mutations + gated coalescing); runtime smoke against **prod** (admin company `4b63c1e6…`) confirmed the edit envelope decodes as `EditAssetResponse` (`{data, sku_updated_count:Int, success}`), and move/delete contracts (`{success,data}` / `{success,message}`); Mac scheme — new files compile clean (only the pre-existing `Signals/` Diagnostics errors remain, untouched).

**NEW gotchas (for later phases):**
- `sku_updated_count` / `prompt_ready_to_repair` / `prompt_view_order` are **envelope siblings of `data`** — the shared `APIResponse<T>` silently drops them; use `APIClient.requestFull<R>` (decodes the whole body) for those endpoints.
- SKU-category propagation only fires when the category actually **changes** AND the asset has a non-null SKU (`sku_updated_count` is 0 otherwise).
- **`Order` model uses `orderNumber` (Int, non-optional), NOT `ticketNumber`; `OrderStatus` display is `.label` NOT `.displayName`; `OrderItem.description` is non-optional and there is NO `name` field.** The `.orderItems` endpoint is unused/unverified — load line items via the verified `request<Order>(.order(id:))` path and read `order.items`.
- Delete blocks with **HTTP 400** (not 409) when `checked_out_to_order_id`/`checked_out_to_device_id` is set.
- Swift's synthesized memberwise init defaults **optionals to nil**, but request structs still need explicit `= nil` so partial-argument call sites compile; struct field order must match the labeled-argument order used at call sites.
- SwiftUI: a parent `.alert` won't present over an active `.sheet` — sheets must show their own inline error (fixed in review).

**Remaining (deferred, non-blocking):** condition-grade can't be *cleared* to empty via edit (Codable omits nil rather than sending `""`); Return-to-Supplier menu item has no disabled-reason text (iOS menus lack tooltips). `main` is ahead of `origin/main` (not pushed — iOS ships via manual release).

---

## Phase 2 (original planning table)

**Delivers:** every single-asset mutation from the web `AssetDetailPage`, surfaced as toolbar buttons / action sheets on `InventoryDetailView` (and where sensible, swipe actions on list rows). All refresh the detail/list on success.

**Features & backend endpoints (all exist; verify shapes in `worker/asset_handlers.js`):**
| Action | Endpoint | Request body | Response |
|---|---|---|---|
| Edit fields | `PUT /api/assets/:id` | `{serial_number,name,sku,category,manufacturer,model_number,supplier_name,supplier_order_reference,purchase_date,cost,cost_inc_vat,warranty_months,warranty_expires,condition_grade,is_oem,is_refurbished,location_id,sub_location_id,notes}` (subset) | `{success,data:<updated a.*>,sku_updated_count}` — WARN: editing SKU/category propagates to sibling assets with same SKU |
| Move | `POST /api/assets/:id/move` | `{location_id, sub_location_id?}` | `{success,data:<a.*>}` |
| Deploy/allocate to order | `POST /api/assets/:id/allocate` | `{order_id?, device_id?, deploy?, recovery?}` | `{success,data,prompt_ready_to_repair,allocated_parts,device,recovered_asset}` |
| Change status | `PATCH /api/assets/:id/status` | `{status}` | `{success,data,pending_order,prompt_view_order}` |
| Deploy (external customer) | `POST /api/assets/:id/deploy-external` | `{customer_name?,external_reference?,notes?,deployment_date?}` | `{success,data:{asset,deployment}}` |
| Return from external | `POST /api/assets/:id/return-external` | `{deployment_id, return_to_stock?, notes?}` | `{success,data}` |
| Return to supplier | `POST /api/assets/:id/return-to-supplier` | `{supplier_return_reason, supplier_return_notes?}` | `{success,data:<a.*>}` |
| Resolve supplier return | `POST /api/assets/:id/resolve-supplier-return` | `{resolution:'credit_received'|'replacement_received', replacement_asset_id?}` | `{success,data}` |
| Delete | `DELETE /api/assets/:id` | — | `{success,message}` — blocked (409/400) if allocated/deployed |

**iOS work:**
- Extend `InventoryServing`/`InventoryService` with the write methods above (each returns the updated `Asset` or void). Add the `APIEndpoint` cases (POST/PUT/PATCH/DELETE) with `Encodable` request bodies (define small `Codable` request structs, snake_case-encoded automatically).
- Add action sheets/sheets: `AssetEditSheet` (form mirroring web `EditFormData` — name/serial/sku/category/condition/warranty/notes/OEM/refurb + SKU-propagation warning), `AssetMoveSheet` (location + sub-location pickers, reuse the filter-sheet pickers), `AssetDeploySheet` (order/device or external customer), `AssetStatusSheet`, `AssetReturnToSupplierSheet` + resolve, delete confirmation.
- `InventoryDetailView` toolbar: Edit / Deploy (when `in_stock`) / Return-to-Supplier (when set + not pending) / Move / Delete (guarded) / status. Mirror the enable/disable rules from `AssetDetailPage.tsx` (e.g. Deploy only `in_stock`; Delete disabled when allocated/deployed; Return-to-Stock when `deployed` with an active external deployment).
- Refresh detail (`viewModel.refresh()`) and invalidate the list after any mutation.

**Apple-sync gate:** these are the app's OWN write calls; no new backend endpoints. But confirm each request/response shape against the handler and keep field names snake_case.

**Verification:** unit tests for request-body encoding + response decoding of each mutation (mock `InventoryServing`); a runtime mutation smoke test needs a seeded asset (create one via `POST /api/assets` with a token for the demo company, exercise edit/move/status, then delete it — leave the demo account clean) OR test on a real account.

---

## Phase 3 — Inventory Groups (NEXT)

**Delivers:** the Groups subsystem from the web `InventoryGroupsView` / `InventoryGroupDetailModal` / `PromoteToProductModal` / `GroupSelector`.

**Features & endpoints (in `asset_group_handlers.js`):**
| Feature | Endpoint | Notes |
|---|---|---|
| Groups list | `GET /api/asset-groups` (have it) | add sort/filter params (has_products, unlinked_only, sort_by) |
| Group detail | `GET /api/asset-groups/:id` | aggregate row + nested `linked_products[]` |
| Group's member assets | `GET /api/asset-groups/:id/assets` | paginated `a.*` |
| Group's linked products | `GET /api/asset-groups/:id/products` | |
| Add membership | `POST /api/asset-groups/memberships` | `{asset_id, group_id}` → `{success,data:{...}}`, 409 on dup |
| Remove membership | `DELETE /api/asset-groups/memberships/:id` | |
| Assign asset↔groups (bulk) | `POST /api/assets/:id/groups` | `{group_ids:[...]}` (empty clears); propagates across SKU siblings; returns `{groups_added,groups_removed,assets_affected,sibling_match,...}` |
| Create group | `POST /api/product-types` | body `{product_kind:'inventory_item', name, sku?, category?, ...}` |
| Promote to product | `POST /api/asset-groups/promote` | `{group_id, product_name, product_sku?, product_category?, default_sell_price?, ...}` → creates a `product` + component |

**iOS work:**
- New models: `InventoryGroup` (full — reuse/extend `AssetGroupListItem`/`AssetGroupSummary`), `LinkedProduct`, `GroupMembership`, `PromoteResult`, `BulkAssignGroupsResult`.
- Extend `InventoryServing` with group CRUD + promote + assign.
- Views: a **Groups** entry (either a segmented mode on the Inventory list or a row in the More/Inventory area) → `InventoryGroupsListView` → `InventoryGroupDetailView` (member assets + linked products tabs, add/remove members) → `PromoteToProductSheet`; and a `GroupSelectorSheet` reachable from `InventoryDetailView`'s Inventory Groups card (Phase 1 shows groups read-only — Phase 3 makes it editable via assign).
- Wire the detail-view "manage groups" affordance to `POST /api/assets/:id/groups`.

**Verification:** model decode tests; group-assign request/response tests; runtime needs seeded assets+groups.

---

## Phase 4 — Advanced (Bulk, Analytics, Book-in, Salvage)

**Delivers:** the remaining web surface — bulk actions, rollup views, supplier book-in, salvage.

**Features & endpoints:**
| Feature | Endpoint(s) |
|---|---|
| Bulk create | `POST /api/assets/bulk` |
| Bulk return-to-supplier | `POST /api/assets/bulk-return-to-supplier` |
| Bulk move/deploy/labels/export | client-side selection + per-item or bulk endpoints; CSV export `GET /api/assets/export` |
| CSV import | `POST /api/assets/import` (multipart) |
| Stock stats | `GET /api/assets/stats` (`by_status`, `by_category`, low-stock alerts, totals) |
| Stock summary / hierarchy / low-stock | `GET /api/assets/stock-summary`, `/hierarchy`, `/low-stock` |
| Next tag | `GET /api/assets/next-tag` |
| Book-in (supplier orders) | supplier-order handlers + `POST /api/assets` |
| Salvage (buyback-scoped) | `POST /api/buyback/:id/salvage`, `DELETE /api/buyback/:id/salvage/:assetId` (in `buyback_salvage_handlers.js`) |

**iOS work:** multi-select on the list (edit-mode) driving bulk sheets; a Stock Summary view (counts + total value by status/category, from `/stats` or `/stock-summary`); low-stock surfacing; book-in flow; salvage entry (likely surfaced from the Buyback detail, cross-linking to inventory). Scope carefully — Phase 4 is the widest; consider splitting into 4a (bulk + multi-select), 4b (analytics views), 4c (book-in + salvage) during its own brainstorm.

**Verification:** decode tests for stats/summary; bulk request encoding tests; runtime with seeded data.

---

## Handoff protocol (how workers chain)

Each phase is executed by a fresh worker using **brainstorming → writing-plans → subagent-driven-development**, on its own branch `feat/ios-inventory-phaseN`, branched from the previous phase's merged result on `main`. At the END of each phase, the worker appends a "Phase N complete" note here (commits touched, what shipped, any new gotchas) and hands off by producing the next phase's worker prompt (same shape as the Phase 2 prompt in the session that created this file). Update the `project_ios_inventory_phase1` memory (or add `project_ios_inventory_phaseN`) with outcomes.
