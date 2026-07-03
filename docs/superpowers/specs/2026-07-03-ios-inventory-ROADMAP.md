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

**Web-parity follow-up (merge `9f2f721`, pushed):** closed the remaining gaps — **replacement-asset linking on Resolve** (`ResolveReplacementSheet`: search in-stock by tag/name → Link & Resolve / Resolve Without Link, mirrors web `ReplacementLinkModal`), **edit now clears condition_grade** (sends `""`), **copy asset-tag** button on detail, **Return-to-Supplier disabled-reason** surfaced in the menu, and a testable **`AssetActions`** gating helper. Tests now **34 unit + 1 XCUITest** (added gating + all remaining VM mutations + replacement/clear encoding). **ALL 8 mutations runtime-verified on prod** (edit/move/delete/return-to-supplier/resolve-with-replacement/deploy-external/return-external; **allocate** via a throwaway asset allocated to a real order **by id only** — no line item → no `order_parts` created → order untouched — then hard-deleted from D1; the live envelope decoded exactly as `AllocateResponse`). The allocate handler does NOT validate order existence for the FK path, but `checked_out_to_order_id` has an FK so a real order id is required. **XCUITest** `InventoryEditActionUITest` drives login→Inventory→open asset→actions menu→Edit→change notes→Save→back-on-detail (verified green with a seeded demo-company asset; skips gracefully when the demo company has no asset — CI-safe). Only Dymo label-printing is intentionally skipped (iOS can't). All test data (seeded assets in admin + demo companies) was deleted afterward; the 3 `order_parts` matching test asset-tags were pre-existing real data and left untouched. **Gotcha:** the demo company id is `demo-company-001`, fixed magic-link code `123456`; the app-wide FAB overlay swallows the first content tap, so UI tests must prime with a neutral tap and tap rows by a precise element (asset-tag static text).

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

## Phase 3 — Inventory Groups ✅ SHIPPED 2026-07-03 (merged to `main` + pushed to `origin/main`, 007)

**Delivered:** the ENTIRE web Groups subsystem at full parity — Groups list (search + **category filter** + has-products/empty-groups toggles + 6-field sort), group detail (member-assets + linked-products tabs, add-member search, two-step remove), bulk asset↔group assignment (the Phase-1 read-only Inventory Groups card is now **editable** via a Manage → `GroupSelectorSheet`), inline create-group, promote-to-product, and full group metadata edit. **Zero backend changes** (9 pre-existing endpoints). Spec: `docs/superpowers/specs/2026-07-03-ios-inventory-phase3-design.md`; plan: `docs/superpowers/plans/2026-07-03-ios-inventory-phase3.md`.

**Files:** `Core/Models/InventoryGroupModels.swift`; 9 `APIEndpoint` cases + richer `assetGroupsList`; extended `InventoryServing`/`InventoryService` (10 methods); `Features/Staff/Inventory/Groups/` (`GroupActions`, `InventoryGroupsListView(Model)`, `InventoryGroupDetailView(Model)` + `GroupAddAssetsSheet`, `GroupSelectorSheet`, `PromoteToProductSheet`, `GroupEditSheet`); segmented `Assets`/`Groups` toggle on `InventoryListView`; editable card + `manageGroups`/`siblingMessage` on `InventoryDetailView(Model)`. Shared test double `InventoryServingStub`.

**Commits (branch `feat/ios-inventory-phase3`):** `537db8d` models · `aad5fff` endpoints · `e087d75` service+gating · `dbb5be6` promote sheet · `ed55e14` edit sheet · `8871dca` detail view · `88c4b01` list+toggle · `0275af8` selector+editable card · `3bfc861` **final-review fixes** · `c552c66` XCUITest · `ab6b9e2` version 007.

**Verification (both mandates met):**
- **Unit:** 47 tests green (encode per request struct; decode per model; VM mutations per action; `GroupActions` gating; regression). Models validated against **real prod captures** (list row, detail row w/o aggregates, `/products` superset, membership 201, bulk-assign, promote 201) — shapes matched exactly.
- **Live prod E2E of EVERY write** (admin company `4b63c1e6…`): create group → bulk-assign add/remove (`affected=2, match=sku`) → add membership → **409 duplicate** → promote (`{product,component}`) → edit (PUT, reorder_level persisted) → remove membership. All decoded into the Swift models; **hard-deleted via D1** (memberships, components, mappings, product_types), verified **0** `ZZ-P3-` rows remain in admin AND demo companies. Additive-only (always preserved the asset's existing groups) so no real membership was ever removed.
- **XCUITest** `InventoryGroupsUITest` drove login → Inventory → open asset → **Manage Groups → toggle → Save → back on detail**, PASSED (55.5s) with a seeded demo asset+group; seed deleted; `XCTSkip` when the demo company is empty (CI-safe).
- iOS build green (007); new Phase-3 files add **zero** errors under the Mac scheme (only the pre-existing `Signals/` Diagnostics errors remain).

**Final-review fixes folded in (a read-only reviewer caught these before merge — take the final review seriously):**
- **Category filter** was dead plumbing (VM `category` + `.onChange` existed, no UI) → added a category `Picker` populated from accumulated `knownCategories`.
- **Sibling-propagation toast** (`groupActionMessage`) was computed but never shown → transient bottom toast on the detail view.
- **Promote SKU-clash** matched only `APIError.serverError`, but a real HTTP-409 surfaces as `APIError.httpError(statusCode:409,…)` → now matches `.httpError`/message; the test injected the wrong case (false confidence) → fixed.
- **Group-wipe data-loss guard:** `GroupSelectorSheet` now authoritatively loads the asset's current memberships (`fetchAssetGroups`) and **disables Save until loaded**, so an empty/failed snapshot can never clear an asset's groups (empty `group_ids` = clear-all). Save reports failure inline and only dismisses on success.
- Add-member row only removed on success; search failures no longer masquerade as "no results".

**NEW gotchas (for Phase 4):**
- **`APIError.serverError(message: String, code: String?)`** — `code` is a semantic STRING (e.g. `ACCOUNT_PENDING_APPROVAL`), NOT an HTTP status. Non-2xx HTTP → **`APIError.httpError(statusCode: Int, message: String?)`**. There is NO `userMessage` property — use `error.localizedDescription` (APIError is `LocalizedError`; `serverError`/`httpError` return the server message).
- **`POST /api/assets/:id/groups` bulk-assign returns its result NESTED under `data`** → plain `request<BulkAssignGroupsResult>` (NO `requestFull` this phase). It treats the sent array as the ABSOLUTE desired set (empty clears all) and **propagates add/remove across all SKU-siblings** — never send a partial set built from a possibly-unloaded snapshot.
- **`POST /api/product-types` requires a non-empty `category`** (`if (!body.name || !body.category)` → 400); the web GroupSelector sends `''` (latent bug). iOS inline create sends `category: "General"`.
- `GET /api/asset-groups/:id/assets` rows are `a.*` with **no `membership_id`** → remove-from-group needs the two-step `GET /api/assets/:id/groups` → `membershipId` → DELETE.
- Group **detail** omits `min/avg/max_cost` + `is_active` (list-only) and adds `linked_products[]` → model all as optional.
- Project uses **file-system-synchronized Xcode groups** — new `.swift` files under the source/test roots are auto-included; NO `project.pbxproj` edits needed.
- SwiftUI: a `ForEach` closure with nested `if let` inside `HStack`/`VStack` triggers a phantom "cannot convert […] to Binding" — extract a small row `View` struct.
- Same-stack `navigationDestination(item:)` collisions: the Groups list pushes detail via a DISTINCT `Identifiable` wrapper (`GroupRoute`) so it can't clash with the String-keyed asset-detail destination.
- iOS is a **manual release** — code is on `origin/main` but no build was cut.

---

## Phase 3 — Inventory Groups (original planning)

> **Worker prompt:** `docs/superpowers/PHASE3-WORKER-PROMPT.md`. **Two hard mandates (from Phase 2's lesson of deferring work then circling back): (1) NOTHING DEFERRED — full web-parity for the Groups subsystem in this phase, including making the read-only groups card editable (`GroupSelector`); the only acceptable exclusion is a capability iOS physically can't do, called out and user-confirmed. (2) EVERYTHING TESTED — unit (encode + decode-vs-real-JSON + VM + gating) AND a live prod E2E of EVERY write (seed → verify real response → hard-delete cleanup via D1; API delete is soft) AND at least one XCUITest driving a new Groups write flow. Then merge to `main` and `git push origin main`.**

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

**Verification (mandatory, no shortcuts):** unit tests (request encoding + response decoding against REAL captured JSON + view-model mutations + gating); a LIVE prod E2E of EVERY write (create group, add/remove membership, bulk assign, promote — perform → assert real response shape → clean up, hard-deleting via D1 since API delete is soft, and never deleting a row you didn't create — verify by `created_at`); at least one XCUITest driving a new Groups write flow (reuse the Phase-2 harness: demo `demo-company-001`/code `123456`, prime the FAB overlay, tap by precise element, `XCTSkip` when empty; seed then delete). Confirm zero test artifacts remain in admin AND demo companies.

---

## Phase 4 — Advanced (Bulk, Analytics, Book-in, Salvage) ✅ SHIPPED 2026-07-04 (merged to `main` + pushed to `origin/main`, 008)

**Delivered — full remaining web parity, nothing deferred.** Spec `docs/superpowers/specs/2026-07-03-ios-inventory-phase4-design.md`; plan `…/plans/2026-07-03-ios-inventory-phase4.md`. **Zero backend changes.**

- **4a Bulk / multi-select:** edit-mode `Select` on the assets list (Select-All/Clear/Done) + a floating `BulkActionBar` → Move (per-item `/move` loop), Deploy (in-stock only; order/external loop), Return-to-Supplier (`POST /api/assets/bulk-return-to-supplier`), Export CSV (share sheet), camera **BulkScanSheet** accumulator. `BulkActions` gating. Files under `Features/Staff/Inventory/Bulk/`, `Core/Models/InventoryBulkModels.swift`.
- **4b Analytics:** new `Stock` segment (Assets|Groups|Stock) → sub-tabs **Summary / Hierarchy / Low Stock** (`/stock-summary` array, `/hierarchy`, `/low-stock`), plus a collapsible **LowStockBanner** above the Assets list. Row taps cross-navigate to the filtered Assets list / asset detail. `Features/Staff/Inventory/Stock/`, `Core/Models/InventoryStockModels.swift`.
- **4c Book-in + CSV import + Salvage:** full 4-step supplier-order **book-in wizard** (order details + invoice-PDF AI extract via `extract-invoice` + PDFKit → line items add/**edit**/delete → per-line receive w/ positional serials, chunked-at-20 `POST /api/supplier-orders/:id/receive` → success) from the Inventory toolbar; admin-gated **CSV import** (`POST /api/assets/import` multipart + validation-error report); **SalvageDeviceCard** on `BuybackDetailView` (`POST/DELETE /api/buyback/:id/salvage`, budget-capped, confirm-on-first). `Features/Staff/Inventory/BookIn/`, `Features/Staff/Buyback/Salvage*`, `Core/Models/{SupplierOrderModels,SalvageModels}.swift`. Added `APIClient.uploadMultipartFull` (configurable field name + whole-body decode + raw error body).

**Confirmed exclusions (user-signed-off):** **bulk label printing** only — the web mechanism is a desktop popup + `window.print()` of a QR-label grid; iOS-can't-parity (consistent with the Phase-2 Dymo exclusion). **Non-parity skips (no web UI exists, confirmed unused in `src/`):** `POST /api/assets/bulk` (bulk create), `GET /api/assets/next-tag`, `GET /api/assets/stats`.

**Verification (both mandates met):**
- **Unit:** 97 inventory tests green (44 new Phase-4: encode per request struct; decode per model vs **real prod captures**; VM mutations; `BulkActions`/`SalvageBudgetMath` gating; serial-index regression). New files add **zero** Mac-scheme errors (only the pre-existing `Signals/` Diagnostics errors remain).
- **Live prod E2E of EVERY write** (admin company `4b63c1e6…`): bulk-return-to-supplier, book-in (create order + line + receive), CSV import, salvage POST + DELETE — all decoded exactly into the Swift models; hard-deleted via D1 (assets, supplier_orders/lines, memberships, mappings, product_types, buyback). Verified **0** `ZZ-P4-` rows remain in admin AND demo companies. (Bulk move/deploy reuse the Phase-2 `/move`/`/allocate`/`/deploy-external` endpoints, already prod-verified.)
- **XCUITest** `InventoryBulkUITest`: login → Inventory → tools menu → Book In → create supplier order → asserts advance to Line Items (real `POST /api/supplier-orders`); PASSED 48.8s; demo test order hard-deleted; `XCTSkip` when the toolbar is unreachable (CI-safe).

**Final full-branch review (read-only) caught real issues, fixed before merge (commit `d8fff6f`):** receive `serial_numbers` must be POSITIONAL (was filtering interior blanks → serials landed on the wrong unit); salvage mutations weren't posting `.inventoryAssetDidChange`; bulk-return dismissed before surfacing the server's skipped-assets; extracted `invoice_file_key` was dropped (not attached to the order); `updateOrderLine` was dead (wired line-edit UI); `BulkScanViewModel.lastMessage` unsurfaced; `SupplierOrderLine.unitCost` hardened to `Double?`; CSV export now writes `status.displayName`.

**NEW gotchas (for future work):**
- `navigationDestination(item:)` requires the item be **`Hashable`** (not just `Identifiable`) — carry an id (String) in the route, not the whole model, to avoid a `Hashable` cascade through nested models.
- A recursive SwiftUI tree (hierarchy) needs a **`View` struct that references itself** — a recursive `@ViewBuilder func` triggers "opaque return type defines the opaque type in terms of itself".
- The existing `APIClient.uploadMultipart` hardcodes the file field name `"file"`; `extract-invoice` accepts `file` but `import` REQUIRES field name `csv` → added `uploadMultipartFull` (configurable field, whole-body decode, and it throws `httpError(status, rawBody)` on non-2xx so the CSV-import `validation_failed` body can be decoded).
- Supplier-orders list uses `meta`; supplier-mappings list uses `pagination`; delete-line returns `{success,message}` (no `data`) → `requestVoid`; `extract-invoice` input errors are bare `{error}` (no `success:false`).
- **New in-test mocks should subclass the shared `InventoryServingStub`** — 4 legacy direct conformers were converted to subclasses so adding a protocol method no longer churns every mock.
- iOS is a **manual release** (code on `origin/main`, no build cut).

---

### 🏁 Inventory feature COMPLETE (all 4 phases)

The iOS **Inventory** section is a **full-parity recreation of the web dashboard's `/assets` + `/assets/:id`** surface, delivered across four merged+pushed phases with zero backend changes:

| Phase | Scope | Merge |
|---|---|---|
| 1 | Foundation + full browse (list/detail/filters/scan) | `main` (005/1.0.6) |
| 2 | Per-asset write actions (edit/move/deploy/return/delete) | `1c4e004` (+ `9f2f721`) |
| 3 | Inventory Groups (list/detail/promote/selector) | `7773e99` (007) |
| 4 | Advanced (bulk/multi-select, analytics, book-in, salvage) | this phase (008) |

The only intentionally-excluded web capability is **bulk label printing** (desktop popup-print of QR labels; iOS-can't-parity, user-signed-off in Phases 2 & 4). Everything else the web Inventory surface does is now on iPhone/iPad/Mac. There is no Phase 5.

---

<details><summary>Original Phase 4 planning notes (superseded by the shipped note above)</summary>

> **Worker prompt:** `docs/superpowers/PHASE4-WORKER-PROMPT.md`. Carries BOTH standing mandates (nothing deferred; everything tested incl. live prod E2E of every write + an XCUITest). Phase 4 is the widest and LAST phase — it may sequence internal sub-parts (4a bulk/multi-select, 4b analytics, 4c book-in/salvage) as ordered work WITHIN the phase, but nothing may be punted to a later phase. No Phase 5 to chain.

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

</details>

---

## Handoff protocol (how workers chain)

Each phase is executed by a fresh worker using **brainstorming → writing-plans → subagent-driven-development**, on its own branch `feat/ios-inventory-phaseN`, branched from the previous phase's merged result on `main`.

**Every phase MUST satisfy the two standing mandates (adopted after Phase 2 deferred work and had to be reopened):**
1. **NOTHING DEFERRED** — deliver full web parity for that phase's surface. Scope questions in brainstorming are HOW, never WHETHER to include a web feature. The only acceptable exclusion is a capability iOS physically cannot do, explicitly called out and user-confirmed. Internal sequencing of a wide phase (e.g. 4a/4b/4c) is fine; punting a feature to a later phase is not.
2. **EVERYTHING TESTED** — before merge: unit tests (request encoding + response decoding against REAL captured JSON + view-model + gating); a LIVE prod E2E of EVERY write in the phase (perform → assert real response shape → clean up; API delete is SOFT so hard-delete via D1, and never delete a row you didn't create — verify by `created_at`); and at least one XCUITest driving a new write flow (demo `demo-company-001`/code `123456`; prime the FAB overlay; tap by precise element; `XCTSkip` when empty; seed then delete). Confirm zero test artifacts remain in admin AND demo companies.

At the END of each phase the worker: appends a "Phase N complete" note here (commits, what shipped, live-E2E + XCUITest results, new gotchas) and flips Phase N+1's heading to `(NEXT)`; adds/updates memory `project_ios_inventory_phaseN`; **merges to `main` and pushes `origin/main`** (bump `CURRENT_PROJECT_VERSION`); and produces the next phase's worker prompt (same shape, carrying BOTH mandates forward).
