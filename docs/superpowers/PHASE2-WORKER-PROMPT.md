# Phase 2 Worker Prompt — iOS Inventory (Per-Asset Write Actions)

Copy everything in the fenced block below into a fresh worker/session.

```
You are implementing PHASE 2 of the iOS "Inventory" feature (per-asset write actions) for the RepairMinder iOS app. Phase 1 (browse) is shipped and merged to `main`. Your job: brainstorm it, plan it, build it with subagents, verify it on REAL data, merge it, and hand off Phase 3.

## Read these first (do not skip — they hold the design, conventions, and every gotcha already found)
1. `docs/superpowers/specs/2026-07-03-ios-inventory-ROADMAP.md` — the 4-phase roadmap. Your scope = the "Phase 2" section (write-action endpoint table) + the "Cross-phase conventions" section.
2. `docs/superpowers/specs/2026-07-03-ios-inventory-phase1-design.md` and `docs/superpowers/plans/2026-07-03-ios-inventory-phase1.md` — Phase 1 spec + plan (module structure, model/endpoint/view-model patterns to mirror).
3. The auto-memory note `project_ios_inventory_phase1` (RepairMinder memory dir) — condensed gotchas + the decode-bug lesson.
4. The shipped Phase-1 code under `Repair Minder/Repair Minder/Features/Staff/Inventory/` and `Core/Models/Inventory*.swift` — you EXTEND these (add write methods to `InventoryServing`/`InventoryService`, add actions to `InventoryDetailView`); do not rewrite them.

## Repos & environment
- iOS git root (INNER): `/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS`. Source root `Repair Minder/Repair Minder/`. Tests: `Repair MinderTests` (unit), `Repair MinderUITests` (UI).
- Backend (read-only, for contract verification): `/Users/rikibaker/Repos/repairminder/worker` — `asset_handlers.js` has every write endpoint. ALL endpoints already exist; expect ZERO backend changes, but verify each request/response shape against the handler (rule `.claude/rules/cross-project-sync.md`; snake_case fields, Int-booleans).
- Booted sim "iPhone 17 Pro". Build/test:
  `xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO` (swap `build`→`test -only-testing:...` + `-parallel-testing-enabled NO`). Builds take minutes — don't cancel. If SPM artifacts are stale, run `xcodebuild -resolvePackageDependencies ... -clonedSourcePackagesDirPath /tmp/rm-spm` first.
- The "Repair Minder Mac" scheme has PRE-EXISTING unrelated Diagnostics build errors — don't fix those; only confirm your new files compile.

## Non-negotiable conventions (from Phase 1)
- Networking: shared `APIClient` — `request<T>(_:body:)` for POST/PUT/PATCH with an `Encodable` body; `requestVoid` for DELETE. Encoder is `.convertToSnakeCase`; define small `Codable` request structs with camelCase fields.
- Add endpoints to `APIEndpoint` (case + `path` + `method` group + `queryItems` + default `requiresAuth==true`).
- @MainActor init trap: never use a `@MainActor`-isolated singleton (`APIClient.shared`, `InventoryService()`) as a DEFAULT-ARG value → `init(x: T? = nil) { self.x = x ?? T.shared }`. (SwiftUI View stored-property defaults are fine.)
- Models: no snake_case CodingKeys; write responses return an updated `a.*` row → decode into the existing `Asset`. Reuse `Asset`, don't fork it.
- Views: `isEmbedded` contract (embedded body owns no NavigationStack). Actions = toolbar buttons / sheets on `InventoryDetailView`; refresh detail + invalidate the list after each mutation. Mirror enable/disable rules from web `repairminder/src/pages/AssetDetailPage.tsx` (Deploy only when in_stock; Delete disabled when allocated/deployed; Return-to-stock only when deployed w/ active external deployment; etc.).

## CRITICAL — decode-test against REAL data (this bit Phase 1)
The Apple Review Demo Shop demo account (`appstore-demo@repairminder.com`, Magic-Link login, static 2FA `123456`) has ZERO assets, so it hides decode bugs. Phase 1 shipped a crash (`checked_out_order_number` is an Int, was typed String?) that only appeared on real data. Before trusting any model or a write's response shape:
- Get an admin token (rule `repairminder/.claude/rules/api-tokens.md` + `docs/REFERENCE-test-tokens/CLAUDE.md`; admin company `4b63c1e6ade1885e73171e10221cac53` HAS assets), `curl` a live `/api/assets?limit=100` and the specific write endpoints, and audit every field's JSON type against the Swift model.
- Add fixture decode tests using REAL captured JSON, not synthetic.

## Phase 2 scope (exact bodies/responses in the roadmap's Phase 2 table)
Edit fields (PUT /api/assets/:id, with SKU-propagation warning), Move (POST /move), Deploy/allocate to order (POST /allocate), Change status (PATCH /status), Deploy-external + Return-external, Return-to-supplier + Resolve, Delete (guarded). Surface as edit/move/deploy/status/return/delete sheets + a toolbar on the detail screen; where sensible, list-row swipe actions. Also fold in the Phase-1 follow-up: fix the `guard !isLoading` silent-drop in `InventoryListViewModel` (filter changes during a load must not be dropped).

## Process (in order)
1. `superpowers:brainstorming` — confirm Phase 2 scope/UX with the user, present a design, get approval, write a Phase 2 spec to `docs/superpowers/specs/`.
2. `superpowers:writing-plans` — bite-sized TDD plan to `docs/superpowers/plans/`.
3. `superpowers:subagent-driven-development` — branch `feat/ios-inventory-phase2` off `main`, execute task-by-task with fresh subagents + spec-then-quality review after each (the review gates catch real backend-contract mismatches — take them seriously). Unit-test request encoding + response decoding for every mutation.
4. Verify: iOS build green, unit tests pass, and a runtime mutation smoke — seed an asset via `POST /api/assets` (admin token), exercise edit/move/status/delete, then clean up; or test on a real account and report honestly.
5. `superpowers:finishing-a-development-branch`.

## Handoff (required at the end)
- Append a "Phase 2 complete" note to the ROADMAP doc (commits, what shipped, any NEW gotchas).
- Add a memory note `project_ios_inventory_phase2`.
- Produce a PHASE 3 worker prompt (same shape as this, scoped to the roadmap's Phase 3 = Inventory Groups) and save it to `docs/superpowers/PHASE3-WORKER-PROMPT.md`; note that the Phase 3 worker must in turn produce the Phase 4 prompt.

Start by reading the roadmap + Phase 1 spec, then invoke the brainstorming skill.
```

## Chaining notes (for you, the human)
- Run the phases **sequentially**: each branches from `main` after the previous phase merges (they touch overlapping files — `InventoryServing`, `InventoryDetailView`).
- The roadmap doc is the shared source of truth; each worker appends its "complete" note and emits the next prompt, so the chain is self-propagating (Phase 2 → `PHASE3-WORKER-PROMPT.md` → `PHASE4-WORKER-PROMPT.md`).
