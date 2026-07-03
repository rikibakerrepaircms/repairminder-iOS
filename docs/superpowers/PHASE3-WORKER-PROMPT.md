# Phase 3 Worker Prompt — iOS Inventory: Inventory Groups

> Paste the block below to a fresh worker to execute Phase 3. It is the same shape as the Phase 2 prompt that produced this file. **The Phase 3 worker MUST, at the end, produce the Phase 4 worker prompt** (`docs/superpowers/PHASE4-WORKER-PROMPT.md`) — see the Handoff section.

---

You are implementing PHASE 3 of the iOS "Inventory" feature (Inventory Groups) for the RepairMinder iOS app. Phases 1 (browse) and 2 (per-asset write actions) are shipped and merged to `main`. Your job: brainstorm it, plan it, build it with subagents, verify it on REAL data, merge it, and hand off Phase 4.

## Read these first (do not skip — they hold the design, conventions, and every gotcha already found)
1. `docs/superpowers/specs/2026-07-03-ios-inventory-ROADMAP.md` — the 4-phase roadmap. Your scope = the "Phase 3 — Inventory Groups" section (endpoint table) + the "Cross-phase conventions" section + the "Phase 2 complete" NEW-gotchas block.
2. `docs/superpowers/specs/2026-07-03-ios-inventory-phase2-design.md` + `docs/superpowers/plans/2026-07-03-ios-inventory-phase2.md` — Phase 2 spec + plan (the module/model/endpoint/view-model/sheet patterns to mirror; how write actions + `requestFull` were done).
3. `docs/superpowers/specs/2026-07-03-ios-inventory-phase1-design.md` + plan — Phase 1 foundation.
4. The auto-memory notes `project_ios_inventory_phase1` and `project_ios_inventory_phase2` (RepairMinder memory dir) — condensed gotchas.
5. The shipped code under `Repair Minder/Repair Minder/Features/Staff/Inventory/` (list/detail/Actions/, `InventoryServing`/`InventoryService`) and `Core/Models/Inventory*.swift` — you EXTEND these (Phase 1's detail already shows groups read-only; Phase 3 makes them editable + adds a Groups browsing/management surface). Do not rewrite them.

## Repos & environment
- iOS git root (INNER): `/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS`. Source root `Repair Minder/Repair Minder/`. Tests: `Repair MinderTests`.
- Backend (read-only, for contract verification): `/Users/rikibaker/Repos/repairminder/worker` — `asset_group_handlers.js` has every group endpoint (9 CRUD + `promote-to-product` + `generateGroupSku()`), and `POST /api/assets/:id/groups` (bulk assign, propagates across SKU siblings) lives in `asset_handlers.js`. ALL endpoints already exist; expect ZERO backend changes, but verify each request/response shape against the handler (rule `.claude/rules/cross-project-sync.md`; snake_case fields, Int-booleans, comma-joined strings).
- Web reference: `repairminder/src/components/inventory/InventoryGroupsView.tsx`, `InventoryGroupDetailModal.tsx`, `PromoteToProductModal.tsx`, `GroupSelector.tsx`, `src/services/assetGroupsApi.ts`.
- Booted sim "iPhone 17 Pro". Build/test (do NOT cancel — builds take minutes; run builds in the FOREGROUND with `| tail`, never background them):
  `xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO` (swap `build`→`test -only-testing:...` + `-parallel-testing-enabled NO`). If SPM artifacts are stale, run `xcodebuild -resolvePackageDependencies … -clonedSourcePackagesDirPath /tmp/rm-spm` first.
- The "Repair Minder Mac" scheme has PRE-EXISTING unrelated Diagnostics build errors in `Signals/` — don't fix those; only confirm your new files compile (no NEW errors).

## Non-negotiable conventions (from Phases 1–2 — do not re-derive)
- Networking: shared `APIClient` — `request<T>(_:body:)` for POST/PUT/PATCH with an `Encodable` body; `requestVoid` for DELETE; **`requestFull<R>`** when you need envelope-level fields the shared `APIResponse<T>` drops. Encoder is `.convertToSnakeCase`; define small `Codable` request structs with camelCase fields.
- Add endpoints to `APIEndpoint` (case + `path` + `method` group + `queryItems` + default `requiresAuth==true`). Verify current line numbers by grepping — don't trust stale numbers.
- @MainActor init trap: never use a `@MainActor`-isolated singleton (`APIClient.shared`, `InventoryService()`) as a DEFAULT-ARG value → `init(x: T? = nil) { self.x = x ?? T.shared }`. (SwiftUI View stored-property defaults are fine.)
- Models: `Decodable, Identifiable, Equatable, Sendable`; NO snake_case CodingKeys (global `.convertFromSnakeCase`); Int-booleans as `Int?` + computed `Bool`; enums use `UnknownDefaultable`. Reuse the existing `Asset`, `AssetGroupSummary`, `AssetGroupListItem` — extend, don't fork. Swift memberwise inits default optionals to nil but request structs still need explicit `= nil`, and struct field order must match labeled call-site order.
- Views: `isEmbedded` contract (embedded body owns no NavigationStack). Mirror Phase 2's sheet/action patterns; show inline errors in sheets (parent `.alert` won't present over a sheet). Post `.inventoryAssetDidChange` after any mutation that changes an asset's groups so the list/detail refresh.

## CRITICAL — decode-test against REAL data (this bit Phase 1 AND is the standing rule)
The Apple Review Demo Shop demo account (`appstore-demo@repairminder.com`, Magic-Link, static 2FA `123456`) has ZERO assets/groups, so it hides decode bugs. Before trusting any model or a write's response shape:
- Get an admin token (rule `repairminder/.claude/rules/api-tokens.md` + `docs/REFERENCE-test-tokens/CLAUDE.md`; admin company `4b63c1e6ade1885e73171e10221cac53` HAS assets AND groups). To mint one: request magic link → read `magic_link_code` from remote D1 (`cd worker; set -a; source ../.env.local; set +a; export CLOUDFLARE_EMAIL=$REPAIRMINDER_CF_EMAIL CLOUDFLARE_API_KEY=$REPAIRMINDER_CF_GLOBAL_KEY CLOUDFLARE_ACCOUNT_ID=$REPAIRMINDER_CF_ACCOUNT_ID; npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email='rikibaker+admin@gmail.com'" 2>&1 | grep magic_link_code`) → exchange via `/api/auth/magic-link/verify-code`. **wrangler `--json` prints to STDERR** (`2>&1`), and update the token file after.
- `curl` live `/api/asset-groups`, `/api/asset-groups/:id`, `/api/asset-groups/:id/assets`, `/api/asset-groups/:id/products`, and a real `POST /api/assets/:id/groups` response, and audit every field's JSON type against the Swift model. Add fixture decode tests using REAL captured JSON.

## Phase 3 scope (exact endpoints in the roadmap's Phase 3 table — verify each in `asset_group_handlers.js`)
- Groups list `GET /api/asset-groups` (add sort/filter params: `has_products`, `unlinked_only`, `sort_by`) — Phase 1 already has a minimal `assetGroupsList`; extend it.
- Group detail `GET /api/asset-groups/:id` (aggregate row + nested `linked_products[]`).
- Group member assets `GET /api/asset-groups/:id/assets` (paginated `a.*` → reuse `Asset`).
- Group linked products `GET /api/asset-groups/:id/products`.
- Add membership `POST /api/asset-groups/memberships` `{asset_id, group_id}` (409 on dup); Remove `DELETE /api/asset-groups/memberships/:id`.
- Bulk assign asset↔groups `POST /api/assets/:id/groups` `{group_ids:[…]}` (empty clears; propagates across SKU siblings; returns `{groups_added, groups_removed, assets_affected, sibling_match, …}` — likely envelope-level, may need `requestFull`).
- Create group `POST /api/product-types` `{product_kind:'inventory_item', name, sku?, category?, …}`.
- Promote to product `POST /api/asset-groups/promote` `{group_id, product_name, product_sku?, product_category?, default_sell_price?, …}` → creates a `product` + component.

## iOS work (mirror Phase 2 structure)
- New models: `InventoryGroup` (full detail — extend `AssetGroupSummary`/`AssetGroupListItem`), `LinkedProduct`, `GroupMembership`, `PromoteResult`, `BulkAssignGroupsResult`.
- Extend `InventoryServing`/`InventoryService` with group CRUD + promote + bulk-assign methods.
- Views: a **Groups** entry (a segmented mode on the Inventory list, or a row in the More/Inventory area) → `InventoryGroupsListView` → `InventoryGroupDetailView` (member-assets + linked-products tabs, add/remove members) → `PromoteToProductSheet`; and a `GroupSelectorSheet` reachable from `InventoryDetailView`'s Inventory Groups card (Phase 1/2 show groups read-only — Phase 3 makes them editable via bulk-assign). Wire the detail-view "manage groups" affordance to `POST /api/assets/:id/groups`.
- Surface the SKU-sibling propagation warning/result (like Phase 2's edit `sku_updated_count`).

**Apple-sync gate:** app's OWN calls, no new backend endpoints — but confirm each request/response shape against the handler and keep field names snake_case. Fill in the `.claude/rules/cross-project-sync.md` sync-gate table.

## Process (in order)
1. `superpowers:brainstorming` — confirm Phase 3 scope/UX with the user (e.g. Groups as a segmented mode on the list vs a separate entry; create-group + promote-to-product inclusion), present a design, get approval, write a Phase 3 spec to `docs/superpowers/specs/`.
2. `superpowers:writing-plans` — bite-sized TDD plan to `docs/superpowers/plans/`.
3. `superpowers:subagent-driven-development` — branch `feat/ios-inventory-phase3` off `main`, execute task-by-task. NOTE (learned in Phase 2): subagents that BACKGROUND their multi-minute xcodebuild stall the loop — instruct implementers to run builds/tests in the FOREGROUND and not return until committed, or drive the mechanical/coupled tasks directly with the same TDD discipline (failing test → implement → passing test → foreground build → per-task commit). Do a spec-then-quality review (a single independent read-only reviewer running both lenses in order is an acceptable, faster substitute for two separate review agents), and a final full-branch review before merge — take its findings seriously; Phase 2's final review caught a silent data-loss bug (a sheet clearing a seeded field) and silent sheet write-failures that a happy-path smoke missed. Unit-test request encoding + response decoding for every mutation, against REAL captured JSON.
4. Verify: iOS build green, unit tests pass, and a runtime smoke — create a group (`POST /api/product-types`), add/remove a membership against a real asset, capture the bulk-assign response, then clean up; or test on a real account and report honestly. Confirm the Mac scheme new files compile (ignore pre-existing `Signals/` errors).
5. `superpowers:finishing-a-development-branch` — merge to `main` (local merge matches how Phases 1–2 shipped; iOS is a manual release, so do NOT push origin unless the user asks).

## Handoff (required at the end)
- Append a "Phase 3 complete" note to the ROADMAP doc (commits, what shipped, any NEW gotchas) and flip Phase 4's heading to `(NEXT)`.
- Add/update a memory note `project_ios_inventory_phase3` (link `[[project_ios_inventory_phase2]]`).
- Produce a PHASE 4 worker prompt (same shape as this one, scoped to the roadmap's Phase 4 = Advanced: bulk actions/multi-select, stock stats/summary/hierarchy/low-stock, book-in, salvage; note Phase 4 is the widest and the roadmap suggests splitting into 4a/4b/4c during its own brainstorm) and save it to `docs/superpowers/PHASE4-WORKER-PROMPT.md`. Phase 4 is the last phase, so its prompt need not chain a Phase 5.

Start by reading the roadmap + Phase 2 spec/plan + the two memory notes, then invoke the brainstorming skill.
