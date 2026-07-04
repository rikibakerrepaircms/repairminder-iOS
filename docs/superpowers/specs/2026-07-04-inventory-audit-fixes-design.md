# Inventory Audit Fixes — Design Spec

**Date:** 2026-07-04
**Author:** audit-fix sweep (post 4-phase iOS Inventory audit)
**Scope:** Fix **every** finding from the iOS Inventory completeness+function audit, across **both** repos (iOS app and web app), in full. Nothing deferred.

## Context

The 4-phase iOS Inventory feature (browse, per-asset writes, groups, bulk, analytics, book-in, salvage) shipped to `main` and passed a full read-only audit. The audit found the feature substantially complete and correct (106/106 unit tests green; every write contract verified against the live worker), but surfaced **1 high + ~6 medium correctness/parity bugs**, a set of low-severity parity/robustness gaps, dead code, and real test gaps — plus **two currently-red XCUITests** (a harness bug). Several iOS findings have a **twin bug in the web app** (`repairminder/src`); the user directive is to fix iOS **and** web together so both function.

**User decisions (2026-07-04):**
1. **Correctness stance:** fix iOS correctly AND fix the twin web bugs at the same time — both platforms must function.
2. **Verification:** *pragmatic* — unit test per fix + green iOS/Mac build + repair & run the 3 XCUITests; live-prod re-verify only the writes whose payload/behaviour changes.
3. **Delivery:** single phased branch per repo (all scope on one branch each).

## Repos, branches, delivery

- **iOS:** `/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS` — branch `fix/ios-inventory-audit` off `main`. Commits grouped A→F (below). One review, one merge, bump `CURRENT_PROJECT_VERSION` (→ 009), manual release. iOS source root: `Repair Minder/Repair Minder/`; unit tests `Repair Minder/Repair MinderTests/`; UI tests `Repair Minder/Repair MinderUITests/`.
- **Web:** `/Users/rikibaker/Repos/repairminder/src` (worker at `/Users/rikibaker/Repos/repairminder/worker`) — branch `fix/inventory-parity-bugs` off `main`. Deploys via CI on merge to `main` (Pages project `repairminder-dashboard`) — **do NOT build/deploy locally**. Run `npx tsc --noEmit` before every commit.
- The two branches are **independent** (no shared runtime; all fixes reuse existing endpoints — zero backend/worker contract changes). Only one behaviour must agree across platforms: **condition-grade clear** (W5 / NTH-5). Cross-reference the two PRs.

## Verification approach (pragmatic)

Per fix: a unit test (encode/decode/gating as applicable) + green iOS build + green Mac build (**zero new inventory-file errors** beyond the pre-existing `Features/Diagnostics/.../Signals/` errors, which are out of scope). Then:

- **XCUITest harness repaired first** (MF-8) so Edit + Manage-Groups flows can run; run all 3 XCUITests (Bulk, Edit, Groups) — pass or graceful `XCTSkip`, never a hard fail.
- **Live-prod re-verify ONLY behaviour-changed writes:** receive-cap (MF-3), part-recovery payload (MF-6), group-edit blank-field (NTH-1), bulk-deploy date (NTH-6), and the serial-positional fix (web W2). Use admin token per `repairminder/.claude/rules/api-tokens.md` + `docs/REFERENCE-test-tokens/CLAUDE.md` (test existing token first; magic-link → read `magic_link_code` from remote D1 with JSON-on-STDERR `2>&1`; send `User-Agent: curl/8.4.0`). Admin company `4b63c1e6ade1885e73171e10221cac53`. Discipline: `ZZ-FIX-` name/tag prefix, seed → assert real response → **hard-delete via D1** (API delete is soft), never delete a row you didn't create (verify by `created_at`/prefix), confirm **zero** artifacts remain in admin AND demo (`demo-company-001`) companies.
- **Investigate-before-fixing** the two uncertain findings (MF-1, NTH-2) — see their tasks. If either proves a non-issue, the plan records that instead of a change.

Standing conventions all fixes must uphold (from the audit): models `Decodable/Identifiable/Equatable/Sendable`, no `CodingKeys`, `.convertFromSnakeCase`; Int-bools as `Int?`+computed Bool, true JSON bools as `Bool`, money/`SUM()` as `Double?`; `APIError.httpError(statusCode:message:)` for non-2xx vs `serverError(message:code:)` for 200+`success:false`, no `userMessage`; every mutation posts `.inventoryAssetDidChange`; sheets show their own inline error; iOS-only APIs `#if os(iOS)`-guarded.

---

## iOS work — grouped by commit

### Group A — Cross-cutting (land first; unblocks the rest)

**MF-2 · MEDIUM · BUG (app-wide) — surface server error message on the main `request<T>` path.**
`Core/Networking/APIClient.swift:201` — the default (non-401/404) non-2xx branch throws `httpError(statusCode:, message: nil)` without reading the body's `error` field (unlike `requestFull`/`uploadMultipart`).
*Fix:* in the default branch, attempt to decode `APIResponse<EmptyResponse>` (or a minimal `{error}` struct) from the response body and pass its `error`/`message` as `httpError`'s `message` (mirror the multipart path). Preserve status code.
*Test:* unit test injecting a 409 body `{"success":false,"error":"Asset is already a member of this group"}` → assert `APIError.httpError(409, "Asset is already…")` and that `localizedDescription` contains the server text.

**MF-8 · MEDIUM · TEST-BUG — repair the two red XCUITests' unguarded prime tap.**
`Repair MinderUITests/InventoryEditActionUITest.swift:46` and `InventoryGroupsUITest.swift:47` call `app.staticTexts["Inventory"].firstMatch.tap()` unconditionally; the element is absent after navigating in, so both hard-fail before reaching their intended `XCTSkip`.
*Fix:* wrap each in `let t = app.staticTexts["Inventory"].firstMatch; if t.exists { t.tap() }` — matching the guarded pattern already in `InventoryBulkUITest`.
*Verify:* run all 3 XCUITests; each passes or `XCTSkip`s gracefully (empty demo company).

**MF-5 · MEDIUM · DECODE-RISK (latent, Phase-1 class) — make `Asset.status` null-tolerant.**
`Core/Models/Inventory.swift:10` — `status: AssetStatus` decodes via `UnknownDefaultable.init` which calls `decode(String.self)` and throws on JSON `null`; schema is `status TEXT DEFAULT 'in_stock'` (nullable). One null row blanks the whole list decode.
*Fix:* decode `status` defensively — e.g. `decodeIfPresent` → `.unknown` fallback (either make the stored property optional with a non-optional computed accessor, or add a null-tolerant `UnknownDefaultable` decode path used here). Keep the public `status` non-optional for call sites.
*Test:* decode a list fixture containing one row with `status: null` → whole array decodes, that row → `.unknown`.

### Group B — Browse / list

**MF-1 · HIGH · BUG/PARITY-GAP — asset product-type filter uses the wrong endpoint variant. (INVESTIGATE FIRST.)**
`Core/Networking/APIEndpoints.swift:863` (`.productTypes(search:)` hardcodes `product_kind=product,service`, `limit=10`) consumed by `Features/Staff/Inventory/AssetFilterSheet.swift:74`. Web calls `/api/product-types` with `is_active=true, limit=50`, no `product_kind`. Assets key on `a.product_type_id`, often `inventory_item`-kind.
*Investigate:* curl `/api/product-types?search=<part>&limit=50&is_active=true` vs the app's current variant against the admin company; confirm inventory-item kinds are excluded/truncated by the current call.
*Fix (if confirmed):* add a dedicated `APIEndpoint.assetFilterProductTypes(search:)` emitting `search`, `is_active=true`, `limit=50`, no `product_kind`; point `InventoryService.fetchProductTypes` at it. **Do not** change the shared `.productTypes` case (Booking/Orders depend on it).
*Test:* endpoint queryItems unit test (asserts params); VM test that fetch populates from the new case.

**MF-4 · MEDIUM · BUG — `loadMore()` not coalesced against reloads (pagination/filter race).**
`Features/Staff/Inventory/InventoryListViewModel.swift:79` — guarded only by `hasMore`/`isLoadingMore`, not `isLoading`/`pendingReload`. Scroll-to-last then change filter → stale page-2 appends onto a reset list, corrupts `currentPage`.
*Fix:* capture the active query (status/search/filters) at `loadMore` entry; before appending, bail if `isLoading` is true or the captured query != current. Let `loadAssets` win.
*Test:* deterministic gated test — start `loadMore`, mutate filter mid-flight, assert the stale page is discarded and cursor not corrupted (mirror the existing Phase-2 coalescing test).

**NTH-3 · LOW-MED · PARITY-GAP (recurring) — searchable, uncapped group/part pickers.**
`AssetFilterSheet.swift:68` (group filter, cap 100, no search) and `Features/Staff/Buyback/SalvageDeviceCard.swift:51` (salvage part picker, cap 100, no search).
*Fix:* add a debounced search field wired to the existing `fetchGroups(search:)` / `assetGroupsList(search:)` param (the product-type section in the same sheet already does this). Applies to both call sites.
*Test:* VM/search wiring test that a search term reaches the service call.

**NTH-10a · LOW · PARITY-GAP — list row omits serial / SKU / condition grade.**
`InventoryListView.swift:348` (`AssetRow`). Web card/table show serial, SKU, coloured grade badge.
*Fix:* add serial (`asset.serialNumber`), SKU (`asset.sku`), and a condition-grade badge to `AssetRow` when present.

**NTH-10b · LOW · PARITY-GAP — "N found" totals.**
`InventoryListViewModel.swift` and `Features/Staff/Inventory/Groups/InventoryGroupsListViewModel.swift` discard pagination `meta.total`.
*Fix:* capture `meta.total` (add an envelope-sibling decode via the existing paginated path) and surface a "N assets/groups found" line in `InventoryListView` / `InventoryGroupsListView`.

### Group C — Detail writes

**MF-7 · MEDIUM · BUG — detail loses joined fields after every mutation.**
`Features/Staff/Inventory/InventoryDetailViewModel.swift:49` — `applyUpdated` sets `asset = resp.data`, but mutation handlers return join-less `SELECT *` (no `location_name`, `product_type_name`, `checked_out_*`, `enable_part_recovery`). After Move the Location rows blank; after Edit the Product Type disappears and `enablePartRecoveryBool` flips false (breaks a subsequent Deploy→Order part-recovery in the same session).
*Fix:* after any mutation, re-fetch the full asset via `service.fetchAsset(id:)` (the joined `/api/assets/:id` read) instead of trusting `resp.data`; fold this into `refreshSubResources` (or a new `refreshAsset`). Keep the optimistic `resp.data` as an immediate update, then reconcile with the refetch.
*Test:* VM test — mock a mutation returning a join-less asset, assert the VM ends with the joined asset (mock `fetchAsset` returns the full row).
*Twin:* **W1** (web `AssetDetailPage.tsx`).

**MF-6 · MEDIUM · PARITY-GAP (data quality) — part-recovery LCD/glass not screen-gated + silently defaulted.**
`Features/Staff/Inventory/Actions/PartRecoveryForm.swift:11` — toggles render for all categories, default `lcdWorking=true`/`glassCracked=false`, always emitted. Web shows them only for "screen" categories and treats recovery as invalid until both are explicitly answered.
*Fix:* gate the LCD/glass toggles on a screen-category check (match web's category test); make them un-answered by default and require explicit answers (nil → block Allocate / omit from payload otherwise). Non-screen recoveries must not send `lcd_working`/`glass_cracked`.
*Test:* `toInput()` unit tests — screen category requires both answers and emits them; non-screen omits them.

**NTH-4 · LOW · BUG — allocate error double-surfaces after cancelling the deploy wizard.**
`Features/Staff/Inventory/Actions/DeployToOrderWizard.swift:34` (Cancel) and `DeployChooserSheet.swift:38` (Cancel) don't reset `viewModel.actionError`; the inline error re-presents as the detail `.alert`.
*Fix:* set `viewModel.actionError = nil` in both Cancel actions (matching every other sheet).

**NTH-5 · LOW · BUG/STYLE — condition-grade clear behaviour + wrong comment.**
`Features/Staff/Inventory/Actions/AssetEditSheet.swift:100` — always sends `conditionGrade` incl. `""` (so "Not set" clears), but the comment claims "matches web" and web omits `""` (preserves).
*Canonical decision:* clearing SHOULD work — when the user picks "Not set", the grade clears. iOS keeps sending `""`; **fix the misleading comment**. Web is changed to match (W5).
*Test:* keep `testUpdateAssetSendsEmptyConditionGradeToClear`; add an assertion that the comment/behaviour is intentional.
*Twin:* **W5**.

**NTH-1 · LOW-MED · BUG — GroupEditSheet can't blank an optional field.**
`Features/Staff/Inventory/Groups/GroupEditSheet.swift:45` — empty text → `nil` → JSONEncoder omits → clearing SKU/subcategory/manufacturer/model/supplier is a silent no-op (web sends `""`). Same class as the Phase-2 edit-clears-condition fix.
*Fix:* send `""` (not `nil`) for user-cleared string fields so the worker's partial-update applies the clear. (Verify the worker applies `""` for these fields; if a field can't be blanked server-side, note it.)
*Test:* encode test — a field set to empty emits `""`, not omitted.

**NTH-3-followup (GroupSelector onAppear race, Groups audit F3):** `GroupSelectorSheet.swift:58` `.onAppear { selected = Set(initialSelection) }` races the authoritative `.task` load. No data-loss (Save gated), but drop the seed or gate it `if !didLoadSelection`.
*Fix:* remove/guard the onAppear seed.

### Group D — Book-in

**MF-3 · MEDIUM · BUG/DATA-INTEGRITY — receive allows over-receiving.**
`Features/Staff/Inventory/BookIn/BookInWizardView.swift:243` — stepper bound `0...max(line.quantityOrdered, 1)`; should be `line.remaining`. Partially-received line → excess assets, `total_received > total_items`.
*Fix:* bound to `0...max(line.remaining, 1)`; cap the serial `ForEach` to the same. (`remaining = quantityOrdered - quantityReceived`.)
*Test:* VM/gating test — a line ordered 10 / received 4 caps receive qty at 6.
*Live-prod re-verify:* seed a supplier order + partial receive, confirm you can't exceed remaining.

**NTH-9 · LOW · ROBUSTNESS — "Receive More" reuses stale drafts; chunked receive non-atomic.**
`BookInWizardView.swift:291` — sets `step=.receive` without reseeding drafts (compounds MF-3); a retry after a mid-batch failure re-sends already-received chunks (double-receive; error is surfaced).
*Fix:* re-run `prepareReceive()` (reseed drafts from current line state) on "Receive More". Document the non-atomic retry caveat; optionally track which chunks succeeded to avoid re-sending on retry.

**NTH-8 · LOW · PARITY-GAP — receive has no sub-location picker; line editor lacks product-type/group linking.**
`BookInWizardView.swift:243` (receive step) and the line editor. Backend auto-links on receive, so functional.
*Fix:* add a sub-location picker to the receive step (reuse the filter-sheet picker; default from the line). Line-editor product-type/group linking is deferred-safe *only if truly unused by web flow* — but per "include everything", add a product-type link field to the line editor (optional) mirroring web `BookInForm`; if scope-heavy, split into its own commit but do not drop.

**NTH-11 · LOW · GATING — "Import CSV" menu item visible to non-admins.**
`Features/Staff/Inventory/InventoryListView.swift:321` — sheet content + worker both gate correctly, but the entry shows for non-admins.
*Fix:* hide the menu entry unless `AuthManager.shared.currentUser?.role.isAdmin` (keep the in-sheet guard as defense-in-depth).

**Book-in import decode alignment (Book-in audit F6):** `AssetImportRowError` models `sku`/`error` the worker never sends; the worker sends `field`.
*Fix:* align `Core/Models/SupplierOrderModels.swift:185` to the worker shape — add `field: String?`, keep `message`; drop or document `sku`/`error`. Update `.display` to include `field` when present.
*Test:* decode a real `validation_failed` row `{row, field, message}`.

**Book-in cancel semantics (Book-in audit §5):** iOS cancel uses PATCH `status=cancelled` while web/worker offer `DELETE` (hard-deletes empty orders), leaving empty cancelled orders in D1.
*Fix:* for an order with zero received lines, call `DELETE /api/supplier-orders/:id` (matching web); otherwise PATCH cancel. `SupplierOrderListViewModel.swift:40`.

### Group E — Bulk / salvage / analytics polish

**NTH-6 · LOW · PARITY-GAP — bulk deploy-external omits deployment date.**
`Features/Staff/Inventory/Bulk/BulkDeploySheet.swift:112` — builds `DeployExternalRequest` without `deploymentDate` (model field exists). Web defaults to today.
*Fix:* add a date field to the external view (default today), pass `deploymentDate`.
*Live-prod re-verify:* bulk external-deploy records the chosen date.

**Bulk deploy / wizard "no line item" (Bulk F2 / Writes F3):** `BulkDeploySheet.swift:74` and `DeployToOrderWizard.swift:71` allow allocate with no line item; web requires one. Worker accepts null `order_item_id` (Phase-2 used this intentionally for id-only allocate).
*Decision:* align to web — require a selected line item to proceed in both the single and bulk deploy-to-order flows (removes the "None"/"no specific line item" paths). Note the worker still supports id-only for programmatic use.
*Fix:* remove the no-line-item option; disable "Deploy" until a line item is chosen.

**CSV export status column (Bulk F3):** `Features/Staff/Inventory/Bulk/CSVExporter.swift:16` writes `status.displayName` ("In Stock"); web writes raw `status` ("in_stock").
*Decision:* keep iOS's human-readable `displayName` for the user-facing export; add a header comment documenting the intentional cross-platform divergence. (No web change — web export is a separate audience.) If exact cross-platform byte-parity is desired later, revisit.

**NTH-7 · LOW · PARITY-GAP — LowStockBanner shown only in the Assets segment.**
`InventoryListView.swift:91` — web shows the panel above hierarchy/summary too.
*Fix:* render `LowStockBanner` inside `Features/Staff/Inventory/Stock/InventoryStockView.swift` (Summary/Hierarchy sub-tabs) as well; keep the dedicated Low Stock sub-tab.

**NTH-12 · LOW · DECODE-RISK — `SalvageResponse.assets:[Asset]` forces a decode `book()` never reads.**
`Core/Models/SalvageModels.swift:24` — a full-`Asset` decode after the worker already created assets/flipped status; a field drift throws a false failure.
*Fix:* make `assets` `[Asset]?` (or remove it — `book()` uses only `salvagedAssets`).

**NTH-2 · LOW-MED · BUG (uncertain) — scanner passes raw QR/URL string. (INVESTIGATE FIRST.)**
`Features/Staff/Inventory/InventoryScannerSheet.swift:84` → `fetchAssetByTag(rawValue)` (single-lookup `InventoryListView.swift:337` and `BulkScanViewModel.onScan`). Web extracts the tag from a scanned URL via `parseAssetScanUrl`.
*Investigate:* determine whether RM asset labels QR-encode a URL (check label-printing code / a real label). Single-lookup reportedly works in prod → likely plain tags.
*Fix (if URLs possible):* add a Swift `parseAssetScanUrl` (extract the tag segment from `…/assets/tag/<TAG>` or query) and apply before `fetchAssetByTag` in both scan paths.
*Test:* parser unit test (URL and raw-tag inputs both yield the tag).

**Salvage polish (Salvage audit F2/F4/F5/F6/F8):**
- `SalvageDeviceCard.swift:122` — salvaged-asset rows link to the asset detail (`NavigationLink`/`navigationDestination` → `InventoryDetailViewModel(assetId:)`).
- `SalvageDeviceCard.swift:123` — show `location_name` on booked rows.
- `SalvageDeviceCard.swift:113` — over-budget label includes `abs(remaining)` ("Over budget by £X").
- `SalvageDeviceCard.swift:79` — sub-location label composes `code — description` (match web).
- `SalvageDeviceCard.swift:126,85` — disable the specific remove button while its DELETE is in flight and Add while `booking` (track `removingId`).
- (Optional) `SalvageDeviceCard.swift:116` — empty-state text "No parts salvaged from this device yet."

**Analytics polish:** LowStockBanner default-collapsed vs web default-expanded is deliberate mobile condensation — **no change** (documented). Decoded-but-unrendered analytics fields — see Group F.

### Group F — Dead code + test-gap closure

**Dead-code pruning (remove — truly unused, not needed for decode):**
- `Bulk/BulkViewModels.swift:94-95,130-131` — `BulkMoveViewModel`/`BulkDeployViewModel` `successCount`/`failureCount`.
- `Buyback/SalvageBudget.swift:9` — `SalvageBudgetMath.spent(booked:pending:)`.
- `Groups/GroupActions.swift:6` — `GroupActions.isAssetAddable` (either wire as a client guard in `GroupAddAssetsSheet` or delete; prefer delete since server filters).
- `BookIn/BookInWizardViewModel` — unused `init(order:)` + `seed(from:)` (preview/test-only path).
- `Actions/ReturnToSupplierSheet.swift:26-31,53` — unreachable no-supplier branch (menu already gates). Remove or leave a one-line defensive comment.

**Decoded-but-unused model fields — resolve each (wire into UI where it adds parity, else keep as a documented contract mirror):**
- `Core/Models/InventoryBulkModels.swift:20` `SupplierReturnBatch.batches` — keep (needed for clean decode); optionally show per-supplier confirmation. Document as mirror.
- `Core/Models/SalvageModels.swift:45` `SalvageBudgetInfo` (dup of `BuybackInventory.SalvageBudget`) — collapse to one type.
- `Core/Models/InventoryGroupModels.swift:30` `InventoryGroup.linkedProducts` — keep as mirror (detail sources products via `/:id/products`); document.
- `Core/Models/InventoryWriteModels.swift:118` `DeployExternalData.deployment` — keep as mirror; document.
- `Core/Models/SupplierOrderModels.swift:90,93-94` `ReceiveItemInput.unitCost/isOem/isRefurbished` — either populate from the receive UI (parity with web receive form) or remove; prefer populate (adds parity).
- `SalvageResponse.newStatus/.assets/.salvageBudget`, `DeleteSalvageResult.booked/.revertedTo` — keep as mirrors; optionally use `revertedTo`/`newStatus` for a toast/local state. Document.
- `HierarchyAsset.locationName`, `LowStockBuckets`, `ProductTypeOption.sku` — keep as mirrors; `ProductTypeOption.sku` may be surfaced as a picker sublabel (parity).

**Test-gap closure (new tests):**
- `BuybackListViewModel` + `BuybackDetailViewModel` — decode + view-logic tests (currently 0).
- Invoice-AI book-in path — test `BookInWizardViewModel.applyExtraction`/`submitOrderDetails` carrying `invoice_file_key` (the View `InvoiceUploadView` is UI-only; test the VM).
- `DeployToOrderWizard` — a multi-step flow test (order search → line item → confirm → allocate) at the VM level.
- `SupplierOrderListViewModel` — list decode + client-side status-filter test.
- `.inventoryAssetDidChange` posting — assert every write VM (edit/move/delete/return*/allocate/deployExternal/salvage book+remove) posts it (extend `InventoryWriteViewModelTests`).
- Plus the per-fix tests listed under each finding above.

**Mac scheme:** confirm the full sweep adds **zero** new inventory-file errors under the `Repair Minder Mac` scheme (only the pre-existing `Signals/` errors remain).

---

## Web work — branch `fix/inventory-parity-bugs` (twins)

**W1 · AssetDetailPage re-fetch after mutation** (twin of MF-7). `src/pages/AssetDetailPage.tsx` — replace `setAsset(response.data)` after each mutation with a re-fetch of the joined `/api/assets/:id` (or merge joined fields), so Location/Product-Type/part-recovery flags don't blank. Verify against `src/services/inventoryApi.ts`.

**W2 · BookInPage positional serials** (real web data-corruption). `src/pages/BookInPage.tsx` (~L908) — the receive payload does `serial_numbers?.filter(sn => sn.trim())`, compacting the array so serials shift onto the wrong unit. Build an index-aligned array of exactly `quantity` slots (blanks → empty/null), matching the fixed iOS `buildReceiveInputs`. **Highest-priority web fix** (data integrity).

**W3 · GroupSelector real category on create** (web 400 bug). `src/components/inventory/GroupSelector.tsx` (~L135) — create sends `category: ''`; `POST /api/product-types` requires non-empty `category` (400). Send a real default (e.g. `"General"`, matching iOS).

**W4 · StockSummaryView child-row aggregate fallback** (web blank cells). `src/components/assets/StockSummaryView.tsx` (~L112 area) — child rows read `aggregate_in_stock`/`aggregate_*` which the worker only sets on parents → blank cells. Fall back to the row's own `in_stock_count`/`allocated_count`/`total_count` when aggregates are absent (mirror iOS `displayInStock`/`displayAllocated`).

**W5 · Condition-grade clear alignment** (twin of NTH-5). `src/pages/AssetDetailPage.tsx` — currently sends `condition_grade: value || undefined` (omits `""`, so "Not set" can't clear). Change to send an explicit `""` when the user selects "Not set", so clearing works and matches iOS. Confirm the worker applies `""`.

Web verification: `npx tsc --noEmit` green before each commit; the receive-serial fix (W2) re-verified against a seeded supplier order on prod (same admin-token discipline); commit + push, CI deploys. Do not build/deploy locally.

---

## Out of scope (explicitly)

- The pre-existing `Features/Diagnostics/.../Signals/` Mac-scheme errors (unrelated; documented).
- Signed-off exclusions remain excluded: bulk label printing, PATCH `/api/assets/:id/status`, Dymo print, and the unused `POST /api/assets/bulk` / `/next-tag` / `/stats` endpoints.
- Grid/table view toggle and desktop-only affordances (shift-select) — deliberate mobile condensation; LowStockBanner default-collapsed on mobile.

## Success criteria

- Every audit finding above is fixed or (for MF-1/NTH-2) resolved by investigation with a recorded outcome.
- iOS: `Repair Minder` scheme builds green; full inventory unit suite green (existing 106 + new tests); all 3 XCUITests pass or graceful-skip; Mac scheme adds zero new inventory errors.
- Web: `tsc --noEmit` green; twins W1–W5 fixed; W2 (serials) re-verified on prod.
- Behaviour-changed writes (MF-3, MF-6, NTH-1, NTH-6, W2) re-verified live-prod with `ZZ-FIX-` discipline and zero leftover artifacts in admin + demo companies.
- iOS version bumped (→ 009); both PRs cross-reference each other.
