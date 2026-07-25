# Inventory Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every finding from the 4-phase iOS Inventory audit, in both the iOS app and the web app, so both platforms function correctly and stay at parity.

**Architecture:** Two independent branches. iOS (`fix/ios-inventory-audit`, Tasks 1–30) is grouped A→F: cross-cutting → browse → detail-writes → book-in → bulk/salvage/analytics → dead-code/tests. Web (`fix/inventory-parity-bugs`, Tasks 31–35) carries the five twin bugs. No worker/backend contract changes — every fix reuses existing endpoints. Spec: `docs/superpowers/specs/2026-07-04-inventory-audit-fixes-design.md`.

**Tech Stack:** iOS — Swift 6, SwiftUI, XCTest + Swift Testing, xcodebuild (sim "iPhone 17 Pro"). Web — TypeScript, React, Vite, `tsc --noEmit`. Backend — Cloudflare Worker (read-only reference).

**Conventions (apply to every task):**
- Models: `Decodable, Identifiable, Equatable, Sendable`; NO `CodingKeys` (global `.convertFromSnakeCase`); Int-bools as `Int?`+computed Bool; true JSON bools as `Bool`; money/`SUM()` as `Double?`.
- Errors: `APIError.httpError(statusCode:message:)` for non-2xx; `serverError(message:code:)` for 200+`success:false`; no `userMessage`.
- Every asset mutation posts `.inventoryAssetDidChange`; sheets show their own inline error; iOS-only APIs `#if os(iOS)`-guarded.
- TDD: write the failing test, watch it fail, implement minimally, watch it pass, commit. All commit messages end with:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

**Standard test runner** (substitute `<TESTID>`):
```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -parallel-testing-enabled NO ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO \
  -only-testing:"Repair MinderTests/<TESTID>" 2>&1 | tail -40
```
Run xcodebuild in the FOREGROUND with `| tail`; never background it.

**Confirm the branch before Task 1:**
```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS" && git rev-parse --abbrev-ref HEAD
# expected: fix/ios-inventory-audit  (already created; the design spec commit is on it)
```

---

# GROUP A — Cross-cutting (land first)

## Task 1: MF-2 — surface server error message on the `request<T>` path

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIClient.swift:~201` (the `performRequest` default non-2xx branch)
- Test: `Repair Minder/Repair MinderTests/APIClientErrorTests.swift` (create)

- [ ] **Step 1: Read the current error-handling switch.** Open `APIClient.swift` around lines 180–210 and around the `requestFull`/`uploadMultipart` body-decoding at ~281 to copy the existing "decode `error` from body" pattern. Note the exact helper used to read the server `error` string.

- [ ] **Step 2: Write the failing test.**
```swift
import XCTest
@testable import Repair_Minder

final class APIClientErrorTests: XCTestCase {
    func testNon2xxSurfacesServerErrorMessage() throws {
        let body = #"{"success":false,"error":"Asset is already a member of this group"}"#.data(using: .utf8)!
        // mapErrorBody mirrors the extraction used in performRequest's default branch.
        let msg = APIClient.serverErrorMessage(from: body)
        XCTAssertEqual(msg, "Asset is already a member of this group")
    }
}
```

- [ ] **Step 3: Run it — expect FAIL** (`serverErrorMessage` undefined). Runner `<TESTID>` = `APIClientErrorTests/testNon2xxSurfacesServerErrorMessage`.

- [ ] **Step 4: Implement.** Add a small static helper on `APIClient` and use it in the default branch:
```swift
static func serverErrorMessage(from data: Data) -> String? {
    struct Body: Decodable { let error: String?; let message: String? }
    let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
    let b = try? d.decode(Body.self, from: data)
    return b?.error ?? b?.message
}
```
Then in the `default` non-2xx branch (currently `throw APIError.httpError(statusCode: http.statusCode, message: nil)`) change to:
```swift
throw APIError.httpError(statusCode: http.statusCode, message: APIClient.serverErrorMessage(from: data))
```
(Use the response body variable name already in scope.)

- [ ] **Step 5: Run test — expect PASS.**

- [ ] **Step 6: Commit.**
```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIClient.swift" "Repair Minder/Repair MinderTests/APIClientErrorTests.swift"
git commit -m "fix(inventory): surface server error text on request<T> non-2xx path (MF-2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 2: MF-8 — guard the XCUITest prime tap

**Files:**
- Modify: `Repair Minder/Repair MinderUITests/InventoryEditActionUITest.swift:46`
- Modify: `Repair Minder/Repair MinderUITests/InventoryGroupsUITest.swift:47`

- [ ] **Step 1: Read the guarded pattern** in `InventoryBulkUITest.swift` (the `if invTitle.exists { invTitle.tap() }` block).

- [ ] **Step 2: Apply the guard.** In both files, replace the unguarded line:
```swift
app.staticTexts["Inventory"].firstMatch.tap()
```
with:
```swift
let invTitle = app.staticTexts["Inventory"].firstMatch
if invTitle.exists { invTitle.tap() }
```

- [ ] **Step 3: Run the 3 XCUITests** (they build the UI target; expect PASS or graceful `XCTSkip`, no hard fail):
```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -parallel-testing-enabled NO ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO \
  -only-testing:"Repair MinderUITests/InventoryEditActionUITest" \
  -only-testing:"Repair MinderUITests/InventoryGroupsUITest" \
  -only-testing:"Repair MinderUITests/InventoryBulkUITest" 2>&1 | tail -50
```
Expected: no test reports a hard failure at the prime-tap line.

- [ ] **Step 4: Commit.**
```bash
git add "Repair Minder/Repair MinderUITests/InventoryEditActionUITest.swift" "Repair Minder/Repair MinderUITests/InventoryGroupsUITest.swift"
git commit -m "fix(inventory): guard XCUITest prime tap so empty-demo skips gracefully (MF-8)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 3: MF-5 — make `Asset.status` null-tolerant

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Models/Inventory.swift:10` (+ a custom `init(from:)` or a decode helper)
- Test: `Repair Minder/Repair MinderTests/InventoryModelTests.swift` (add a method)

- [ ] **Step 1: Write the failing test** (add to `InventoryModelTests`):
```swift
func testAssetStatusNullDecodesToUnknownAndListSurvives() throws {
    let json = #"""
    [{"id":"a1","asset_tag":"AST-1","name":"Part","status":null},
     {"id":"a2","asset_tag":"AST-2","name":"Part2","status":"in_stock"}]
    """#.data(using: .utf8)!
    let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
    let assets = try d.decode([Asset].self, from: json)
    XCTAssertEqual(assets.count, 2)
    XCTAssertEqual(assets[0].status, .unknown)
    XCTAssertEqual(assets[1].status, .inStock)
}
```

- [ ] **Step 2: Run — expect FAIL** (throws on `null`). `<TESTID>` = `InventoryModelTests/testAssetStatusNullDecodesToUnknownAndListSurvives`.

- [ ] **Step 3: Implement.** Give `Asset` an explicit decode for `status` only (keep the property non-optional). Add a memberwise-preserving `init(from:)` OR, simpler, decode via a null-tolerant path. Minimal approach — add to `Asset`:
```swift
init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: GenericCodingKeys.self)
    // ... decode every existing property with c.decode/decodeIfPresent ...
    if let raw = try c.decodeIfPresent(String.self, forKey: .init("status")) {
        self.status = AssetStatus(rawValue: raw) ?? .unknown
    } else {
        self.status = .unknown
    }
}
```
If hand-writing `init(from:)` for the whole model is too broad, instead change the stored property to `private let statusRaw: String?` decoded via `decodeIfPresent`, plus `var status: AssetStatus { statusRaw.flatMap(AssetStatus.init(rawValue:)) ?? .unknown }`, and update the ~1–2 call sites. Prefer whichever keeps the diff smallest while keeping `status` a non-optional `AssetStatus` at call sites. (`GenericCodingKeys` — reuse the project's existing dynamic key type if present; grep for it. If none exists, use the property-level `statusRaw` approach to avoid introducing one.)

- [ ] **Step 4: Run test — expect PASS.**

- [ ] **Step 5: Full inventory-model suite** to catch regressions: `<TESTID>` = `InventoryModelTests`.

- [ ] **Step 6: Commit.**
```bash
git add "Repair Minder/Repair Minder/Core/Models/Inventory.swift" "Repair Minder/Repair MinderTests/InventoryModelTests.swift"
git commit -m "fix(inventory): Asset.status tolerates null, never fails the list decode (MF-5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

# GROUP B — Browse / list

## Task 4: MF-1 — asset product-type filter endpoint (INVESTIGATE, then fix)

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift:~863`
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift` (`fetchProductTypes`)
- Test: `Repair Minder/Repair MinderTests/InventoryEndpointTests.swift` (create or extend)

- [ ] **Step 1: Investigate.** Mint an admin token (see spec verification block). Compare the two variants against the admin company:
```bash
# current app variant (product_kind=product,service, limit 10):
curl -s "https://api.repairminder.com/api/product-types?search=&limit=10&product_kind=product,service" \
  -H "Authorization: Bearer <TOKEN>" -H "User-Agent: curl/8.4.0" | jq '.data | length, (.data[0]|keys)'
# web/asset variant (is_active, limit 50, no product_kind):
curl -s "https://api.repairminder.com/api/product-types?search=&limit=50&is_active=true" \
  -H "Authorization: Bearer <TOKEN>" -H "User-Agent: curl/8.4.0" | jq '.data | length, ([.data[].product_kind]|unique)'
```
Confirm the asset variant returns `inventory_item` kinds that the current variant excludes. **If not confirmed** (asset filter works fine with the shared case), record that in the plan checkbox and SKIP Steps 2–6.

- [ ] **Step 2: Write the failing test** (endpoint query params):
```swift
func testAssetFilterProductTypesQueryItems() {
    let ep = APIEndpoint.assetFilterProductTypes(search: "screen")
    let items = Dictionary(uniqueKeysWithValues: (ep.queryItems ?? []).map { ($0.name, $0.value) })
    XCTAssertEqual(items["search"], "screen")
    XCTAssertEqual(items["is_active"], "true")
    XCTAssertEqual(items["limit"], "50")
    XCTAssertNil(items["product_kind"])
}
```

- [ ] **Step 3: Run — expect FAIL** (case undefined). `<TESTID>` = `InventoryEndpointTests/testAssetFilterProductTypesQueryItems`.

- [ ] **Step 4: Implement.** Add the case + path/method/queryItems (model it on the existing `.productTypes(search:)` case but drop `product_kind`, set `is_active=true`, `limit=50`):
```swift
case assetFilterProductTypes(search: String?)
// path: "/api/product-types"; method: .get
// queryItems: [search? "search", "is_active"="true", "limit"="50"]
```
Point `InventoryService.fetchProductTypes` at `.assetFilterProductTypes(search:)`. **Do not touch** the shared `.productTypes` case.

- [ ] **Step 5: Run test — expect PASS.** Build the app scheme to confirm the service change compiles.

- [ ] **Step 6: Commit.**
```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift" "Repair Minder/Repair MinderTests/InventoryEndpointTests.swift"
git commit -m "fix(inventory): asset product-type filter uses inventory-kind endpoint variant (MF-1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 5: MF-4 — coalesce `loadMore()` against reloads

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift:~79`
- Test: `Repair Minder/Repair MinderTests/InventoryListViewModelTests.swift` (add)

- [ ] **Step 1: Read** `loadMore()` and `loadAssets()` to learn the query fields (status/search/productTypeId/etc.) and the existing `pendingReload` coalescing.

- [ ] **Step 2: Write the failing test.** Using the existing `InventoryServingStub` (make `fetchAssets` await a controllable continuation), start `loadMore`, change a filter mid-flight, resume, and assert the stale page-2 is discarded and `currentPage`/`assets` reflect only the fresh reload:
```swift
func testLoadMoreDiscardsStalePageWhenQueryChangesMidFlight() async {
    let stub = InventoryServingStub()
    let vm = await InventoryListViewModel(service: stub)
    // seed page 1, begin loadMore, flip status filter before the awaited page returns,
    // then assert vm.assets does not contain the stale page-2 rows and currentPage != 2.
    // (Model on the Phase-2 coalescing test testLoadCoalescesFilterChange.)
}
```
Fill in the stub-gating exactly like the existing coalescing test in this file.

- [ ] **Step 3: Run — expect FAIL.** `<TESTID>` = `InventoryListViewModelTests/testLoadMoreDiscardsStalePageWhenQueryChangesMidFlight`.

- [ ] **Step 4: Implement.** At the top of `loadMore()` capture the query; after the `await`, bail before appending if `isLoading` is true or the query changed:
```swift
func loadMore() async {
    guard hasMore, !isLoadingMore, !isLoading else { return }
    let snapshot = currentQuerySnapshot()   // status, search, filters, currentPage
    isLoadingMore = true; defer { isLoadingMore = false }
    let page = try? await service.fetchAssets(/* snapshot */)
    guard snapshot == currentQuerySnapshot(), !isLoading else { return } // stale → drop
    // append + advance cursor as before
}
```
Add a small `Equatable` `struct QuerySnapshot` (or compare the individual fields) and `currentQuerySnapshot()`.

- [ ] **Step 5: Run test — expect PASS**, then run the whole `InventoryListViewModelTests` class.

- [ ] **Step 6: Commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift" "Repair Minder/Repair MinderTests/InventoryListViewModelTests.swift"
git commit -m "fix(inventory): coalesce loadMore against reloads, no stale-page corruption (MF-4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 6: NTH-3 — searchable, uncapped group/part pickers

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/AssetFilterSheet.swift:~68` (group filter)
- Modify: `Repair Minder/Repair Minder/Features/Staff/Buyback/SalvageDeviceCard.swift:~51` (part picker)
- Test: extend an existing filter/salvage VM test if a searchable-list VM is introduced; otherwise a wiring assertion.

- [ ] **Step 1: Read** the product-type search section already in `AssetFilterSheet` (it debounces into `fetchGroups(search:)`/`assetGroupsList(search:)`) — reuse its pattern.

- [ ] **Step 2: Implement the group filter.** Replace the static `Picker` (loaded once at `limit:100`) with a searchable list bound to a `@State searchText`, debounced, calling `fetchGroups(search:)`. Keep a "clear" affordance.

- [ ] **Step 3: Implement the salvage part picker** identically in `SalvageDeviceCard` (search field → `fetchGroups(search:)`), replacing the capped `Picker`.

- [ ] **Step 4: Test.** Add a VM-level test that a non-empty search string reaches the service call (spy on `InventoryServingStub.fetchGroupsCalledWithSearch`). `<TESTID>` = the salvage or filter VM test class.

- [ ] **Step 5: Build the app scheme** (SwiftUI wiring compiles). Commit.
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/AssetFilterSheet.swift" "Repair Minder/Repair Minder/Features/Staff/Buyback/SalvageDeviceCard.swift" "Repair Minder/Repair MinderTests/"
git commit -m "fix(inventory): searchable group/part pickers, no 100-row cap (NTH-3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 7: NTH-10a — list row shows serial / SKU / condition grade

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift:~348` (`AssetRow`)

- [ ] **Step 1: Read** `AssetRow` and confirm `Asset` has `serialNumber`, `sku`, `conditionGrade` (all optional). Reuse the grade-badge style from `AssetHierarchyView`'s `AssetStatusBadge`/web colours.

- [ ] **Step 2: Implement.** In `AssetRow`, when present, render serial + SKU as caption text and a small condition-grade badge. Guard optionals (`if let`). No decode changes.

- [ ] **Step 3: Build the app scheme** to confirm it compiles. (Row is view-only; no unit test.) Commit.
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift"
git commit -m "fix(inventory): asset list row shows serial/SKU/condition grade (NTH-10a)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 8: NTH-10b — "N found" totals

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift` and `InventoryGroupsListViewModel.swift`
- Modify: `InventoryListView.swift`, `InventoryGroupsListView.swift`
- Test: `InventoryListViewModelTests`, `InventoryGroupsListViewModelTests` (add)

- [ ] **Step 1: Find how the paginated envelope is decoded.** The list endpoints put pagination under `meta`. Check `APIClient` for an existing paginated request (`requestWithPagination`/`requestFull`). Prefer capturing `meta.total` via the existing envelope-sibling path used elsewhere; if none, add a minimal `AssetsPage { items, total }` decode using `requestFull`.

- [ ] **Step 2: Failing test** — assert the VM stores `total` after a load whose fixture includes `meta.total`. `<TESTID>` = `InventoryListViewModelTests/testCapturesTotalFromMeta`.

- [ ] **Step 3: Implement** `@Published var total: Int?` in both VMs, populate from `meta.total`, and render "N assets found" / "N groups found" in the list views.

- [ ] **Step 4: Run both VM test classes. Commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/" "Repair Minder/Repair MinderTests/"
git commit -m "fix(inventory): surface total result count for assets and groups lists (NTH-10b)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

# GROUP C — Detail writes

## Task 9: MF-7 — re-fetch the asset after every mutation

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift:~49` (`applyUpdated`, `refreshSubResources`)
- Test: `Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift` (add)

- [ ] **Step 1: Write the failing test.** Mock a mutation returning a join-less asset (nil `locationName`/`productTypeName`) and mock `fetchAsset(id:)` to return the fully-joined asset; assert the VM ends with the joined values:
```swift
func testMutationRefetchesJoinedAsset() async {
    let stub = InventoryServingStub()
    stub.moveResult = Asset.fixture(id: "a1", locationName: nil, productTypeName: nil)
    stub.fetchAssetResult = Asset.fixture(id: "a1", locationName: "Shelf B", productTypeName: "Screen")
    let vm = await InventoryDetailViewModel(assetId: "a1", service: stub)
    await vm.move(locationId: "loc1", subLocationId: nil)
    XCTAssertEqual(vm.asset?.locationName, "Shelf B")
    XCTAssertEqual(vm.asset?.productTypeName, "Screen")
}
```
(Add `Asset.fixture(...)` helper if not present; add `fetchAssetResult`/`moveResult` to `InventoryServingStub`.)

- [ ] **Step 2: Run — expect FAIL** (VM keeps the join-less `resp.data`). `<TESTID>` = `InventoryWriteViewModelTests/testMutationRefetchesJoinedAsset`.

- [ ] **Step 3: Implement.** In `applyUpdated` set `asset = resp.data` optimistically, then in the mutation flow (or a new `refreshAsset()`) call `service.fetchAsset(id:)` and reconcile `asset`. Fold `refreshAsset()` into `refreshSubResources` (called by every mutation). Ensure `.inventoryAssetDidChange` still posts once.

- [ ] **Step 4: Run test — expect PASS**, then the full `InventoryWriteViewModelTests` class.

- [ ] **Step 5: Commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift" "Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift"
git commit -m "fix(inventory): re-fetch joined asset after mutations (MF-7)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 10: MF-6 — part-recovery LCD/glass screen-gated + required

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/PartRecoveryForm.swift:~11,31,20`
- Test: `Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift` (add `toInput()` tests)

- [ ] **Step 1: Read** web `src/components/assets/PartRecoveryForm.tsx:42-69` to copy the exact "screen" category test.

- [ ] **Step 2: Write failing tests.**
```swift
func testPartRecoveryScreenRequiresBothAnswers() {
    var f = PartRecoveryForm.Model(category: "screen")   // no answers set
    XCTAssertFalse(f.isValid)
    f.lcdWorking = true; f.glassCracked = false
    XCTAssertTrue(f.isValid)
    let input = f.toInput()
    XCTAssertEqual(input?.lcdWorking, true)
    XCTAssertEqual(input?.glassCracked, false)
}
func testPartRecoveryNonScreenOmitsScreenFields() {
    let f = PartRecoveryForm.Model(category: "battery")
    XCTAssertTrue(f.isValid)                  // no screen answers needed
    XCTAssertNil(f.toInput()?.lcdWorking)
    XCTAssertNil(f.toInput()?.glassCracked)
}
```
(Adapt to the actual model type name/shape in the file.)

- [ ] **Step 3: Run — expect FAIL.** `<TESTID>` = `InventoryWriteModelTests/testPartRecoveryScreenRequiresBothAnswers`.

- [ ] **Step 4: Implement.** Make `lcdWorking`/`glassCracked` optional (un-answered by default); add `isScreen` (category-based) and `isValid` (screen ⇒ both non-nil); render the toggles only when `isScreen`; `toInput()` emits the screen fields only when `isScreen`. Wire `isValid` to disable the Allocate button in `DeployToOrderWizard`/confirm step.

- [ ] **Step 5: Run tests — expect PASS.** Commit.
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/PartRecoveryForm.swift" "Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift"
git commit -m "fix(inventory): part-recovery LCD/glass screen-gated and required (MF-6)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 11: NTH-4 — reset allocate error on deploy-wizard cancel

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployToOrderWizard.swift:~34`
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployChooserSheet.swift:~38`

- [ ] **Step 1: Implement.** In both Cancel actions add `viewModel.actionError = nil` before dismiss (matching other sheets).

- [ ] **Step 2: Build the app scheme.** Commit.
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployToOrderWizard.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployChooserSheet.swift"
git commit -m "fix(inventory): clear allocate error on deploy-wizard cancel (NTH-4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 12: NTH-5 — condition-grade clear comment

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetEditSheet.swift:~100`

- [ ] **Step 1: Fix the misleading comment.** Behaviour stays (send `""` to clear when "Not set"). Replace the "matches web" comment with: `// Sends "" to clear the grade when "Not set" is chosen; web is aligned to this in fix/inventory-parity-bugs (W5).`

- [ ] **Step 2: Confirm** `testUpdateAssetSendsEmptyConditionGradeToClear` still passes. `<TESTID>` = `InventoryWriteModelTests/testUpdateAssetSendsEmptyConditionGradeToClear`.

- [ ] **Step 3: Commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetEditSheet.swift"
git commit -m "docs(inventory): correct condition-grade clear comment; canonical=clear (NTH-5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 13: NTH-1 — GroupEditSheet can blank fields; drop GroupSelector onAppear race

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupEditSheet.swift:~45`
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupSelectorSheet.swift:~58`
- Test: `Repair Minder/Repair MinderTests/GroupEditSheetTests.swift` (add)

- [ ] **Step 1: Verify worker behaviour.** Confirm `PUT /api/product-types/:id` applies `""` for sku/subcategory/manufacturer/model_number/supplier (read `worker/product_type_handlers.js` update handler). Note any field that ignores `""`.

- [ ] **Step 2: Write the failing test** (encode): a group-edit request with user-cleared SKU emits `"sku":""`, not omitted.
```swift
func testGroupEditEmitsEmptyStringForClearedFields() throws {
    let req = GroupEditSheet.buildRequest(sku: "", manufacturer: "")  // adapt to real builder
    let data = try encode(req)  // .convertToSnakeCase
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    XCTAssertEqual(obj["sku"] as? String, "")
}
```

- [ ] **Step 3: Run — expect FAIL.** `<TESTID>` = `GroupEditSheetTests/testGroupEditEmitsEmptyStringForClearedFields`.

- [ ] **Step 4: Implement.** In the request builder, map user-cleared text fields to `""` (not `nil`) for fields the worker can blank; keep `nil` for untouched fields (only send `""` when the user actually cleared a previously-set value — track "dirty" per field, or send `""` for all string fields that are empty AND were shown populated).

- [ ] **Step 5: GroupSelector race.** Remove the `.onAppear { selected = Set(initialSelection) }` seed (the `.task` authoritative load + Save-gate already cover it), or guard `if !didLoadSelection`.

- [ ] **Step 6: Run test + `GroupEditSheetTests` class + `InventoryGroupSelectorTests`. Commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupEditSheet.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupSelectorSheet.swift" "Repair Minder/Repair MinderTests/GroupEditSheetTests.swift"
git commit -m "fix(inventory): group edit can blank optional fields; drop selector onAppear race (NTH-1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

# GROUP D — Book-in

## Task 14: MF-3 — receive quantity capped at `remaining`

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/BookInWizardView.swift:~243`
- Modify: `Repair Minder/Repair Minder/Core/Models/SupplierOrderModels.swift` (add `remaining` computed if absent)
- Test: `Repair Minder/Repair MinderTests/BookInTests.swift` (add)

- [ ] **Step 1: Add `remaining` to the line model** if not present:
```swift
extension SupplierOrderLine { var remaining: Int { max((quantityOrdered ?? 0) - (quantityReceived ?? 0), 0) } }
```
(Match the real property names/optionality.)

- [ ] **Step 2: Failing test.**
```swift
func testReceiveQuantityCapsAtRemaining() {
    let line = SupplierOrderLine.fixture(quantityOrdered: 10, quantityReceived: 4)
    XCTAssertEqual(line.remaining, 6)
    // and the view-model/draft clamp:
    var draft = ReceiveDraft(line: line); draft.quantity = 99
    draft.clampToRemaining()   // add this if the clamp lives in the VM
    XCTAssertEqual(draft.quantity, 6)
}
```

- [ ] **Step 3: Run — expect FAIL.** `<TESTID>` = `BookInTests/testReceiveQuantityCapsAtRemaining`.

- [ ] **Step 4: Implement.** Change the stepper bound at `BookInWizardView.swift:243` from `0...max(line.quantityOrdered, 1)` to `0...max(line.remaining, 1)`; cap the serial `ForEach` to the same count; clamp any pre-seeded draft quantity to `remaining`.

- [ ] **Step 5: Run test — expect PASS.** Commit.
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/BookInWizardView.swift" "Repair Minder/Repair Minder/Core/Models/SupplierOrderModels.swift" "Repair Minder/Repair MinderTests/BookInTests.swift"
git commit -m "fix(inventory): receive caps at remaining, prevents over-receive (MF-3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Live-prod re-verify** (spec discipline, `ZZ-FIX-` prefix): seed a supplier order + line (qty 10), receive 4, confirm the app can't receive >6; hard-delete via D1; verify zero `ZZ-FIX-` rows remain in admin + demo.

## Task 15: NTH-9 — "Receive More" reseeds drafts

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/BookInWizardView.swift:~291`
- Modify: `BookInWizardViewModel.swift` (expose `prepareReceive()` if private)

- [ ] **Step 1: Implement.** On "Receive More", call `viewModel.prepareReceive()` (reseed drafts from current line state) before setting `step = .receive`, so stale quantities/serials don't persist.

- [ ] **Step 2: Add a VM test** that `prepareReceive()` rebuilds drafts to `remaining` per line after a partial receive. `<TESTID>` = `BookInTests/testPrepareReceiveReseedsToRemaining`.

- [ ] **Step 3: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/" "Repair Minder/Repair MinderTests/BookInTests.swift"
git commit -m "fix(inventory): Receive More reseeds drafts from current line state (NTH-9)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 16: NTH-8 — receive sub-location picker + line product-type link

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/BookInWizardView.swift` (receive step + line editor)
- Modify: `Repair Minder/Repair Minder/Core/Models/SupplierOrderModels.swift` (populate `ReceiveItemInput.subLocationId`)

- [ ] **Step 1: Sub-location picker.** In the receive step add a sub-location picker (reuse `AssetSubLocationOption` + `.locationSubLocations` endpoint, as in `AssetMoveSheet`), defaulting from the line; write the chosen id into `ReceiveDraft.subLocationId` → `ReceiveItemInput.subLocationId` (already sent to the worker).

- [ ] **Step 2: Line product-type link (optional field).** Add a product-type picker to the line editor (reuse the Task-4 `assetFilterProductTypes` search); write it into the line request. If this materially grows the diff, land it as a second commit — but do not drop it.

- [ ] **Step 3: Test** that a chosen sub-location id reaches `ReceiveItemInput`. `<TESTID>` = `BookInTests/testReceiveInputCarriesSubLocation`.

- [ ] **Step 4: Build + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/" "Repair Minder/Repair Minder/Core/Models/SupplierOrderModels.swift" "Repair Minder/Repair MinderTests/BookInTests.swift"
git commit -m "fix(inventory): receive sub-location picker + line product-type link (NTH-8)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 17: NTH-11 — hide "Import CSV" for non-admins

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift:~321`

- [ ] **Step 1: Implement.** Wrap the "Import CSV" menu entry in `if AuthManager.shared.currentUser?.role.isAdmin == true { ... }`. Keep the in-sheet guard.

- [ ] **Step 2: Build + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift"
git commit -m "fix(inventory): hide Import CSV menu entry for non-admins (NTH-11)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 18: Book-in import decode alignment (`field`)

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Models/SupplierOrderModels.swift:~185` (`AssetImportRowError`)
- Test: `Repair Minder/Repair MinderTests/BookInTests.swift` (add)

- [ ] **Step 1: Failing test** decoding a real validation row `{"row":3,"field":"sku","message":"required"}`:
```swift
func testImportRowErrorDecodesFieldAndMessage() throws {
    let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
    let e = try d.decode(AssetImportRowError.self, from: #"{"row":3,"field":"sku","message":"required"}"#.data(using:.utf8)!)
    XCTAssertEqual(e.field, "sku")
    XCTAssertTrue(e.display.contains("Row 3"))
}
```

- [ ] **Step 2: Run — expect FAIL.** `<TESTID>` = `BookInTests/testImportRowErrorDecodesFieldAndMessage`.

- [ ] **Step 3: Implement.** Add `field: String?`; drop the never-sent `sku`/`error` (or keep with a doc comment); include `field` in `.display` when present.

- [ ] **Step 4: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Core/Models/SupplierOrderModels.swift" "Repair Minder/Repair MinderTests/BookInTests.swift"
git commit -m "fix(inventory): align AssetImportRowError to worker {row,field,message}

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 19: Book-in cancel semantics (DELETE empty orders)

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/SupplierOrderListViewModel.swift:~40`
- Modify: `APIEndpoints.swift` (confirm a `DELETE /api/supplier-orders/:id` case exists; add if missing)

- [ ] **Step 1: Read** `worker/supplier_order_handlers.js` DELETE handler (hard-deletes when no received lines).

- [ ] **Step 2: Implement.** In `cancelOrder`, if the order has zero received lines call `requestVoid(.deleteSupplierOrder(id:))`; otherwise keep PATCH `status=cancelled`.

- [ ] **Step 3: Test** the branch selection at the VM level (mock service records which call fired). `<TESTID>` = `BookInTests/testCancelDeletesEmptyOrder` (create `SupplierOrderListViewModelTests` if cleaner).

- [ ] **Step 4: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn/SupplierOrderListViewModel.swift" "Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift" "Repair Minder/Repair MinderTests/"
git commit -m "fix(inventory): cancel deletes empty supplier orders, matching web

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

# GROUP E — Bulk / salvage / analytics polish

## Task 20: NTH-6 — bulk deploy-external deployment date

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Bulk/BulkDeploySheet.swift:~112`
- Test: `Repair Minder/Repair MinderTests/InventoryBulkTests.swift` (add)

- [ ] **Step 1: Failing test** — the built `DeployExternalRequest` carries a `deploymentDate` (default today):
```swift
func testBulkDeployExternalCarriesDate() {
    let req = BulkDeploySheet.buildExternalRequest(date: someDate, /* ... */)
    XCTAssertNotNil(req.deploymentDate)
}
```

- [ ] **Step 2: Run — expect FAIL.** `<TESTID>` = `InventoryBulkTests/testBulkDeployExternalCarriesDate`.

- [ ] **Step 3: Implement.** Add a `DatePicker` (default today) to the external view; pass `deploymentDate` into the request (model field already exists).

- [ ] **Step 4: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Bulk/BulkDeploySheet.swift" "Repair Minder/Repair MinderTests/InventoryBulkTests.swift"
git commit -m "fix(inventory): bulk deploy-external sends deployment date (NTH-6)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Live-prod re-verify** the date is recorded (bulk external-deploy a seeded `ZZ-FIX-` asset; hard-delete; confirm clean).

## Task 21: Tighten deploy-to-order to require a line item (single + bulk)

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployToOrderWizard.swift:~71`
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Bulk/BulkDeploySheet.swift:~74`
- Test: `AssetActionsTests` or the deploy VM test (add gating assertion)

- [ ] **Step 1: Implement.** Remove the "No specific line item"/"None" options; disable the "Deploy" CTA until a line item is selected in both flows.

- [ ] **Step 2: Test** that deploy is disabled with no line item selected. `<TESTID>` = the deploy gating test.

- [ ] **Step 3: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployToOrderWizard.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/Bulk/BulkDeploySheet.swift" "Repair Minder/Repair MinderTests/"
git commit -m "fix(inventory): require a line item for deploy-to-order, matching web

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 22: CSV export status column — document the intentional divergence

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Bulk/CSVExporter.swift:~16`

- [ ] **Step 1: Add a header comment** at the `status` column: `// Intentional divergence: iOS exports human-readable status.displayName; web exports raw status. See spec §Group E.` No behaviour change.

- [ ] **Step 2: Commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Bulk/CSVExporter.swift"
git commit -m "docs(inventory): note CSV status displayName divergence from web

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 23: NTH-7 — LowStockBanner in the Stock segment

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/Stock/InventoryStockView.swift`

- [ ] **Step 1: Implement.** Render `LowStockBanner` above the Summary/Hierarchy sub-tabs in `InventoryStockView` (reuse the same banner + data source used above the Assets list). Keep the dedicated Low Stock sub-tab.

- [ ] **Step 2: Build + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Stock/InventoryStockView.swift"
git commit -m "fix(inventory): show low-stock banner in Stock segment too (NTH-7)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 24: NTH-12 — `SalvageResponse.assets` optional

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Models/SalvageModels.swift:~24`
- Test: `Repair Minder/Repair MinderTests/SalvageTests.swift` (add)

- [ ] **Step 1: Failing test** — a salvage POST response missing/odd `assets` still decodes (VM reads `salvagedAssets`):
```swift
func testSalvageResponseDecodesWithoutAssets() throws {
    let json = #"{"salvaged_assets":[],"new_status":"salvaged","salvage_budget":{"cap":100,"booked":0,"remaining":100}}"#
    let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
    XCTAssertNoThrow(try d.decode(SalvageResponse.self, from: json.data(using:.utf8)!))
}
```

- [ ] **Step 2: Run — expect FAIL.** `<TESTID>` = `SalvageTests/testSalvageResponseDecodesWithoutAssets`.

- [ ] **Step 3: Implement.** Change `assets: [Asset]` → `assets: [Asset]?`.

- [ ] **Step 4: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Core/Models/SalvageModels.swift" "Repair Minder/Repair MinderTests/SalvageTests.swift"
git commit -m "fix(inventory): SalvageResponse.assets optional, no false-fail after book (NTH-12)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 25: NTH-2 — scanner URL parsing (INVESTIGATE, then fix)

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryScannerSheet.swift:~84` (+ `BulkScanViewModel`, `InventoryListView.lookupTag`)
- Test: `Repair Minder/Repair MinderTests/ScannerParseTests.swift` (create)

- [ ] **Step 1: Investigate.** Determine whether RM asset labels QR-encode a URL: check the web label-printing code (`window.print` QR grid) for the encoded value, or inspect a real label. Read web `parseAssetScanUrl` (`src/components/modals/BulkScanActionsModal.tsx:22`).

- [ ] **Step 2: If labels are plain tags** (single-lookup works in prod), record "no fix needed" and SKIP. **If URLs are possible**, continue.

- [ ] **Step 3: Failing test.**
```swift
func testParseAssetScanUrl() {
    XCTAssertEqual(AssetScan.parse("https://app.repairminder.com/assets/tag/AST-123"), "AST-123")
    XCTAssertEqual(AssetScan.parse("AST-123"), "AST-123")           // raw passthrough
    XCTAssertEqual(AssetScan.parse("https://x/api/assets/tag/AST-9?x=1"), "AST-9")
}
```

- [ ] **Step 4: Implement** `enum AssetScan { static func parse(_ s: String) -> String }` (extract the segment after `/tag/`, else return trimmed input); apply it before `fetchAssetByTag` in both scan paths.

- [ ] **Step 5: Run + commit.**
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/" "Repair Minder/Repair MinderTests/ScannerParseTests.swift"
git commit -m "fix(inventory): parse asset tag from scanned URL before lookup (NTH-2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 26: Salvage card polish

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Buyback/SalvageDeviceCard.swift` (lines ~79, 85, 113, 122, 123, 126)

- [ ] **Step 1: Implement all five polish items.**
  - `:122` — wrap the salvaged-asset tag in a `NavigationLink`/`navigationDestination` to `InventoryDetailView` (via `InventoryDetailViewModel(assetId:)`).
  - `:123` — append `location_name` to booked rows (`SalvagedAssetSummary.locationName`).
  - `:113` — over-budget label: `"Over budget by \(CurrencyFormatter.format(abs(remaining)))"`.
  - `:79` — sub-location label composes `"\(code) — \(description)"` (both when present).
  - `:126,85` — track `@State removingId`; disable that row's remove while its DELETE is in flight; disable Add while `booking`.
  - (Optional) `:116` — empty-state text "No parts salvaged from this device yet."

- [ ] **Step 2: Build the app scheme.** Commit.
```bash
git add "Repair Minder/Repair Minder/Features/Staff/Buyback/SalvageDeviceCard.swift"
git commit -m "fix(inventory): salvage card polish — asset link, location, over-budget amount, sub-loc label, in-flight disable (Salvage F2/F4/F5/F6/F8)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

# GROUP F — Dead code + tests + release

## Task 27: Prune truly-unused code

**Files (remove the symbols):**
- `Bulk/BulkViewModels.swift:94-95,130-131` — `successCount`/`failureCount` on both bulk VMs
- `Buyback/SalvageBudget.swift:9` — `SalvageBudgetMath.spent(booked:pending:)`
- `Groups/GroupActions.swift:6` — `isAssetAddable`
- `BookIn/BookInWizardViewModel` — unused `init(order:)` + `seed(from:)`
- `Actions/ReturnToSupplierSheet.swift:26-31,53` — unreachable no-supplier branch

- [ ] **Step 1: Grep each symbol** to confirm zero non-test references before deleting:
```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
grep -rn "successCount\|failureCount\|isAssetAddable\|SalvageBudgetMath.spent\|seed(from:" "Repair Minder"
```
Delete only symbols with no non-test callers. (If `SalvageBudgetMath.spent` is referenced by a test, delete the test too or keep both.)

- [ ] **Step 2: Remove the symbols + any now-dead `@State`/branches.**

- [ ] **Step 3: Full inventory unit suite green** (run the whole `Repair MinderTests` target). Commit.
```bash
git add -A "Repair Minder/Repair Minder" "Repair Minder/Repair MinderTests"
git commit -m "chore(inventory): remove dead helpers and unreachable branches

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 28: Resolve decoded-but-unused model fields

**Files:** `Core/Models/SalvageModels.swift`, `InventoryGroupModels.swift`, `InventoryWriteModels.swift`, `InventoryBulkModels.swift`, `SupplierOrderModels.swift`

- [ ] **Step 1: Collapse the duplicate** `SalvageBudgetInfo` (`SalvageModels.swift:45`) into `BuybackInventory.SalvageBudget` (identical `{cap,booked,remaining}`) — update `SalvageResponse.salvageBudget` to the surviving type; delete the dup.

- [ ] **Step 2: Populate `ReceiveItemInput.unitCost/isOem/isRefurbished`** from the receive UI (parity — the receive form already collects cost/OEM/refurb; wire them into `buildReceiveInputs`). Add a `BookInTests` assertion that they're sent.

- [ ] **Step 3: Keep as documented contract mirrors** (add a one-line `// contract mirror; not yet rendered` comment on each): `SupplierReturnBatch.batches`, `InventoryGroup.linkedProducts`, `DeployExternalData.deployment`, `SalvageResponse.newStatus/.assets`, `DeleteSalvageResult.booked/.revertedTo`, `HierarchyAsset.locationName`, `LowStockBuckets`. Surface `ProductTypeOption.sku` as a picker sublabel where the filter shows product types (small parity win).

- [ ] **Step 4: Run the inventory suite green. Commit.**
```bash
git add -A "Repair Minder/Repair Minder/Core/Models" "Repair Minder/Repair Minder/Features/Staff/Inventory/BookIn" "Repair Minder/Repair MinderTests"
git commit -m "chore(inventory): collapse duplicate budget type, wire receive cost fields, annotate contract mirrors

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 29: Close the test gaps

**Files (create):**
- `Repair Minder/Repair MinderTests/BuybackListViewModelTests.swift`
- `Repair Minder/Repair MinderTests/BuybackDetailViewModelTests.swift`
- `Repair Minder/Repair MinderTests/DeployToOrderWizardTests.swift`
- `Repair Minder/Repair MinderTests/SupplierOrderListViewModelTests.swift`
- Extend `InventoryWriteViewModelTests.swift`, `BookInTests.swift`

- [ ] **Step 1: BuybackList/DetailVM** — decode fixtures + a load/mutation path each (use `InventoryServingStub`-style mocks; subclass the shared stub per the Phase-4 convention).

- [ ] **Step 2: DeployToOrderWizard** — VM flow test: order search → select line item → confirm → allocate calls the service with `order_id`+`order_item_id`; and (from Task 21) allocate is blocked with no line item.

- [ ] **Step 3: SupplierOrderListViewModel** — list decode + client-side status filter; cancel branch (Task 19).

- [ ] **Step 4: `.inventoryAssetDidChange` posting** — extend `InventoryWriteViewModelTests` to assert each write VM (edit/move/delete/return*/allocate/deployExternal and salvage book+remove) posts the notification exactly once (observe via `NotificationCenter`).

- [ ] **Step 5: Invoice-AI path** — `BookInTests`: `applyExtraction`/`submitOrderDetails` carries `invoice_file_key` into the create request.

- [ ] **Step 6: Run the FULL `Repair MinderTests` target green.** Commit.
```bash
git add "Repair Minder/Repair MinderTests"
git commit -m "test(inventory): cover buyback VMs, deploy wizard, supplier-order list, change-notifications, invoice path

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 30: Full verification + Mac build + version bump

- [ ] **Step 1: Full unit target** (expect the prior 106 + new tests, 0 failures):
```bash
cd "/Users/rikibaker/Repos/repairminder-iOS/repairminder-iOS"
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -parallel-testing-enabled NO ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -40
```

- [ ] **Step 2: 3 XCUITests** (pass/graceful-skip) — the Task 2 command.

- [ ] **Step 3: Mac scheme build** — must add ZERO new inventory-file errors (only the pre-existing `Signals/` errors):
```bash
xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder Mac" \
  -destination 'platform=macOS' -derivedDataPath ../build-derived-data-mac \
  -clonedSourcePackagesDirPath /tmp/rm-spm 2>&1 | tail -60
# then: grep the errors for Inventory|Salvage|SupplierOrder|BookIn|Bulk|Group|Stock -> expect none
```

- [ ] **Step 4: Bump version** `CURRENT_PROJECT_VERSION` → 009 in the Xcode project (match the roadmap's per-release bump).

- [ ] **Step 5: Commit.**
```bash
git add -A
git commit -m "chore(inventory): bump build to 009 after audit-fix sweep

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Finish the branch** — use superpowers:finishing-a-development-branch (merge to `main` + `git push origin main`, manual release; update memory `project_ios_inventory_phase4` / roadmap with the fix-sweep note).

---

# WEB (separate repo + branch) — Tasks 31–35

**Setup:**
```bash
cd "/Users/rikibaker/Repos/repairminder" && git checkout -b fix/inventory-parity-bugs
```
Before every web commit: `npx tsc --noEmit` must be clean. Do NOT build/deploy locally — CI deploys on merge to `main`.

## Task 31: W2 — BookInPage positional serials (HIGHEST PRIORITY — data corruption)

**Files:**
- Modify: `src/pages/BookInPage.tsx:~908`

- [ ] **Step 1: Locate** the receive payload build: `serial_numbers: serials?.filter(sn => sn.trim())` (or similar `.filter`).

- [ ] **Step 2: Replace with a positional array** of exactly `quantity` slots (index-aligned; blanks → `''`/`null`), mirroring the fixed iOS `buildReceiveInputs`:
```ts
const serial_numbers = Array.from({ length: quantity }, (_, i) => (serials?.[i] ?? '').trim());
const hasAny = serial_numbers.some(Boolean);
// send serial_numbers only when hasAny; never compact interior blanks
```

- [ ] **Step 3: `npx tsc --noEmit`** clean. Commit.
```bash
git add src/pages/BookInPage.tsx
git commit -m "fix(inventory): positional receive serials, no wrong-unit assignment (W2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Live-prod re-verify** (spec discipline): seed a `ZZ-FIX-` supplier order, receive with a blank interior serial, confirm serials land on the correct units in D1; hard-delete; verify clean.

## Task 32: W1 — AssetDetailPage re-fetch after mutation

**Files:**
- Modify: `src/pages/AssetDetailPage.tsx`

- [ ] **Step 1: Find** each `setAsset(response.data)` after a mutation (move/edit/allocate/return*/deploy-external).

- [ ] **Step 2: Replace** with a re-fetch of the joined asset (`assetsApi.get(id)` / the `/api/assets/:id` read) so `location_name`/`product_type_name`/part-recovery flags survive; keep an optimistic update then reconcile.

- [ ] **Step 3: `tsc --noEmit`** clean. Commit.
```bash
git add src/pages/AssetDetailPage.tsx
git commit -m "fix(inventory): re-fetch joined asset after mutations (W1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 33: W3 — GroupSelector sends a real category on create

**Files:**
- Modify: `src/components/inventory/GroupSelector.tsx:~135`

- [ ] **Step 1: Replace** `category: ''` in the create-group body with a real default (`category: 'General'`, matching iOS) so `POST /api/product-types` doesn't 400.

- [ ] **Step 2: `tsc --noEmit`** clean. Commit.
```bash
git add src/components/inventory/GroupSelector.tsx
git commit -m "fix(inventory): GroupSelector create sends non-empty category (W3)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 34: W4 — StockSummaryView child-row aggregate fallback

**Files:**
- Modify: `src/components/assets/StockSummaryView.tsx:~112`

- [ ] **Step 1: For child rows**, when `aggregate_in_stock`/`aggregate_*` are absent (worker only sets them on parents), fall back to the row's own `in_stock_count`/`allocated_count`/`total_count` (mirror iOS `displayInStock`/`displayAllocated`) so cells aren't blank.

- [ ] **Step 2: `tsc --noEmit`** clean. Commit.
```bash
git add src/components/assets/StockSummaryView.tsx
git commit -m "fix(inventory): child-row stock counts fall back to own values (W4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

## Task 35: W5 — condition-grade clear alignment

**Files:**
- Modify: `src/pages/AssetDetailPage.tsx`

- [ ] **Step 1: Change** `condition_grade: value || undefined` to send an explicit `''` when the user selects "Not set", so clearing works and matches iOS. Confirm the worker applies `''` (already verified in Task 13 Step 1 / the edit handler).

- [ ] **Step 2: `tsc --noEmit`** clean. Commit.
```bash
git add src/pages/AssetDetailPage.tsx
git commit -m "fix(inventory): condition-grade Not-set clears the grade, matching iOS (W5)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Finish the web branch** — use superpowers:finishing-a-development-branch (PR or merge to `main`; CI deploys). Cross-reference the iOS PR.

---

## Cross-project sync note

No worker/backend contract changes. All fixes reuse existing endpoints. iOS models unchanged in shape except: `Asset.status` decode-tolerance (Task 3), `AssetImportRowError` field rename (Task 18), `SalvageResponse.assets` optional (Task 24), `SalvageBudgetInfo` collapse (Task 28) — all iOS-internal, no API impact. Web and iOS agree on condition-grade clear (Tasks 12/35). iPhone/iPad/Mac share the touched Swift models — Task 30 confirms the Mac scheme is clean.
