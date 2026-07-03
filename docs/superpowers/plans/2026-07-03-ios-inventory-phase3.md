# iOS Inventory Phase 3 — Inventory Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the web Inventory Groups subsystem in the iOS app at full parity — groups list (sort/filter), group detail (member assets + linked products, add/remove members), bulk asset↔group assignment (making the read-only detail card editable), create group, promote-to-product, and full group metadata editing.

**Architecture:** Extend the existing Phase 1/2 Inventory module. New models in `Core/Models/InventoryGroupModels.swift`; 9 new `APIEndpoint` cases; extend the `InventoryServing`/`InventoryService` layer; new SwiftUI views under `Features/Staff/Inventory/Groups/`; a segmented Assets/Groups toggle on the existing list; a pure `GroupActions` gating helper. Networking uses the shared `APIClient` (`request`/`requestVoid`) — **no `requestFull` needed** (bulk-assign nests its result under `data`). Zero backend changes.

**Tech Stack:** Swift 6, SwiftUI, XCTest/XCUITest, shared `APIClient` (JSON `.convertFromSnakeCase`/`.convertToSnakeCase`).

**Spec:** `docs/superpowers/specs/2026-07-03-ios-inventory-phase3-design.md` (read it — it has every backend contract and the No-Deferral Checklist).

**Build/test commands** (run in the FOREGROUND — never background a build; it stalls the loop):
```bash
# Build
xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -40
# Unit test (single class)
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -parallel-testing-enabled NO -only-testing:"Repair MinderTests/InventoryGroupModelTests" \
  ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -40
```
If SPM artifacts are stale: `xcodebuild -resolvePackageDependencies -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" -clonedSourcePackagesDirPath /tmp/rm-spm` first.

**Conventions (do not re-derive — from Phases 1–2):**
- Models: `Decodable, Identifiable, Equatable, Sendable`; NO snake_case CodingKeys; Int-booleans as `Int?` + computed `Bool`; comma-joined strings stay `String`.
- Request structs: `Encodable`; every optional `= nil`; field order matches labeled call-site order.
- `@MainActor` init trap: `InventoryService.init(api: APIClient? = nil) { self.api = api ?? APIClient.shared }`.
- Views: `isEmbedded` (embedded body owns no `NavigationStack`); sheets show their OWN inline error (a parent `.alert` won't present over a sheet); post `.inventoryAssetDidChange` after any membership mutation.
- `Asset` model already exists and decodes `a.*` rows (incl. `location_name`, `sub_location_code`). `AssetGroupSummary` (has `membershipId`) and `AssetGroupListItem` already exist.

---

## Task 1: Group models + request structs

**Files:**
- Create: `Repair Minder/Repair Minder/Core/Models/InventoryGroupModels.swift`
- Test: `Repair Minder/Repair MinderTests/InventoryGroupModelTests.swift`

- [ ] **Step 1: Write the failing decode/encode tests**

Create `InventoryGroupModelTests.swift`:

```swift
import XCTest
@testable import Repair_Minder

final class InventoryGroupModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase
        let data = try e.encode(value)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // Real /api/asset-groups list row (aggregates present)
    func testInventoryGroupListRowDecodes() throws {
        let json = #"""
        {"id":"g1","name":"iPhone 14 Screen","sku":"SCR-14","category":"Screens",
         "subcategory":null,"manufacturer":"Apple","model_number":null,
         "reorder_level":5,"reorder_quantity":10,"preferred_supplier_name":"Mobasight",
         "default_cost":18.0,"default_sell_price":49.0,
         "is_oem":1,"is_refurbished":0,"is_active":1,
         "created_at":"2026-01-01T00:00:00.000Z","updated_at":null,
         "in_stock_count":12,"total_asset_count":20,"linked_product_count":2,
         "min_cost":15.0,"avg_cost":18.5,"max_cost":22.0}
        """#
        let g = try decode(InventoryGroup.self, json)
        XCTAssertEqual(g.id, "g1")
        XCTAssertEqual(g.inStockCount, 12)
        XCTAssertEqual(g.avgCost, 18.5)
        XCTAssertTrue(g.isOemBool)
        XCTAssertFalse(g.isRefurbishedBool)
        XCTAssertNil(g.linkedProducts)
    }

    // Real /api/asset-groups/:id detail (NO min/avg/max_cost, NO is_active, HAS linked_products)
    func testInventoryGroupDetailDecodesWithoutAggregateCosts() throws {
        let json = #"""
        {"id":"g1","name":"iPhone 14 Screen","sku":"SCR-14","category":"Screens",
         "subcategory":null,"manufacturer":null,"model_number":null,
         "reorder_level":5,"reorder_quantity":10,"preferred_supplier_name":null,
         "default_cost":null,"default_sell_price":null,"is_oem":0,"is_refurbished":0,
         "created_at":"2026-01-01T00:00:00.000Z","updated_at":null,
         "in_stock_count":12,"total_asset_count":20,"linked_product_count":1,
         "linked_products":[{"id":"p1","name":"Screen Repair","sku":"PRD-1",
            "product_kind":"product","quality_tier":"genuine","quantity_required":1}]}
        """#
        let g = try decode(InventoryGroup.self, json)
        XCTAssertNil(g.avgCost)          // detail omits aggregates
        XCTAssertNil(g.isActive)
        XCTAssertEqual(g.linkedProducts?.count, 1)
        XCTAssertEqual(g.linkedProducts?.first?.qualityTier, "genuine")
    }

    func testLinkedProductDecodesFullProductsRow() throws {
        let json = #"""
        {"id":"p1","name":"Screen Repair","sku":"PRD-1","product_kind":"product",
         "category":"Repairs","default_sell_price":89.0,"vat_rate":20.0,
         "quality_tier":"genuine","quantity_required":2,"is_required":1}
        """#
        let p = try decode(LinkedProduct.self, json)
        XCTAssertEqual(p.quantityRequired, 2)
        XCTAssertTrue(p.isRequiredBool)
        XCTAssertEqual(p.defaultSellPrice, 89.0)
    }

    func testGroupMembershipDecodes201() throws {
        let json = #"{"id":"m1","asset_id":"a1","group_id":"g1","company_id":"c1","created_by":"u1"}"#
        let m = try decode(GroupMembership.self, json)
        XCTAssertEqual(m.id, "m1"); XCTAssertEqual(m.assetId, "a1"); XCTAssertEqual(m.groupId, "g1")
    }

    func testBulkAssignResultDecodes() throws {
        let json = #"""
        {"asset_id":"a1","groups_added":2,"groups_removed":1,"assets_affected":3,
         "sibling_match":"sku","sku_value":"SCR-14","supplier_mappings_updated":2}
        """#
        let r = try decode(BulkAssignGroupsResult.self, json)
        XCTAssertEqual(r.groupsAdded, 2)
        XCTAssertEqual(r.assetsAffected, 3)
        XCTAssertEqual(r.siblingMatch, "sku")
        XCTAssertEqual(r.skuValue, "SCR-14")
    }

    func testPromoteResultDecodes() throws {
        let json = #"""
        {"product":{"id":"p1","name":"Screen","sku":"PRD-1","category":"Repairs",
           "product_kind":"product","default_sell_price":89.0,"vat_rate":20.0},
         "component":{"id":"c1","service_product_id":"p1","inventory_product_id":"g1",
           "quantity_required":1,"is_required":1}}
        """#
        let r = try decode(PromoteResult.self, json)
        XCTAssertEqual(r.product.id, "p1")
        XCTAssertEqual(r.component.inventoryProductId, "g1")
    }

    func testAddMembershipRequestEncodes() throws {
        let dict = try encodeToDict(AddMembershipRequest(assetId: "a1", groupId: "g1"))
        XCTAssertEqual(dict["asset_id"] as? String, "a1")
        XCTAssertEqual(dict["group_id"] as? String, "g1")
    }

    func testBulkAssignRequestEncodesEmptyClears() throws {
        let dict = try encodeToDict(BulkAssignGroupsRequest(groupIds: []))
        XCTAssertEqual((dict["group_ids"] as? [String])?.count, 0)
    }

    func testPromoteRequestEncodes() throws {
        let dict = try encodeToDict(PromoteGroupRequest(
            groupId: "g1", productName: "Screen", productSku: "PRD-1",
            productCategory: "Repairs", defaultSellPrice: 89.0))
        XCTAssertEqual(dict["group_id"] as? String, "g1")
        XCTAssertEqual(dict["product_name"] as? String, "Screen")
        XCTAssertEqual(dict["default_sell_price"] as? Double, 89.0)
        XCTAssertNil(dict["sell_price_inc_vat"])  // nil omitted
    }

    func testGroupFormRequestEncodesInventoryKindAndCategory() throws {
        let dict = try encodeToDict(GroupFormRequest(name: "Batteries", category: "General"))
        XCTAssertEqual(dict["name"] as? String, "Batteries")
        XCTAssertEqual(dict["category"] as? String, "General")
        XCTAssertEqual(dict["product_kind"] as? String, "inventory_item")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the unit-test command with `-only-testing:"Repair MinderTests/InventoryGroupModelTests"`.
Expected: FAIL — `cannot find 'InventoryGroup' in scope` (types not defined yet).

- [ ] **Step 3: Create the models**

Create `Core/Models/InventoryGroupModels.swift`:

```swift
import Foundation

// MARK: - Inventory Group (GET /api/asset-groups list + /:id detail)
// List rows carry min/avg/max_cost + is_active; detail rows omit those but add linked_products.
// So aggregate + linkedProducts fields are all optional.
struct InventoryGroup: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var category: String?
    var subcategory: String?
    var manufacturer: String?
    var modelNumber: String?
    var reorderLevel: Int?
    var reorderQuantity: Int?
    var preferredSupplierName: String?
    var defaultCost: Double?
    var defaultSellPrice: Double?
    var isOem: Int?
    var isRefurbished: Int?
    var isActive: Int?
    var createdAt: String?
    var updatedAt: String?
    var inStockCount: Int?
    var totalAssetCount: Int?
    var linkedProductCount: Int?
    var minCost: Double?
    var avgCost: Double?
    var maxCost: Double?
    var linkedProducts: [LinkedProduct]?

    var isOemBool: Bool { (isOem ?? 0) == 1 }
    var isRefurbishedBool: Bool { (isRefurbished ?? 0) == 1 }
}

// MARK: - Linked product (detail linked_products[] + /:id/products superset)
struct LinkedProduct: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var productKind: String?
    var category: String?
    var defaultSellPrice: Double?
    var vatRate: Double?
    var qualityTier: String?
    var quantityRequired: Int?
    var isRequired: Int?

    var isRequiredBool: Bool { (isRequired ?? 0) == 1 }
}

// MARK: - Membership (POST /api/asset-groups/memberships → 201)
struct GroupMembership: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetId: String?
    var groupId: String?
    var companyId: String?
    var createdBy: String?
}

// MARK: - Bulk assign result (POST /api/assets/:id/groups → data:{...})
struct BulkAssignGroupsResult: Decodable, Equatable, Sendable {
    var assetId: String?
    var groupsAdded: Int
    var groupsRemoved: Int
    var assetsAffected: Int
    var siblingMatch: String?     // "sku" | "name" | null
    var skuValue: String?
    var supplierMappingsUpdated: Int?
}

// MARK: - Promote result (POST /api/asset-groups/promote → 201 data:{product,component})
struct PromoteResult: Decodable, Equatable, Sendable {
    let product: PromotedProduct
    let component: PromotedComponent
}
struct PromotedProduct: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var name: String?
    var sku: String?
    var category: String?
    var productKind: String?
    var defaultSellPrice: Double?
    var vatRate: Double?
}
struct PromotedComponent: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var serviceProductId: String?
    var inventoryProductId: String?
    var quantityRequired: Int?
    var isRequired: Int?
}

// MARK: - Request bodies (encoded with .convertToSnakeCase)

/// POST /api/asset-groups/memberships
struct AddMembershipRequest: Encodable {
    var assetId: String
    var groupId: String
}

/// POST /api/assets/:id/groups — empty array clears all groups
struct BulkAssignGroupsRequest: Encodable {
    var groupIds: [String]
}

/// POST /api/asset-groups/promote
struct PromoteGroupRequest: Encodable {
    var groupId: String
    var productName: String
    var productSku: String? = nil
    var productCategory: String? = nil
    var defaultSellPrice: Double? = nil
    var sellPriceIncVat: Double? = nil
    var vatRate: Double? = nil
}

/// POST /api/product-types (create) + PUT /api/product-types/:id (edit).
/// Backend REQUIRES a non-empty `category`; inline create passes "General".
struct GroupFormRequest: Encodable {
    var name: String
    var category: String
    var sku: String? = nil
    var subcategory: String? = nil
    var manufacturer: String? = nil
    var modelNumber: String? = nil
    var reorderLevel: Int? = nil
    var reorderQuantity: Int? = nil
    var defaultCost: Double? = nil
    var defaultSellPrice: Double? = nil
    var preferredSupplierName: String? = nil
    var isOem: Int? = nil
    var isRefurbished: Int? = nil
    var productKind: String = "inventory_item"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the same test command. Expected: PASS (all 10 tests).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/InventoryGroupModels.swift" \
        "Repair Minder/Repair MinderTests/InventoryGroupModelTests.swift"
git commit -m "feat(inventory): Phase 3 group models + request structs with decode/encode tests"
```

> **Note for the live-E2E task (Task 10):** replace/augment these test JSON fixtures with REAL captured bodies from prod before merge — the demo account may have zero groups and the fixtures above are hand-built from the handlers.

---

## Task 2: API endpoints

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift` (case list ~line 212; `path` switch ~line 528; `method` switch ~line 590; `queryItems` switch ~line 671)

Grep to confirm current line numbers before editing (don't trust these).

- [ ] **Step 1: Add the enum cases**

After `case assetGroupsList(page: Int, limit: Int, search: String?)` extend it and add the new cases. Replace the `assetGroupsList` case with the richer signature and add cases in the Phase-2 write block:

```swift
    case assetGroupsList(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?)
    // Phase 3 — Inventory Groups
    case assetGroup(id: String)
    case assetGroupAssets(id: String, page: Int, limit: Int)
    case assetGroupProducts(id: String)
    case addMembership
    case removeMembership(id: String)
    case bulkAssignGroups(assetId: String)
    case promoteGroup
    case createProductType
    case updateProductType(id: String)
```

- [ ] **Step 2: Add the `path` cases**

In the `var path` switch, replace the `assetGroupsList` path line and add:

```swift
        case .assetGroupsList: return "/api/asset-groups"
        case .assetGroup(let id): return "/api/asset-groups/\(id)"
        case .assetGroupAssets(let id, _, _): return "/api/asset-groups/\(id)/assets"
        case .assetGroupProducts(let id): return "/api/asset-groups/\(id)/products"
        case .addMembership: return "/api/asset-groups/memberships"
        case .removeMembership(let id): return "/api/asset-groups/memberships/\(id)"
        case .bulkAssignGroups(let assetId): return "/api/assets/\(assetId)/groups"
        case .promoteGroup: return "/api/asset-groups/promote"
        case .createProductType: return "/api/product-types"
        case .updateProductType(let id): return "/api/product-types/\(id)"
```

- [ ] **Step 3: Add to `method`, `queryItems`, and update the GET list**

In `method`: add `.assetGroup, .assetGroupAssets, .assetGroupProducts` to the `.get` group (alongside `.assetGroupsList`); add `.addMembership, .bulkAssignGroups, .promoteGroup, .createProductType` to the `.post` group; add `.updateProductType` to the `.put` group; add `.removeMembership` to the `.delete` group.

In `queryItems`, replace the `assetGroupsList` case and add `assetGroupAssets`:

```swift
        case .assetGroupsList(let page, let limit, let search, let category, let hasProducts, let unlinkedOnly, let sortBy, let sortOrder):
            var items = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let search = search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
            if let category = category, !category.isEmpty { items.append(URLQueryItem(name: "category", value: category)) }
            if let hasProducts = hasProducts, hasProducts { items.append(URLQueryItem(name: "has_products", value: "true")) }
            if let unlinkedOnly = unlinkedOnly, unlinkedOnly { items.append(URLQueryItem(name: "unlinked_only", value: "true")) }
            if let sortBy = sortBy { items.append(URLQueryItem(name: "sort_by", value: sortBy)) }
            if let sortOrder = sortOrder { items.append(URLQueryItem(name: "sort_order", value: sortOrder)) }
            return items

        case .assetGroupAssets(_, let page, let limit):
            return [URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "limit", value: String(limit))]
```

`requiresAuth` already returns `true` by `default`, so nothing to add there.

Also fix the existing caller `fetchGroups(search:)` in `InventoryService.swift` and any `AssetFilterSheet`/`InventoryListViewModel` call site of `.assetGroupsList(page:limit:search:)` to pass the new args (`category: nil, hasProducts: nil, unlinkedOnly: nil, sortBy: nil, sortOrder: nil`). Grep: `grep -rn "assetGroupsList(" "Repair Minder/Repair Minder"`.

- [ ] **Step 4: Build to verify it compiles**

Run the build command. Expected: BUILD SUCCEEDED (fix any missed `.assetGroupsList(` call sites the compiler flags).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift" \
        "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift"
git commit -m "feat(inventory): Phase 3 group API endpoints (list filters + 9 new cases)"
```

---

## Task 3: Service methods + `GroupActions` gating helper

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift` (protocol ~line 5; impl class)
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupActions.swift`
- Test: `Repair Minder/Repair MinderTests/InventoryGroupActionsTests.swift`

- [ ] **Step 1: Write the failing gating tests**

Create `InventoryGroupActionsTests.swift`:

```swift
import XCTest
@testable import Repair_Minder

final class InventoryGroupActionsTests: XCTestCase {
    private func asset(_ status: AssetStatus) -> Asset {
        Asset(id: "a", assetTag: "T", name: "n", status: status)
    }
    func testOnlyInStockAssetsAreAddable() {
        XCTAssertTrue(GroupActions.isAssetAddable(asset(.inStock)))
        XCTAssertFalse(GroupActions.isAssetAddable(asset(.allocated)))
        XCTAssertFalse(GroupActions.isAssetAddable(asset(.deployed)))
    }
    func testAlreadyLinked() {
        var g = InventoryGroup(id: "g", name: "n"); g.linkedProductCount = 0
        XCTAssertFalse(GroupActions.alreadyLinked(g))
        g.linkedProductCount = 2
        XCTAssertTrue(GroupActions.alreadyLinked(g))
    }
    func testStockColorThresholds() {
        var g = InventoryGroup(id: "g", name: "n")
        g.inStockCount = 0; g.reorderLevel = 5
        XCTAssertEqual(GroupActions.stockLevel(g), .out)
        g.inStockCount = 3; g.reorderLevel = 5
        XCTAssertEqual(GroupActions.stockLevel(g), .low)
        g.inStockCount = 9; g.reorderLevel = 5
        XCTAssertEqual(GroupActions.stockLevel(g), .ok)
        g.inStockCount = 9; g.reorderLevel = 0   // no reorder set → never "low"
        XCTAssertEqual(GroupActions.stockLevel(g), .ok)
    }
}
```

> `InventoryGroup` is a struct with a memberwise init; `InventoryGroup(id:name:)` works because all other fields are optional/have defaults — confirm the memberwise init is accessible (it is, same-module). If the compiler complains, add an explicit convenience init in the test.

- [ ] **Step 2: Run tests to verify they fail**

`-only-testing:"Repair MinderTests/InventoryGroupActionsTests"`. Expected: FAIL — `cannot find 'GroupActions' in scope`.

- [ ] **Step 3: Create `GroupActions`**

Create `Features/Staff/Inventory/Groups/GroupActions.swift`:

```swift
import SwiftUI

/// Pure, testable gating + presentation rules for Inventory Groups (mirrors web).
enum GroupActions {
    /// Only in-stock assets can be added to a group (web filters add-search to status=in_stock).
    static func isAssetAddable(_ asset: Asset) -> Bool { asset.status == .inStock }

    /// Group is already linked to at least one product (drives the amber warning; promote still allowed).
    static func alreadyLinked(_ group: InventoryGroup) -> Bool { (group.linkedProductCount ?? 0) > 0 }

    enum StockLevel { case out, low, ok }
    static func stockLevel(_ group: InventoryGroup) -> StockLevel {
        let inStock = group.inStockCount ?? 0
        let reorder = group.reorderLevel ?? 0
        if inStock == 0 { return .out }
        if reorder > 0 && inStock <= reorder { return .low }
        return .ok
    }
    static func stockColor(_ group: InventoryGroup) -> Color {
        switch stockLevel(group) { case .out: return .red; case .low: return .orange; case .ok: return .green }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS.

- [ ] **Step 5: Add service protocol methods + implementations**

In `InventoryService.swift`, add to `protocol InventoryServing` (after the Phase-2 write methods):

```swift
    // Phase 3 — Groups
    func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup]
    func fetchGroup(id: String) async throws -> InventoryGroup
    func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset]
    func fetchGroupProducts(id: String) async throws -> [LinkedProduct]
    func addMembership(assetId: String, groupId: String) async throws -> GroupMembership
    func removeMembership(id: String) async throws
    func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult
    func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult
    func createGroup(_ body: GroupFormRequest) async throws -> InventoryGroup
    func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup
```

And to the `InventoryService` class (after `fetchOrderItems`):

```swift
    // MARK: - Phase 3 group actions
    func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup] {
        try await api.request(.assetGroupsList(page: page, limit: limit, search: search, category: category, hasProducts: hasProducts, unlinkedOnly: unlinkedOnly, sortBy: sortBy, sortOrder: sortOrder))
    }
    func fetchGroup(id: String) async throws -> InventoryGroup {
        try await api.request(.assetGroup(id: id))
    }
    func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset] {
        try await api.request(.assetGroupAssets(id: id, page: page, limit: limit))
    }
    func fetchGroupProducts(id: String) async throws -> [LinkedProduct] {
        try await api.request(.assetGroupProducts(id: id))
    }
    func addMembership(assetId: String, groupId: String) async throws -> GroupMembership {
        try await api.request(.addMembership, body: AddMembershipRequest(assetId: assetId, groupId: groupId))
    }
    func removeMembership(id: String) async throws {
        try await api.requestVoid(.removeMembership(id: id))
    }
    func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult {
        try await api.request(.bulkAssignGroups(assetId: assetId), body: BulkAssignGroupsRequest(groupIds: groupIds))
    }
    func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult {
        try await api.request(.promoteGroup, body: body)
    }
    func createGroup(_ body: GroupFormRequest) async throws -> InventoryGroup {
        try await api.request(.createProductType, body: body)
    }
    func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup {
        try await api.request(.updateProductType(id: id), body: body)
    }
```

- [ ] **Step 6: Update every existing `InventoryServing` conformer (mock in tests)**

The test `GatedService` (in `InventoryWriteViewModelTests.swift`) and any other mock conforming to `InventoryServing` must add stubs for the 10 new methods, or the test target won't compile. Add to `GatedService`:

```swift
    func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup] { [] }
    func fetchGroup(id: String) async throws -> InventoryGroup { InventoryGroup(id: id, name: "n") }
    func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset] { [] }
    func fetchGroupProducts(id: String) async throws -> [LinkedProduct] { [] }
    func addMembership(assetId: String, groupId: String) async throws -> GroupMembership { GroupMembership(id: "m") }
    func removeMembership(id: String) async throws {}
    func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult { BulkAssignGroupsResult(groupsAdded: 0, groupsRemoved: 0, assetsAffected: 1) }
    func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult { fatalError() }
    func createGroup(_ body: GroupFormRequest) async throws -> InventoryGroup { InventoryGroup(id: "g", name: body.name) }
    func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup { InventoryGroup(id: id, name: body.name) }
```

Grep for other conformers: `grep -rln "InventoryServing" "Repair Minder/Repair MinderTests"`.

- [ ] **Step 7: Build + run both new test classes**

Build, then run `InventoryGroupActionsTests` + the existing `InventoryWriteViewModelTests` (must still pass). Expected: BUILD SUCCEEDED, all PASS.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat(inventory): Phase 3 group service methods + GroupActions gating helper"
```

---

## Task 4: Groups list view-model + view + segmented toggle

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/InventoryGroupsListViewModel.swift`
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/InventoryGroupsListView.swift`
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift` (add segmented mode)
- Test: `Repair Minder/Repair MinderTests/InventoryGroupsListViewModelTests.swift`

- [ ] **Step 1: Write the failing VM tests**

```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryGroupsListViewModelTests: XCTestCase {
    final class Mock: InventoryServingStub {   // see note below
        var lastParams: (search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?)?
        var groups: [InventoryGroup] = []
        override func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup] {
            lastParams = (search, category, hasProducts, unlinkedOnly, sortBy, sortOrder)
            return groups
        }
    }
    func testLoadPassesFiltersAndSetsHasMore() async {
        let mock = Mock()
        mock.groups = (0..<25).map { InventoryGroup(id: "g\($0)", name: "n") }  // == pageSize
        let vm = InventoryGroupsListViewModel(service: mock, pageSize: 25)
        vm.search = "screen"; vm.hasProducts = true; vm.sortField = .inStock; vm.sortAscending = false
        await vm.load()
        XCTAssertEqual(vm.groups.count, 25)
        XCTAssertTrue(vm.hasMore)
        XCTAssertEqual(mock.lastParams?.search, "screen")
        XCTAssertEqual(mock.lastParams?.hasProducts, true)
        XCTAssertEqual(mock.lastParams?.sortBy, "in_stock_count")
        XCTAssertEqual(mock.lastParams?.sortOrder, "desc")
    }
    func testUnlinkedOnlyMapsToEmptyGroups() async {
        let mock = Mock()
        let vm = InventoryGroupsListViewModel(service: mock, pageSize: 25)
        vm.emptyGroups = true
        await vm.load()
        XCTAssertEqual(mock.lastParams?.unlinkedOnly, true)
    }
}
```

> **`InventoryServingStub`:** to avoid re-stubbing all ~40 protocol methods in every VM test, create ONE shared open class `InventoryServingStub: InventoryServing` in the test target (file `Repair MinderTests/InventoryServingStub.swift`) whose every method has a default (`fatalError()` for unused, `[]`/simple values where handy). Subclass it per test and override only what you need. Create it now as part of this step. (If a stub already exists from Phase 2, reuse/extend it instead.)

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `cannot find 'InventoryGroupsListViewModel'`.

- [ ] **Step 3: Create the view-model**

```swift
import SwiftUI

@MainActor
final class InventoryGroupsListViewModel: ObservableObject {
    enum SortField: String, CaseIterable, Identifiable {
        case name, inStock = "in_stock_count", total = "total_asset_count"
        case linked = "linked_product_count", reorder = "reorder_level", avgCost = "avg_cost"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .name: return "Name"; case .inStock: return "In stock"; case .total: return "Total"
            case .linked: return "Linked products"; case .reorder: return "Reorder level"; case .avgCost: return "Avg cost"
            }
        }
    }

    @Published var groups: [InventoryGroup] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published var errorMessage: String?

    // Filters / sort
    @Published var search = ""
    @Published var category: String?
    @Published var hasProducts = false
    @Published var emptyGroups = false
    @Published var sortField: SortField = .name
    @Published var sortAscending = true

    private let service: InventoryServing
    private let pageSize: Int
    private var page = 1
    private var pendingReload = false

    init(service: InventoryServing? = nil, pageSize: Int = 25) {
        self.service = service ?? InventoryService()
        self.pageSize = pageSize
    }

    func load() async {
        if isLoading { pendingReload = true; return }
        isLoading = true; errorMessage = nil; page = 1
        defer { isLoading = false }
        do {
            let result = try await fetch(page: 1)
            groups = result
            hasMore = result.count == pageSize
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
        if pendingReload { pendingReload = false; await load() }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true; defer { isLoadingMore = false }
        do {
            let next = page + 1
            let result = try await fetch(page: next)
            groups.append(contentsOf: result)
            page = next
            hasMore = result.count == pageSize
        } catch { /* keep existing list; surface nothing on pagination */ }
    }

    private func fetch(page: Int) async throws -> [InventoryGroup] {
        try await service.listGroups(
            page: page, limit: pageSize,
            search: search.isEmpty ? nil : search,
            category: category,
            hasProducts: hasProducts ? true : nil,
            unlinkedOnly: emptyGroups ? true : nil,
            sortBy: sortField.rawValue,
            sortOrder: sortAscending ? "asc" : "desc")
    }
}
```

> `APIError.userMessage` — reuse whatever the Phase-2 VMs use to render an error string; grep `userMessage`/`localizedDescription` in `InventoryDetailViewModel.swift` and match it.

- [ ] **Step 4: Run VM tests to verify they pass**

Expected: PASS.

- [ ] **Step 5: Create the list view + wire the segmented toggle**

Create `InventoryGroupsListView.swift` (embedded content — the parent provides navigation):

```swift
import SwiftUI

struct InventoryGroupsListView: View {
    @StateObject private var vm = InventoryGroupsListViewModel()
    /// External search text driven by the shared Inventory search bar.
    var externalSearch: String
    @State private var selectedGroupId: String?
    @State private var promotingGroup: InventoryGroup?

    var body: some View {
        List {
            filtersSection
            ForEach(vm.groups) { group in
                Button { selectedGroupId = group.id } label: { GroupRow(group: group) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("group-row-\(group.sku ?? group.id)")
                    .swipeActions(edge: .trailing) {
                        Button { promotingGroup = group } label: { Label("Promote", systemImage: "arrow.up.right") }
                            .tint(.accentColor)
                    }
                    .onAppear { if group.id == vm.groups.last?.id { Task { await vm.loadMore() } } }
            }
            if vm.isLoadingMore { ProgressView().frame(maxWidth: .infinity) }
        }
        .overlay { if vm.isLoading && vm.groups.isEmpty { ProgressView() } }
        .overlay { if !vm.isLoading && vm.groups.isEmpty { ContentUnavailableView("No inventory groups", systemImage: "shippingbox") } }
        .navigationDestination(item: $selectedGroupId) { id in
            InventoryGroupDetailView(groupId: id)
        }
        .sheet(item: $promotingGroup) { g in PromoteToProductSheet(group: g) { Task { await vm.load() } } }
        .task(id: externalSearch) { vm.search = externalSearch; await vm.load() }
        .onChange(of: vm.category) { Task { await vm.load() } }
        .onChange(of: vm.hasProducts) { Task { await vm.load() } }
        .onChange(of: vm.emptyGroups) { Task { await vm.load() } }
        .onChange(of: vm.sortField) { Task { await vm.load() } }
        .onChange(of: vm.sortAscending) { Task { await vm.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryAssetDidChange)) { _ in Task { await vm.load() } }
    }

    private var filtersSection: some View {
        Section {
            Toggle("Has products", isOn: $vm.hasProducts)
            Toggle("Empty groups", isOn: $vm.emptyGroups)
            Picker("Sort by", selection: $vm.sortField) {
                ForEach(InventoryGroupsListViewModel.SortField.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Ascending", isOn: $vm.sortAscending)
        }
    }
}

private struct GroupRow: View {
    let group: InventoryGroup
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(group.name).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(group.inStockCount ?? 0)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GroupActions.stockColor(group))
            }
            HStack(spacing: 8) {
                if let sku = group.sku, !sku.isEmpty { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                if let cat = group.category, !cat.isEmpty { Text(cat).font(.caption).foregroundStyle(.secondary) }
            }
            HStack(spacing: 12) {
                Text("Total \(group.totalAssetCount ?? 0)").font(.caption2).foregroundStyle(.secondary)
                if let lp = group.linkedProductCount, lp > 0 { Text("\(lp) product\(lp == 1 ? "" : "s")").font(.caption2).foregroundStyle(.accentColor) }
                if let r = group.reorderLevel, r > 0 { Text("Reorder \(r)").font(.caption2).foregroundStyle(.secondary) }
            }
        }
    }
}
```

In `InventoryListView.swift`, add a mode enum + segmented `Picker` above the content, rendering the assets list in `.assets` mode and `InventoryGroupsListView(externalSearch: <the list's search text>)` in `.groups` mode. Mirror the existing search-text binding. Example (adapt to the real structure):

```swift
enum InventoryMode: String, CaseIterable { case assets = "Assets", groups = "Groups" }
@State private var mode: InventoryMode = .assets
// ...inside body, above the list content:
Picker("", selection: $mode) {
    ForEach(InventoryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
}
.pickerStyle(.segmented)
.padding(.horizontal)
// then: if mode == .groups { InventoryGroupsListView(externalSearch: viewModel.searchText) } else { <existing assets list> }
```

Confirm the assets-search property name by reading `InventoryListView.swift`/`InventoryListViewModel.swift` (it drives the existing search field).

- [ ] **Step 6: Build to verify it compiles**

Build. Expected: BUILD SUCCEEDED. (`InventoryGroupDetailView` and `PromoteToProductSheet` are referenced but built in Tasks 5 & 7 — if you execute strictly in order, temporarily stub them as `struct X: View { ... init...; var body: some View { EmptyView() } }` and remove the stub when the real one lands. Prefer to build Task 6 after 5 & 7. If using subagent-driven-development, sequence 5 & 7 before wiring 4's `.sheet`/`.navigationDestination`, or land 4 with stubs and a follow-up.)

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(inventory): Phase 3 Groups list view + segmented Assets/Groups toggle"
```

---

## Task 5: Group detail view (tabs, add/remove members)

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/InventoryGroupDetailViewModel.swift`
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/InventoryGroupDetailView.swift`
- Test: `Repair Minder/Repair MinderTests/InventoryGroupDetailViewModelTests.swift`

- [ ] **Step 1: Write the failing VM tests**

```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryGroupDetailViewModelTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var removed: [String] = []
        var addedTo: [(String, String)] = []
        var assetGroups: [AssetGroupSummary] = []
        override func fetchGroup(id: String) async throws -> InventoryGroup {
            var g = InventoryGroup(id: id, name: "Screens"); g.inStockCount = 3; g.totalAssetCount = 5; return g
        }
        override func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset] {
            [Asset(id: "a1", assetTag: "T1", name: "Screen", status: .inStock)]
        }
        override func fetchGroupProducts(id: String) async throws -> [LinkedProduct] {
            [LinkedProduct(id: "p1", name: "Repair")]
        }
        override func addMembership(assetId: String, groupId: String) async throws -> GroupMembership {
            addedTo.append((assetId, groupId)); return GroupMembership(id: "m1")
        }
        override func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { assetGroups }
        override func removeMembership(id: String) async throws { removed.append(id) }
    }

    func testLoadPopulatesGroupAssetsAndProducts() async {
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: Mock())
        await vm.load()
        XCTAssertEqual(vm.group?.name, "Screens")
        XCTAssertEqual(vm.assets.count, 1)
        XCTAssertEqual(vm.products.count, 1)
    }
    func testAddMemberCallsService() async {
        let mock = Mock()
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: mock)
        await vm.addMember(assetId: "a9")
        XCTAssertEqual(mock.addedTo.first?.0, "a9")
        XCTAssertEqual(mock.addedTo.first?.1, "g1")
    }
    // Remove is a two-step: look up membership_id for this asset+group, then delete it.
    func testRemoveMemberResolvesMembershipIdThenDeletes() async {
        let mock = Mock()
        mock.assetGroups = [AssetGroupSummary(id: "g1", name: "Screens", membershipId: "mem-42")]
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: mock)
        await vm.removeMember(assetId: "a1")
        XCTAssertEqual(mock.removed, ["mem-42"])
    }
    func testRemoveMemberSurfacesErrorWhenMembershipMissing() async {
        let mock = Mock(); mock.assetGroups = []   // no matching membership
        let vm = InventoryGroupDetailViewModel(groupId: "g1", service: mock)
        await vm.removeMember(assetId: "a1")
        XCTAssertTrue(mock.removed.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }
}
```

> `AssetGroupSummary(id:name:membershipId:)` — confirm the memberwise init arg labels against `Inventory.swift` (fields: `id, name, sku?, category?, membershipId?, minCost?, avgCost?, maxCost?, inStockCount?`). Provide the labels the compiler needs.

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `cannot find 'InventoryGroupDetailViewModel'`.

- [ ] **Step 3: Create the detail view-model**

```swift
import SwiftUI

@MainActor
final class InventoryGroupDetailViewModel: ObservableObject {
    enum Tab { case assets, products }

    let groupId: String
    @Published var group: InventoryGroup?
    @Published var assets: [Asset] = []
    @Published var products: [LinkedProduct] = []
    @Published var tab: Tab = .assets
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var errorMessage: String?

    private let service: InventoryServing
    private var page = 1
    private let pageSize = 20
    @Published private(set) var hasMoreAssets = false

    init(groupId: String, service: InventoryServing? = nil) {
        self.groupId = groupId
        self.service = service ?? InventoryService()
    }

    func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            async let g = service.fetchGroup(id: groupId)
            async let a = service.fetchGroupAssets(id: groupId, page: 1, limit: pageSize)
            async let p = service.fetchGroupProducts(id: groupId)
            group = try await g
            let assetsResult = try await a
            assets = assetsResult; hasMoreAssets = assetsResult.count == pageSize; page = 1
            products = try await p
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    func loadMoreAssets() async {
        guard hasMoreAssets, !isMutating, !isLoading else { return }
        do {
            let next = page + 1
            let result = try await service.fetchGroupAssets(id: groupId, page: next, limit: pageSize)
            assets.append(contentsOf: result); page = next; hasMoreAssets = result.count == pageSize
        } catch { /* keep list */ }
    }

    func addMember(assetId: String) async {
        isMutating = true; defer { isMutating = false }
        do {
            _ = try await service.addMembership(assetId: assetId, groupId: groupId)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            await load()
        } catch { errorMessage = memberError(error) }
    }

    /// Two-step (group-assets rows have no membership_id): look up this asset's groups,
    /// find the membership for THIS group, delete it.
    func removeMember(assetId: String) async {
        isMutating = true; defer { isMutating = false }
        do {
            let groups = try await service.fetchAssetGroups(id: assetId)
            guard let membershipId = groups.first(where: { $0.id == groupId })?.membershipId else {
                errorMessage = "Membership not found"; return
            }
            try await service.removeMembership(id: membershipId)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            await load()
        } catch { errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription }
    }

    private func memberError(_ error: Error) -> String {
        if case let APIError.serverError(message, code) = error, code == 409 { return message }
        return (error as? APIError)?.userMessage ?? error.localizedDescription
    }
}
```

> Confirm `APIError.serverError(message:code:)` shape (from Task 1's APIClient read it's `.serverError(message: String, code: Int?)`). Match the real associated-value labels; if `code` is `Int?`, compare `code == 409`.

- [ ] **Step 4: Run VM tests to verify they pass**

Expected: PASS (4 tests).

- [ ] **Step 5: Create the detail view**

Create `InventoryGroupDetailView.swift` — header, Edit/Promote toolbar, tab picker, member-assets list with add-search + remove, products list. Include a `GroupEditSheet` (Task 8) + `PromoteToProductSheet` (Task 7) presentation. Key structure:

```swift
import SwiftUI

struct InventoryGroupDetailView: View {
    let groupId: String
    @StateObject private var vm: InventoryGroupDetailViewModel
    @State private var showEdit = false
    @State private var showPromote = false
    @State private var showAddAssets = false

    init(groupId: String) {
        self.groupId = groupId
        _vm = StateObject(wrappedValue: InventoryGroupDetailViewModel(groupId: groupId))
    }

    var body: some View {
        List {
            if let g = vm.group {
                headerSection(g)
                if GroupActions.alreadyLinked(g) {
                    Text("Linked to \(g.linkedProductCount ?? 0) product(s). Creating another shares the same stock.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Picker("", selection: $vm.tab) {
                Text("Member Assets").tag(InventoryGroupDetailViewModel.Tab.assets)
                Text("Linked Products").tag(InventoryGroupDetailViewModel.Tab.products)
            }.pickerStyle(.segmented)

            if vm.tab == .assets { assetsSection } else { productsSection }
        }
        .navigationTitle(vm.group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "pencil") }
                    .accessibilityIdentifier("group-edit")
                Button { showPromote = true } label: { Image(systemName: "arrow.up.right") }
                    .accessibilityIdentifier("group-promote")
            }
        }
        .sheet(isPresented: $showEdit) { if let g = vm.group { GroupEditSheet(group: g) { Task { await vm.load() } } } }
        .sheet(isPresented: $showPromote) { if let g = vm.group { PromoteToProductSheet(group: g) { Task { await vm.load() } } } }
        .overlay { if let e = vm.errorMessage { ErrorBanner(text: e) } }  // reuse Phase-2 error surface; or a simple Text
        .task { await vm.load() }
    }

    private func headerSection(_ g: InventoryGroup) -> some View {
        Section {
            if let sku = g.sku { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
            HStack {
                Label("\(g.inStockCount ?? 0) in stock", systemImage: "shippingbox")
                Spacer()
                Text("\(g.totalAssetCount ?? 0) total").foregroundStyle(.secondary)
            }.font(.subheadline)
        }
    }

    private var assetsSection: some View {
        Section {
            Button { showAddAssets = true } label: { Label("Add Assets", systemImage: "plus") }
                .accessibilityIdentifier("group-add-assets")
            ForEach(vm.assets) { asset in
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.assetTag).font(.subheadline.monospaced())
                    Text(asset.name).font(.caption).foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await vm.removeMember(assetId: asset.id) } } label: { Label("Remove", systemImage: "trash") }
                }
                .onAppear { if asset.id == vm.assets.last?.id { Task { await vm.loadMoreAssets() } } }
            }
            if vm.assets.isEmpty && !vm.isLoading { Text("No assets in this group").foregroundStyle(.secondary) }
        }
        .sheet(isPresented: $showAddAssets) { GroupAddAssetsSheet(vm: vm) }
    }

    private var productsSection: some View {
        Section {
            ForEach(vm.products) { p in
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.subheadline)
                    HStack(spacing: 8) {
                        if let sku = p.sku { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                        if let t = p.qualityTier { Text(t).font(.caption).foregroundStyle(.accentColor) }
                        if let q = p.quantityRequired { Text("Qty \(q)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            if vm.products.isEmpty && !vm.isLoading { Text("No products linked").foregroundStyle(.secondary) }
        }
    }
}
```

Create `GroupAddAssetsSheet` (in the same file or its own) — a search field (debounced) over `InventoryService.fetchAssets(filters: AssetQuery(status: "in_stock", search: term))`, listing in-stock assets not already members, each with an "Add" button calling `vm.addMember(assetId:)`. Use the existing `AssetQuery` type (grep its init). Show an inline error from `vm.errorMessage`.

> If `ErrorBanner` doesn't exist, use a simple inline `Text(e).foregroundStyle(.red)`; match whatever Phase-2 sheets use for inline errors.

- [ ] **Step 6: Build + run detail VM tests**

Build (needs Tasks 7 & 8's sheets — sequence them first, or stub). Run `InventoryGroupDetailViewModelTests`. Expected: BUILD SUCCEEDED, PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(inventory): Phase 3 group detail view + add/remove member (two-step remove)"
```

---

## Task 6: GroupSelectorSheet + make the detail card editable

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupSelectorSheet.swift`
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailView.swift` (add "Manage" button to the Inventory Groups card; always render the card so it's reachable even with zero groups)
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift` (add a `manageGroups` bulk-assign method + sibling-result message)
- Test: `Repair Minder/Repair MinderTests/InventoryGroupSelectorTests.swift`

- [ ] **Step 1: Write the failing tests (VM bulk-assign + sibling message)**

```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryGroupSelectorTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var assignedIds: [String]?
        var result = BulkAssignGroupsResult(groupsAdded: 0, groupsRemoved: 0, assetsAffected: 1)
        override func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult {
            assignedIds = groupIds; return result
        }
    }
    func testManageGroupsSendsDesiredSetAndPostsNotification() async {
        let mock = Mock()
        let vm = InventoryDetailViewModel(assetId: "a1", service: mock)   // match the real init label
        var notified = false
        let token = NotificationCenter.default.addObserver(forName: .inventoryAssetDidChange, object: nil, queue: nil) { _ in notified = true }
        defer { NotificationCenter.default.removeObserver(token) }
        await vm.manageGroups(groupIds: ["g1", "g2"])
        XCTAssertEqual(mock.assignedIds, ["g1", "g2"])
        XCTAssertTrue(notified)
    }
    func testSiblingMessageForSkuPropagation() {
        let r = BulkAssignGroupsResult(groupsAdded: 1, groupsRemoved: 0, assetsAffected: 3, siblingMatch: "sku", skuValue: "SCR-14")
        XCTAssertEqual(InventoryDetailViewModel.siblingMessage(r), #"Groups updated across 3 assets with SKU "SCR-14""#)
        let single = BulkAssignGroupsResult(groupsAdded: 1, groupsRemoved: 0, assetsAffected: 1)
        XCTAssertEqual(InventoryDetailViewModel.siblingMessage(single), "Groups updated")
    }
}
```

> Match the real `InventoryDetailViewModel` init label (grep it — likely `init(assetId:service:)` or `init(id:service:)`). Adjust the test accordingly.

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `value of type 'InventoryDetailViewModel' has no member 'manageGroups'`.

- [ ] **Step 3: Add `manageGroups` + `siblingMessage` to the detail VM**

In `InventoryDetailViewModel.swift`:

```swift
    @Published var groupActionMessage: String?   // toast/inline after bulk-assign

    func manageGroups(groupIds: [String]) async {
        isMutating = true; defer { isMutating = false }
        do {
            let result = try await service.bulkAssignGroups(assetId: assetId, groupIds: groupIds)
            groupActionMessage = Self.siblingMessage(result)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            await refresh()   // reload detail so the Inventory Groups card updates
        } catch {
            errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    static func siblingMessage(_ r: BulkAssignGroupsResult) -> String {
        guard r.assetsAffected > 1 else { return "Groups updated" }
        if r.siblingMatch == "sku", let sku = r.skuValue {
            return "Groups updated across \(r.assetsAffected) assets with SKU \"\(sku)\""
        }
        return "Groups updated across \(r.assetsAffected) assets with same name"
    }
```

> Use the VM's real property names for `assetId`, `service`, `isMutating`, `errorMessage`, and its refresh method (`refresh()`); grep them.

- [ ] **Step 4: Run to verify it passes**

Expected: PASS.

- [ ] **Step 5: Build the `GroupSelectorSheet` + wire the card**

Create `GroupSelectorSheet.swift`:

```swift
import SwiftUI

struct GroupSelectorSheet: View {
    let assetId: String
    /// Pre-selected group ids (from the asset's current groups).
    let initialSelection: [String]
    /// Called with the desired id set on Save.
    let onSave: ([String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var groups: [InventoryGroup] = []
    @State private var search = ""
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    private let service = InventoryService()

    var body: some View {
        NavigationStack {
            List {
                if let e = errorMessage { Text(e).foregroundStyle(.red) }
                ForEach(groups) { g in
                    Button {
                        if selected.contains(g.id) { selected.remove(g.id) } else { selected.insert(g.id) }
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(g.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(g.id) ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading) {
                                Text(g.name)
                                if let sku = g.sku, !sku.isEmpty { Text(sku).font(.caption.monospaced()).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text("\(g.inStockCount ?? 0)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("select-group-\(g.sku ?? g.id)")
                }
                if canCreate {
                    Button { Task { await createGroup() } } label: {
                        Label(isCreating ? "Creating…" : "Add new \"\(search)\"", systemImage: "plus")
                    }.disabled(isCreating)
                }
            }
            .searchable(text: $search)
            .task(id: search) { await loadGroups() }
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(isSaving)
                        .accessibilityIdentifier("group-selector-save")
                }
            }
            .onAppear { selected = Set(initialSelection) }
        }
    }

    private var canCreate: Bool {
        let t = search.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && !groups.contains { $0.name.lowercased() == t.lowercased() }
    }

    private func loadGroups() async {
        isLoading = true; defer { isLoading = false }
        do {
            groups = try await service.listGroups(page: 1, limit: 30, search: search.isEmpty ? nil : search,
                                                   category: nil, hasProducts: nil, unlinkedOnly: nil, sortBy: "name", sortOrder: "asc")
        } catch { errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription }
    }

    private func createGroup() async {
        let name = search.trimmingCharacters(in: .whitespaces); guard !name.isEmpty else { return }
        isCreating = true; defer { isCreating = false }
        do {
            let g = try await service.createGroup(GroupFormRequest(name: name, category: "General"))
            selected.insert(g.id); search = ""; await loadGroups()
        } catch { errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription }
    }

    private func save() async {
        isSaving = true; defer { isSaving = false }
        await onSave(Array(selected))
        dismiss()
    }
}
```

In `InventoryDetailView.swift`, change the Inventory Groups card to always render and add a Manage button that presents the sheet:

```swift
// replace `if !viewModel.groups.isEmpty { card("Inventory Groups") { ... } }` with:
card("Inventory Groups") {
    if viewModel.groups.isEmpty {
        Text("No groups assigned").font(.caption).foregroundStyle(.secondary)
    } else {
        ForEach(viewModel.groups) { g in /* existing rows unchanged */ }
    }
    Button { showManageGroups = true } label: { Label("Manage", systemImage: "square.and.pencil") }
        .buttonStyle(.bordered).padding(.top, 4)
        .accessibilityIdentifier("manage-groups")
}
// add @State private var showManageGroups = false
// add a .sheet on the detail view:
.sheet(isPresented: $showManageGroups) {
    GroupSelectorSheet(
        assetId: viewModel.assetId,
        initialSelection: viewModel.groups.map(\.id)
    ) { desired in await viewModel.manageGroups(groupIds: desired) }
}
// surface viewModel.groupActionMessage as a transient toast/inline note if present
```

Confirm `viewModel.assetId` exists (else use the id the VM was created with).

- [ ] **Step 6: Build to verify it compiles**

Build. Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(inventory): Phase 3 GroupSelectorSheet + editable Inventory Groups card"
```

---

## Task 7: PromoteToProductSheet

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/PromoteToProductSheet.swift`
- Test: extend `Repair Minder/Repair MinderTests/InventoryGroupDetailViewModelTests.swift` (or a new `PromoteSheetTests`) with a promote-encoding + 409-mapping VM-less test using the service mock.

- [ ] **Step 1: Write the failing test (promote request prefill + 409 mapping)**

Add a small `@MainActor` model test that exercises a `PromoteSheetModel` (extracted logic) — prefill from group + error mapping:

```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class PromoteSheetTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var sent: PromoteGroupRequest?
        var error: Error?
        override func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult {
            sent = body
            if let error { throw error }
            return PromoteResult(product: PromotedProduct(id: "p1"), component: PromotedComponent(id: "c1"))
        }
    }
    func testPrefillFromGroup() {
        var g = InventoryGroup(id: "g1", name: "iPhone Screen"); g.sku = "SCR-14"; g.category = "Screens"; g.defaultSellPrice = 49
        let m = PromoteSheetModel(group: g, service: Mock())
        XCTAssertEqual(m.name, "iPhone Screen")
        XCTAssertEqual(m.sku, "PROD-SCR-14")
        XCTAssertEqual(m.category, "Screens")
        XCTAssertEqual(m.sellPrice, "49")
    }
    func testSubmitSendsRequest() async {
        var g = InventoryGroup(id: "g1", name: "Screen"); g.sku = "SCR-14"
        let mock = Mock(); let m = PromoteSheetModel(group: g, service: mock)
        m.sellPrice = "89"
        let ok = await m.submit()
        XCTAssertTrue(ok)
        XCTAssertEqual(mock.sent?.groupId, "g1")
        XCTAssertEqual(mock.sent?.productName, "Screen")
        XCTAssertEqual(mock.sent?.defaultSellPrice, 89)
    }
    func testDuplicateSkuMapsToFieldError() async {
        var g = InventoryGroup(id: "g1", name: "Screen")
        let mock = Mock(); mock.error = APIError.serverError(message: "A product with that SKU already exists", code: 409)
        let m = PromoteSheetModel(group: g, service: mock)
        let ok = await m.submit()
        XCTAssertFalse(ok)
        XCTAssertNotNil(m.skuError)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `cannot find 'PromoteSheetModel'`.

- [ ] **Step 3: Create the sheet + its model**

Create `PromoteToProductSheet.swift`:

```swift
import SwiftUI

@MainActor
final class PromoteSheetModel: ObservableObject {
    let group: InventoryGroup
    @Published var name: String
    @Published var sku: String
    @Published var category: String
    @Published var sellPrice: String
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var skuError: String?
    private let service: InventoryServing

    init(group: InventoryGroup, service: InventoryServing? = nil) {
        self.group = group
        self.service = service ?? InventoryService()
        self.name = group.name
        self.sku = (group.sku?.isEmpty == false) ? "PROD-\(group.sku!)" : ""
        self.category = group.category ?? ""
        self.sellPrice = group.defaultSellPrice.map { String(format: "%g", $0) } ?? ""
    }

    func submit() async -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { errorMessage = "Product name is required"; return false }
        isSubmitting = true; defer { isSubmitting = false }
        errorMessage = nil; skuError = nil
        let req = PromoteGroupRequest(
            groupId: group.id,
            productName: name.trimmingCharacters(in: .whitespaces),
            productSku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
            productCategory: category.isEmpty ? nil : category,
            defaultSellPrice: Double(sellPrice))
        do {
            _ = try await service.promoteGroup(req)
            return true
        } catch {
            if case let APIError.serverError(message, code) = error,
               code == 409 || message.lowercased().contains("sku") {
                skuError = "This SKU is already in use. Choose a different one."
            } else {
                errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            }
            return false
        }
    }
}

struct PromoteToProductSheet: View {
    @StateObject private var model: PromoteSheetModel
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(group: InventoryGroup, onSuccess: @escaping () -> Void) {
        _model = StateObject(wrappedValue: PromoteSheetModel(group: group))
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(model.group.name).font(.headline)
                    Text("\(model.group.inStockCount ?? 0) items in stock").font(.caption).foregroundStyle(.secondary)
                    Text("Creates a sellable product backed by this group's stock.").font(.caption).foregroundStyle(.secondary)
                    if GroupActions.alreadyLinked(model.group) {
                        Text("Already linked to \(model.group.linkedProductCount ?? 0) product(s). Creating another shares the same stock.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section {
                    TextField("Product name", text: $model.name).accessibilityIdentifier("promote-name")
                    TextField("SKU", text: $model.sku)
                    if let e = model.skuError { Text(e).font(.caption).foregroundStyle(.red) }
                    TextField("Category", text: $model.category)
                    TextField("Sell price", text: $model.sellPrice).keyboardType(.decimalPad)
                }
                if let e = model.errorMessage { Text(e).foregroundStyle(.red) }
            }
            .navigationTitle("Promote to Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { if await model.submit() { onSuccess(); dismiss() } } }
                        .disabled(model.isSubmitting)
                        .accessibilityIdentifier("promote-create")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests + build**

Run `PromoteSheetTests`; build. Expected: PASS, BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(inventory): Phase 3 PromoteToProductSheet with 409 SKU mapping"
```

---

## Task 8: GroupEditSheet (full metadata edit)

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Groups/GroupEditSheet.swift`
- Test: `Repair Minder/Repair MinderTests/GroupEditSheetTests.swift`

- [ ] **Step 1: Write the failing test (edit form → request mapping)**

```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class GroupEditSheetTests: XCTestCase {
    final class Mock: InventoryServingStub {
        var sent: GroupFormRequest?
        override func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup {
            sent = body; return InventoryGroup(id: id, name: body.name)
        }
    }
    func testPrefillAndSubmitMapsAllFields() async {
        var g = InventoryGroup(id: "g1", name: "Screens")
        g.sku = "SCR"; g.category = "Screens"; g.reorderLevel = 5; g.defaultCost = 12; g.isOem = 1
        let mock = Mock()
        let m = GroupEditModel(group: g, service: mock)
        XCTAssertEqual(m.name, "Screens"); XCTAssertEqual(m.sku, "SCR"); XCTAssertTrue(m.isOem)
        m.name = "Screens v2"; m.reorderLevel = "8"
        let ok = await m.submit()
        XCTAssertTrue(ok)
        XCTAssertEqual(mock.sent?.name, "Screens v2")
        XCTAssertEqual(mock.sent?.reorderLevel, 8)
        XCTAssertEqual(mock.sent?.isOem, 1)
        XCTAssertEqual(mock.sent?.category, "Screens")
    }
    func testEmptyNameBlocksSubmit() async {
        let m = GroupEditModel(group: InventoryGroup(id: "g1", name: "X"), service: Mock())
        m.name = "   "
        let ok = await m.submit()
        XCTAssertFalse(ok); XCTAssertNotNil(m.errorMessage)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `cannot find 'GroupEditModel'`.

- [ ] **Step 3: Create the edit sheet + model**

```swift
import SwiftUI

@MainActor
final class GroupEditModel: ObservableObject {
    let groupId: String
    @Published var name: String
    @Published var sku: String
    @Published var category: String
    @Published var subcategory: String
    @Published var manufacturer: String
    @Published var modelNumber: String
    @Published var reorderLevel: String
    @Published var reorderQuantity: String
    @Published var defaultCost: String
    @Published var defaultSellPrice: String
    @Published var preferredSupplierName: String
    @Published var isOem: Bool
    @Published var isRefurbished: Bool
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    private let service: InventoryServing

    init(group: InventoryGroup, service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
        self.groupId = group.id
        self.name = group.name
        self.sku = group.sku ?? ""
        self.category = group.category ?? ""
        self.subcategory = group.subcategory ?? ""
        self.manufacturer = group.manufacturer ?? ""
        self.modelNumber = group.modelNumber ?? ""
        self.reorderLevel = group.reorderLevel.map(String.init) ?? ""
        self.reorderQuantity = group.reorderQuantity.map(String.init) ?? ""
        self.defaultCost = group.defaultCost.map { String(format: "%g", $0) } ?? ""
        self.defaultSellPrice = group.defaultSellPrice.map { String(format: "%g", $0) } ?? ""
        self.preferredSupplierName = group.preferredSupplierName ?? ""
        self.isOem = group.isOemBool
        self.isRefurbished = group.isRefurbishedBool
    }

    func submit() async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name is required"; return false }
        isSubmitting = true; defer { isSubmitting = false }; errorMessage = nil
        let body = GroupFormRequest(
            name: trimmed,
            category: category.isEmpty ? "General" : category,   // backend requires non-empty
            sku: sku.isEmpty ? nil : sku,
            subcategory: subcategory.isEmpty ? nil : subcategory,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            modelNumber: modelNumber.isEmpty ? nil : modelNumber,
            reorderLevel: Int(reorderLevel),
            reorderQuantity: Int(reorderQuantity),
            defaultCost: Double(defaultCost),
            defaultSellPrice: Double(defaultSellPrice),
            preferredSupplierName: preferredSupplierName.isEmpty ? nil : preferredSupplierName,
            isOem: isOem ? 1 : 0,
            isRefurbished: isRefurbished ? 1 : 0)
        do { _ = try await service.updateGroup(id: groupId, body: body); return true }
        catch { errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription; return false }
    }
}

struct GroupEditSheet: View {
    @StateObject private var model: GroupEditModel
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(group: InventoryGroup, onSuccess: @escaping () -> Void) {
        _model = StateObject(wrappedValue: GroupEditModel(group: group))
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $model.name).accessibilityIdentifier("group-edit-name")
                    TextField("SKU", text: $model.sku)
                    TextField("Category", text: $model.category)
                    TextField("Subcategory", text: $model.subcategory)
                    TextField("Manufacturer", text: $model.manufacturer)
                    TextField("Model number", text: $model.modelNumber)
                }
                Section("Stock") {
                    TextField("Reorder level", text: $model.reorderLevel).keyboardType(.numberPad)
                    TextField("Reorder quantity", text: $model.reorderQuantity).keyboardType(.numberPad)
                    TextField("Default cost", text: $model.defaultCost).keyboardType(.decimalPad)
                    TextField("Default sell price", text: $model.defaultSellPrice).keyboardType(.decimalPad)
                    TextField("Preferred supplier", text: $model.preferredSupplierName)
                    Toggle("OEM", isOn: $model.isOem)
                    Toggle("Refurbished", isOn: $model.isRefurbished)
                }
                if let e = model.errorMessage { Text(e).foregroundStyle(.red) }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { if await model.submit() { onSuccess(); dismiss() } } }
                        .disabled(model.isSubmitting)
                        .accessibilityIdentifier("group-edit-save")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run tests + full build**

Run `GroupEditSheetTests`; then a FULL build. Expected: PASS, BUILD SUCCEEDED (all sheets now exist — remove any temporary stubs from Tasks 4/5).

- [ ] **Step 5: Run the WHOLE inventory test suite**

Run all inventory test classes (Model/Actions/GroupsList/GroupDetail/Selector/Promote/Edit + the Phase-2 classes) with `-only-testing` for each, or the whole `Repair MinderTests` bundle. Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(inventory): Phase 3 GroupEditSheet (full product-type metadata edit)"
```

---

## Task 9: XCUITest — drive a Groups write flow

**Files:**
- Create: `Repair Minder/Repair MinderUITests/InventoryGroupsUITest.swift` (reuse the login helper from `InventoryEditActionUITest`)

- [ ] **Step 1: Write the UI test**

Mirror `InventoryEditActionUITest`. Flow: launch → Magic-Link login (demo `appstore-demo@repairminder.com`, code `123456`) → open Inventory → prime the FAB overlay with a neutral tap → tap the first asset row by its asset-tag static text → tap `manage-groups` → in the sheet tap the first `select-group-*` row → tap `group-selector-save` → assert we're back on the detail (e.g. the `manage-groups` button exists again). `XCTSkip` if no asset/group rows appear (demo company empty → CI-safe).

```swift
import XCTest

final class InventoryGroupsUITest: XCTestCase {
    func testManageGroupsFromAssetDetail() throws {
        let app = XCUIApplication()
        app.launch()
        LoginHelper.magicLinkLogin(app)   // reuse the Phase-2 helper (extract it if it's private to the other file)

        // Navigate to Inventory (More → Inventory). Reuse the Phase-2 navigation steps.
        InventoryNav.open(app)

        // Prime the app-wide FAB overlay (swallows the first content tap).
        app.tap()

        // Tap the first asset row by asset-tag static text; skip if none.
        let firstAsset = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'AST'")).firstMatch
        guard firstAsset.waitForExistence(timeout: 8) else { throw XCTSkip("Demo company has no assets") }
        firstAsset.tap()

        let manage = app.buttons["manage-groups"]
        guard manage.waitForExistence(timeout: 8) else { throw XCTSkip("No asset detail / manage button") }
        manage.tap()

        let firstGroup = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'select-group-'")).firstMatch
        guard firstGroup.waitForExistence(timeout: 8) else { throw XCTSkip("Demo company has no groups") }
        firstGroup.tap()

        app.buttons["group-selector-save"].tap()

        XCTAssertTrue(manage.waitForExistence(timeout: 8), "Back on asset detail after saving groups")
    }
}
```

> Extract the Phase-2 login + inventory-navigation helpers into a shared file if they're currently private to `InventoryEditActionUITest`. Match the real accessibility identifiers already on the asset list rows (Phase 2 used asset-tag static text).

- [ ] **Step 2: Seed the demo company, run the test green**

Seed `demo-company-001` via API/D1 with one in-stock asset + one inventory-item group (and optionally a membership) using an admin-style token for the demo company (or D1 inserts). Run:
```bash
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -parallel-testing-enabled NO -only-testing:"Repair MinderUITests/InventoryGroupsUITest" \
  ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -40
```
Expected: PASS (or `XCTSkip` if seeding was skipped — but for the mandate it MUST run green at least once with seed).

- [ ] **Step 3: Delete the seed**

Hard-delete the seeded demo asset/group/membership via D1 (see Task 10 cleanup). Confirm the demo company is clean.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "test(inventory): Phase 3 XCUITest driving Manage-Groups write flow"
```

---

## Task 10: Live prod E2E of every write + cleanup (NO code — verification gate)

**Goal:** exercise every Phase-3 write against prod, assert the live response decodes into the Swift model, then hard-delete all test data. API delete is SOFT — clean up via D1.

Setup: mint an admin token (rule `repairminder/.claude/rules/api-tokens.md` + `docs/REFERENCE-test-tokens/CLAUDE.md`; admin company `4b63c1e6ade1885e73171e10221cac53` has groups + assets). D1 access:
```bash
cd /Users/rikibaker/Repos/repairminder/worker
set -a; source ../.env.local; set +a
export CLOUDFLARE_EMAIL=$REPAIRMINDER_CF_EMAIL CLOUDFLARE_API_KEY=$REPAIRMINDER_CF_GLOBAL_KEY CLOUDFLARE_ACCOUNT_ID=$REPAIRMINDER_CF_ACCOUNT_ID
```

- [ ] **Step 1: Capture real GET JSON + back the decode fixtures**

`curl` (admin token) `/api/asset-groups?limit=5&sort_by=in_stock_count&sort_order=desc`, `/api/asset-groups/:id`, `/api/asset-groups/:id/assets`, `/api/asset-groups/:id/products`, `/api/assets/:id/groups`. Diff every field's JSON type against the Swift models (Task 1). If anything mismatches, fix the model + its decode test with the REAL JSON, rebuild, re-run tests.

- [ ] **Step 2: CREATE group** — `POST /api/product-types {product_kind:"inventory_item", name:"ZZ-P3-TEST-<ts>", category:"General"}`. Assert 201 `{success,data:<row>}` decodes into `InventoryGroup`. Record the returned `id`.

- [ ] **Step 3: ADD membership** — pick a real in-stock asset id from the admin company; `POST /api/asset-groups/memberships {asset_id, group_id:<new>}`. Assert 201 decodes into `GroupMembership`. Record membership id. (Re-POST once to confirm the **409** duplicate path.)

- [ ] **Step 4: BULK-ASSIGN** — `POST /api/assets/<sameAsset>/groups {group_ids:[<new group>]}`. Assert 200 `{success,data:{...}}` decodes into `BulkAssignGroupsResult`; note `assets_affected`/`sibling_match`/`sku_value`. Then `POST … {group_ids:[]}` to clear and confirm removal counts. **Record every membership row + supplier mapping** this created for cleanup.

- [ ] **Step 5: PROMOTE** — `POST /api/asset-groups/promote {group_id:<new>, product_name:"ZZ-P3-PROD-<ts>"}`. Assert 201 `{success,data:{product,component}}` decodes into `PromoteResult`. Record `product.id` + `component.id`.

- [ ] **Step 6: EDIT group** — `PUT /api/product-types/<new group> {name:"ZZ-P3-TEST-<ts>-edited", category:"General", reorder_level:7}`. Assert `{success,data}` and the change persisted (GET back). Confirm the model decodes the response.

- [ ] **Step 7: REMOVE membership** — resolve a membership via `GET /api/assets/<asset>/groups`, `DELETE /api/asset-groups/memberships/:id`. Assert `{success:true}`.

- [ ] **Step 8: CLEANUP (hard delete via D1)** — for each id you recorded, and ONLY rows you created (verify by `created_at`/the `ZZ-P3-` name prefix):
```sql
DELETE FROM product_components WHERE inventory_product_id = '<new group>' OR service_product_id = '<promoted product>';
DELETE FROM asset_group_memberships WHERE group_id = '<new group>';
DELETE FROM supplier_name_mappings WHERE group_id = '<new group>';
DELETE FROM supplier_sku_mappings WHERE product_type_id = '<new group>';
DELETE FROM product_types WHERE id IN ('<new group>', '<promoted product>');
```
Then verify zero `ZZ-P3-` rows remain in `product_types` and no orphan memberships/mappings, in BOTH the admin and demo companies:
```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT id,name,company_id FROM product_types WHERE name LIKE 'ZZ-P3-%'" 2>&1 | grep -A3 results
```
Expected: empty. **Never delete a row you didn't create** (test names can collide with old real rows — the `ZZ-P3-<ts>` prefix guards this).

- [ ] **Step 9: Record results** — note each write's live response shape + that it matched the Swift model, for the roadmap "Phase 3 complete" note.

---

## Task 11: Release prep + final build

**Files:**
- Modify: `Repair Minder/Repair Minder.xcodeproj/project.pbxproj` (`CURRENT_PROJECT_VERSION` 006 → 007, all targets)

- [ ] **Step 1: Bump the version**

Set `CURRENT_PROJECT_VERSION = 7;` everywhere it's `6` (grep `CURRENT_PROJECT_VERSION` in `project.pbxproj`; update all target build configs consistently, matching how Phase 2's `b471190` bumped 005→006).

- [ ] **Step 2: Final full build (iOS + Mac new-files check)**

iOS build green. Then confirm the new Phase-3 files add ZERO errors under the "Repair Minder Mac" scheme (the pre-existing `Signals/` Diagnostics errors are unrelated — do not touch them):
```bash
xcodebuild build -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder Mac" \
  -destination 'platform=macOS' -derivedDataPath ../build-derived-data \
  -clonedSourcePackagesDirPath /tmp/rm-spm ENABLE_PREVIEWS=NO 2>&1 | grep -i "error:" | grep -iv "Signals/" | head
```
Expected: no Phase-3 file errors.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "chore(ios): bump CURRENT_PROJECT_VERSION 006->007 for Phase 3 release"
```

---

## Final: review, merge, push, handoff (post-plan — see the worker prompt)

After all tasks: run `superpowers:requesting-code-review` (spec-then-quality) on the full branch; address findings; then `superpowers:finishing-a-development-branch` → merge to `main` → `git push origin main`. Then update the roadmap ("Phase 3 complete" + flip Phase 4 to NEXT), add memory `project_ios_inventory_phase3` (link `[[project_ios_inventory_phase2]]`), update `MEMORY.md`, and write `docs/superpowers/PHASE4-WORKER-PROMPT.md` carrying both mandates.

---

## Self-review notes (author)

- **Spec coverage:** every row of the No-Deferral Checklist maps to a task — list/sort/filter (T4), detail + tabs + add/remove (T5), bulk-assign + editable card + inline create (T6), promote (T7), full edit (T8), XCUITest (T9), live E2E of every write (T10). ✓
- **`requestFull` avoided:** bulk-assign uses `request<BulkAssignGroupsResult>` (nested `data`). ✓
- **Type consistency:** service method names used in VMs (`listGroups`, `fetchGroup`, `fetchGroupAssets`, `fetchGroupProducts`, `addMembership`, `removeMembership`, `bulkAssignGroups`, `promoteGroup`, `createGroup`, `updateGroup`) match the protocol in T3. Models (`InventoryGroup`, `LinkedProduct`, `GroupMembership`, `BulkAssignGroupsResult`, `PromoteResult`, request structs) defined in T1 and used consistently. ✓
- **Known unknowns to confirm while building (grep, don't guess):** `APIError.serverError` associated-value labels + `userMessage`; `InventoryDetailViewModel` init label + `assetId`/`refresh()`/`isMutating`/`errorMessage` names; `AssetQuery` init; `Asset` init labels used in tests; `AssetGroupSummary` memberwise-init labels; the existing search-text property on the assets list; whether an `ErrorBanner`/inline-error component exists. Each is flagged inline in the relevant task.
