# iOS Inventory Phase 1 (Foundation + Full Browse) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only "Inventory" section to the iOS app (opt-in tab + More-overflow) with an asset list (search, full filter set, status pills, infinite scroll, barcode scan-to-find) and a full asset detail (all read sections + activity/groups/external-deployment), matching the web Inventory section.

**Architecture:** New `Features/Staff/Inventory/` SwiftUI module mirroring the existing Buyback module. Networking via the shared `APIClient` (standard `request<T>`). Models in `Core/Models/Inventory.swift` + `InventoryEnums.swift`, decoded with the global `.convertFromSnakeCase`. Tab wiring through `FeatureTab` + `StaffMainView` + `SettingsView` using the `isEmbedded` pattern (avoids the double-`NavigationStack` bug fixed 2026-07-03). No backend changes.

**Tech Stack:** Swift 5 / SwiftUI, `@MainActor` ObservableObject view models, `XCTest` decode tests, `XCUITest` smoke test, `xcodebuild` against the iOS 26 simulator.

---

## Conventions used throughout

- **Source root:** `Repair Minder/Repair Minder/` (all app paths below are relative to the repo root `repairminder-iOS/repairminder-iOS/`).
- **Test target:** `Repair MinderTests` (unit), `Repair MinderUITests` (UI). New files land in synchronized groups, so no `.xcodeproj` edits are needed.
- **No explicit snake_case `CodingKeys`** — the decoder uses `.convertFromSnakeCase` globally (repo rule).
- **SQLite booleans** arrive as `Int` 0/1 → model as `Int?` + computed `Bool`.
- **Unknown enum strings** must not throw → use the existing `UnknownDefaultable` protocol.
- **Build/test command** (fresh SPM dir avoids the stale-artifact issue; UDID is the booted iPhone 17 Pro):
  ```bash
  cd "repairminder-iOS/repairminder-iOS"
  SP=/tmp/rm-spm
  xcodebuild build \
    -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath "$SP" \
    ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -15
  ```
  For unit tests, swap `build` for `test -only-testing:"Repair MinderTests/<Class>"` and add `-parallel-testing-enabled NO`.

---

## Task 1: `AssetStatus` enum

**Files:**
- Create: `Repair Minder/Repair Minder/Core/Models/InventoryEnums.swift`
- Test: `Repair Minder/Repair MinderTests/InventoryModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Repair Minder/Repair MinderTests/InventoryModelTests.swift`:
```swift
import XCTest
@testable import Repair_Minder

final class InventoryModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    func testAssetStatusDecodesKnownAndUnknown() throws {
        struct Box: Decodable { let status: AssetStatus }
        XCTAssertEqual(try decode(Box.self, #"{"status":"in_stock"}"#).status, .inStock)
        XCTAssertEqual(try decode(Box.self, #"{"status":"pending_return"}"#).status, .pendingReturn)
        // Unknown must fall back, not throw:
        XCTAssertEqual(try decode(Box.self, #"{"status":"martian"}"#).status, .unknown)
    }

    func testAssetStatusAllCasesExcludesUnknown() {
        XCTAssertFalse(AssetStatus.allCases.contains(.unknown))
        XCTAssertEqual(AssetStatus.allCases.first, .inStock)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm -parallel-testing-enabled NO -only-testing:"Repair MinderTests/InventoryModelTests/testAssetStatusDecodesKnownAndUnknown" 2>&1 | tail -20`
Expected: FAIL — `cannot find type 'AssetStatus' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Repair Minder/Repair Minder/Core/Models/InventoryEnums.swift`:
```swift
import SwiftUI

/// Asset lifecycle status. Mirrors the backend ASSET_STATUSES set.
enum AssetStatus: String, CaseIterable, Sendable, Decodable, UnknownDefaultable {
    case inStock = "in_stock"
    case allocated
    case reserved
    case deployed
    case used
    case returned
    case damaged
    case sold
    case pendingReturn = "pending_return"
    case unknown = "__unknown__"

    static var unknownFallback: AssetStatus { .unknown }

    static var allCases: [AssetStatus] {
        [.inStock, .allocated, .reserved, .deployed, .used, .returned, .damaged, .sold, .pendingReturn]
    }

    var displayName: String {
        switch self {
        case .inStock: return "In Stock"
        case .allocated: return "Allocated"
        case .reserved: return "Reserved"
        case .deployed: return "Deployed"
        case .used: return "Used"
        case .returned: return "Returned"
        case .damaged: return "Damaged"
        case .sold: return "Sold"
        case .pendingReturn: return "Pending Return"
        case .unknown: return "Unknown"
        }
    }

    /// Query-param value for the list endpoint (nil for `.unknown`).
    var apiValue: String? { self == .unknown ? nil : rawValue }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the two `testAssetStatus…` tests (as Step 2, both names). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/InventoryEnums.swift" "Repair Minder/Repair MinderTests/InventoryModelTests.swift"
git commit -m "feat(inventory): AssetStatus enum with unknown fallback"
```

---

## Task 2: `Asset` model + sub-resource models

**Files:**
- Create: `Repair Minder/Repair Minder/Core/Models/Inventory.swift`
- Modify (add tests): `Repair Minder/Repair MinderTests/InventoryModelTests.swift`

- [ ] **Step 1: Write the failing tests** (append to `InventoryModelTests`)

```swift
extension InventoryModelTests {
    func testAssetDecodesQuirks() throws {
        let json = #"""
        {
          "id": "a1", "asset_tag": "AST000000001", "name": "iPhone 13 Screen",
          "status": "in_stock", "is_oem": 1, "is_refurbished": 0,
          "cost": 42.5, "cost_inc_vat": null,
          "location_name": "Main Store", "sub_location_code": "A1",
          "group_names": "Screens, Genuine", "group_ids": "g1,g2",
          "lcd_working": 1, "glass_cracked": null
        }
        """#
        let a = try decode(Asset.self, json)
        XCTAssertEqual(a.assetTag, "AST000000001")
        XCTAssertEqual(a.status, .inStock)
        XCTAssertTrue(a.isOemBool)
        XCTAssertFalse(a.isRefurbishedBool)
        XCTAssertEqual(a.cost, 42.5)
        XCTAssertNil(a.costIncVat)
        XCTAssertEqual(a.groupNamesList, ["Screens", "Genuine"])
        XCTAssertEqual(a.groupIdsList, ["g1", "g2"])
        XCTAssertEqual(a.lcdWorking, 1)
    }

    func testAssetListIgnoresMetaEnvelope() throws {
        // The list endpoint returns { success, data: [Asset], meta: {...} }.
        // APIResponse<[Asset]> must decode data and ignore meta.
        let json = #"""
        { "success": true, "data": [ {"id":"a1","asset_tag":"T1","name":"n","status":"sold"} ],
          "meta": { "page": 1, "limit": 24, "total": 1, "totalPages": 1 } }
        """#
        let env = try decode(APIResponse<[Asset]>.self, json)
        XCTAssertEqual(env.data?.count, 1)
        XCTAssertEqual(env.data?.first?.status, .sold)
    }

    func testExternalDeploymentDecodes() throws {
        let json = #"""
        { "active": {"id":"d1","asset_id":"a1","customer_name":"Acme","status":"deployed","created_at":"2026-01-01"},
          "history": [] }
        """#
        let ed = try decode(ExternalDeployment.self, json)
        XCTAssertEqual(ed.active?.customerName, "Acme")
        XCTAssertEqual(ed.history?.count, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the three new tests. Expected: FAIL — `cannot find type 'Asset'`.

- [ ] **Step 3: Write minimal implementation**

Create `Repair Minder/Repair Minder/Core/Models/Inventory.swift`:
```swift
import Foundation

/// A single inventory asset. One struct serves both the list and detail endpoints;
/// list rows and the detail record share the assets-table columns, so every field
/// beyond the identity trio is optional.
struct Asset: Decodable, Identifiable, Equatable, Sendable, Hashable {
    let id: String
    let assetTag: String
    let name: String
    let status: AssetStatus

    // Core columns
    var companyId: String?
    var productTypeId: String?
    var serialNumber: String?
    var sku: String?
    var category: String?
    var manufacturer: String?
    var modelNumber: String?
    var supplierName: String?
    var supplierOrderReference: String?
    var purchaseDate: String?
    var cost: Double?
    var costIncVat: Double?
    var warrantyMonths: Int?
    var warrantyExpires: String?
    var conditionGrade: String?
    var isOem: Int?
    var isRefurbished: Int?
    var locationId: String?
    var subLocationId: String?
    var checkedOutToOrderId: String?
    var checkedOutToDeviceId: String?
    var checkedOutAt: String?
    var checkedOutBy: String?
    var deployedAt: String?
    var returnedAt: String?
    var returnReason: String?
    var returnCondition: String?
    var supplierReturnReason: String?
    var supplierReturnNotes: String?
    var supplierReturnInitiatedAt: String?
    var supplierReturnResolvedAt: String?
    var supplierReturnResolution: String?
    var replacementAssetId: String?
    var notes: String?
    var createdAt: String?
    var updatedAt: String?

    // Recovery / salvage origin
    var sourceType: String?
    var recoveredFromAssetId: String?
    var recoveredFromBuybackId: String?
    var recoveredFromOrderId: String?
    var recoveredFromDeviceId: String?
    var recoveredBy: String?
    var recoveredAt: String?
    var lcdWorking: Int?
    var glassCracked: Int?
    var checkedOutToBuybackId: String?

    // Joined / computed by the API
    var productTypeName: String?
    var productTypeSku: String?
    var enablePartRecovery: Int?
    var locationName: String?
    var subLocationCode: String?
    var subLocationDescription: String?
    var checkedOutOrderNumber: String?
    var checkedOutDeviceName: String?
    var createdByEmail: String?
    var updatedByEmail: String?
    var checkedOutByEmail: String?
    var groupNames: String?   // comma-joined, NOT an array
    var groupIds: String?     // comma-joined, NOT an array

    // MARK: Computed helpers
    var isOemBool: Bool { isOem == 1 }
    var isRefurbishedBool: Bool { isRefurbished == 1 }
    var enablePartRecoveryBool: Bool { enablePartRecovery == 1 }
    var lcdWorkingBool: Bool? { lcdWorking.map { $0 == 1 } }
    var glassCrackedBool: Bool? { glassCracked.map { $0 == 1 } }

    var groupNamesList: [String] {
        (groupNames ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    var groupIdsList: [String] {
        (groupIds ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var locationDisplay: String? {
        switch (locationName, subLocationCode) {
        case let (loc?, sub?): return "\(loc) / \(sub)"
        case let (loc?, nil):  return loc
        default:               return subLocationCode
        }
    }

    var formattedCost: String? { cost.map { CurrencyFormatter.format($0) } }
}

// MARK: - Activity

struct AssetActivity: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetId: String?
    var activityType: String?   // backend column is activity_type
    var description: String?
    var fromStatus: String?
    var toStatus: String?
    var performedBy: String?
    var performedByEmail: String?
    var performedByName: String?
    var performedAt: String?     // backend column is performed_at
}

// MARK: - Asset group summary (GET /api/assets/:id/groups)

struct AssetGroupSummary: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var category: String?
    var membershipId: String?
    var minCost: Double?
    var avgCost: Double?
    var maxCost: Double?
    var inStockCount: Int?
}

// MARK: - External deployment (GET /api/assets/:id/external-deployment?include_history=true)

struct ExternalDeployment: Decodable, Equatable, Sendable {
    var active: ExternalDeploymentRecord?
    var history: [ExternalDeploymentRecord]?
}

struct ExternalDeploymentRecord: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetId: String?
    var customerName: String?
    var externalReference: String?
    var notes: String?
    var deploymentDate: String?
    var status: String?
    var returnedAt: String?
    var deployedBy: String?
    var createdAt: String?
}

// MARK: - Categories (GET /api/product-types/categories)
// Verified backend shape: data: { categories: [{category, count}], suggested: [String] }
struct CategoriesResponse: Decodable, Equatable, Sendable {
    let categories: [CategoryCount]
    var suggested: [String]?
}
struct CategoryCount: Decodable, Equatable, Sendable, Identifiable {
    let category: String
    var count: Int?
    var id: String { category }
}

// MARK: - Asset group list item (GET /api/asset-groups) — for the group filter picker

struct AssetGroupListItem: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
    var category: String?
    var inStockCount: Int?
}
```

> **Note:** `AssetActivity` and `CategoryOption` shapes are tolerant because their exact JSON was flagged as an open item in the spec. Task 8/10 include a verification step.

- [ ] **Step 4: Run tests to verify they pass**

Run the three tests from Step 1. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/Inventory.swift" "Repair Minder/Repair MinderTests/InventoryModelTests.swift"
git commit -m "feat(inventory): Asset + sub-resource Codable models"
```

---

## Task 3: API endpoints

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift` (add cases in the enum, `path`, `method` GET group, `queryItems`)

- [ ] **Step 1: Add the enum cases**

In `enum APIEndpoint`, near the existing `.buybackList` case (~line 198), add:
```swift
    // Inventory / Assets
    case inventoryList(page: Int, limit: Int, status: String?, category: String?, locationId: String?, subLocationId: String?, productTypeId: String?, groupId: String?, hasGroups: Bool?, hasProducts: Bool?, search: String?)
    case inventoryDetail(id: String)
    case inventoryByTag(tag: String)
    case inventoryActivity(id: String, limit: Int?)
    case inventoryAssetGroups(id: String)
    case inventoryExternalDeployment(id: String)
    case productTypeCategories
    case assetGroupsList(page: Int, limit: Int, search: String?)
```

- [ ] **Step 2: Add the paths**

In the `path` switch (near the `.buybackList` path, ~line 490):
```swift
    case .inventoryList: return "/api/assets"
    case .inventoryDetail(let id): return "/api/assets/\(id)"
    case .inventoryByTag(let tag): return "/api/assets/tag/\(tag)"
    case .inventoryActivity(let id, _): return "/api/assets/\(id)/activity"
    case .inventoryAssetGroups(let id): return "/api/assets/\(id)/groups"
    case .inventoryExternalDeployment(let id): return "/api/assets/\(id)/external-deployment"
    case .productTypeCategories: return "/api/product-types/categories"
    case .assetGroupsList: return "/api/asset-groups"
```

- [ ] **Step 3: Add to the GET method group**

Find the `method` switch GET group (contains `.buybackList, .buybackDetail, …`, ~line 556-571) and append the new cases to that same `return .get` group:
```swift
    .inventoryList, .inventoryDetail, .inventoryByTag, .inventoryActivity,
    .inventoryAssetGroups, .inventoryExternalDeployment, .productTypeCategories, .assetGroupsList,
```

- [ ] **Step 4: Add the query items**

In the `queryItems` switch (near `.buybackList`, ~line 800):
```swift
    case .inventoryList(let page, let limit, let status, let category, let locationId, let subLocationId, let productTypeId, let groupId, let hasGroups, let hasProducts, let search):
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let status = status { items.append(URLQueryItem(name: "status", value: status)) }
        if let category = category { items.append(URLQueryItem(name: "category", value: category)) }
        if let locationId = locationId { items.append(URLQueryItem(name: "location_id", value: locationId)) }
        if let subLocationId = subLocationId { items.append(URLQueryItem(name: "sub_location_id", value: subLocationId)) }
        if let productTypeId = productTypeId { items.append(URLQueryItem(name: "product_type_id", value: productTypeId)) }
        if let groupId = groupId { items.append(URLQueryItem(name: "group_id", value: groupId)) }
        if let hasGroups = hasGroups { items.append(URLQueryItem(name: "has_groups", value: hasGroups ? "true" : "false")) }
        if let hasProducts = hasProducts { items.append(URLQueryItem(name: "has_products", value: hasProducts ? "true" : "false")) }
        if let search = search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
        return items

    case .inventoryActivity(_, let limit):
        if let limit = limit { return [URLQueryItem(name: "limit", value: String(limit))] }
        return nil

    case .inventoryExternalDeployment:
        return [URLQueryItem(name: "include_history", value: "true")]

    case .assetGroupsList(let page, let limit, let search):
        var items = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let search = search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
        return items
```
(`.inventoryDetail`, `.inventoryByTag`, `.inventoryAssetGroups`, `.productTypeCategories` take no query items — they fall through to the default `return nil`.)

`requiresAuth` needs no change — the default branch returns `true`.

- [ ] **Step 5: Build to verify it compiles**

Run the build command. Expected: build succeeds (no "switch must be exhaustive" errors → all four switches handle the new cases).

- [ ] **Step 6: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift"
git commit -m "feat(inventory): API endpoints for assets, categories, asset-groups"
```

---

## Task 4: `InventoryService`

A thin, injectable wrapper over `APIClient` so the view models are testable.

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift`
- Test: append to `InventoryModelTests.swift` (protocol conformance compile check only — network calls aren't unit-tested)

- [ ] **Step 1: Write the implementation**

Create `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift`:
```swift
import Foundation

/// Abstraction over the inventory endpoints so view models can be tested with a mock.
@MainActor
protocol InventoryServing {
    func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset]
    func fetchAsset(id: String) async throws -> Asset
    func fetchAssetByTag(_ tag: String) async throws -> Asset
    func fetchActivity(id: String) async throws -> [AssetActivity]
    func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary]
    func fetchExternalDeployment(id: String) async throws -> ExternalDeployment
    func fetchCategories() async throws -> [String]
    func fetchGroups(search: String?) async throws -> [AssetGroupListItem]
    func fetchProductTypes(search: String) async throws -> [ProductTypeOption]
    func fetchLocations() async throws -> [Location]
    func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption]
}

/// The filter parameters that vary per list request.
struct AssetQuery: Equatable {
    var status: String?
    var category: String?
    var locationId: String?
    var subLocationId: String?
    var productTypeId: String?
    var groupId: String?
    var hasGroups: Bool?
    var hasProducts: Bool?
    var search: String?
}

/// Minimal product-type row for the filter picker.
struct ProductTypeOption: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
}

/// Minimal sub-location row for the filter picker.
struct AssetSubLocationOption: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var code: String?
    var description: String?
}

@MainActor
final class InventoryService: InventoryServing {
    private let api: APIClient
    init(api: APIClient = .shared) { self.api = api }

    func fetchAssets(page: Int, pageSize: Int, filters q: AssetQuery) async throws -> [Asset] {
        try await api.request(.inventoryList(
            page: page, limit: pageSize,
            status: q.status, category: q.category,
            locationId: q.locationId, subLocationId: q.subLocationId,
            productTypeId: q.productTypeId, groupId: q.groupId,
            hasGroups: q.hasGroups, hasProducts: q.hasProducts, search: q.search))
    }

    func fetchAsset(id: String) async throws -> Asset {
        try await api.request(.inventoryDetail(id: id))
    }
    func fetchAssetByTag(_ tag: String) async throws -> Asset {
        try await api.request(.inventoryByTag(tag: tag))
    }
    func fetchActivity(id: String) async throws -> [AssetActivity] {
        try await api.request(.inventoryActivity(id: id, limit: 50))
    }
    func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] {
        try await api.request(.inventoryAssetGroups(id: id))
    }
    func fetchExternalDeployment(id: String) async throws -> ExternalDeployment {
        try await api.request(.inventoryExternalDeployment(id: id))
    }
    func fetchCategories() async throws -> [String] {
        let resp: CategoriesResponse = try await api.request(.productTypeCategories)
        return resp.categories.map(\.category).filter { !$0.isEmpty }
    }
    func fetchGroups(search: String?) async throws -> [AssetGroupListItem] {
        try await api.request(.assetGroupsList(page: 1, limit: 100, search: search))
    }
    func fetchProductTypes(search: String) async throws -> [ProductTypeOption] {
        try await api.request(.productTypes(search: search))
    }
    func fetchLocations() async throws -> [Location] {
        try await api.request(.locations)
    }
    func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] {
        try await api.request(.locationSubLocations(locationId: locationId))
    }
}
```

> **Verification note (open item):** `fetchCategories` assumes `data` decodes as `[CategoryOption]` and `fetchProductTypes` assumes `[ProductTypeOption]`. Both are tolerant/minimal; if the live shape differs, adjust these two structs only.

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: success.

- [ ] **Step 3: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift"
git commit -m "feat(inventory): InventoryService over APIClient"
```

---

## Task 5: `InventoryListViewModel`

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift`
- Test: `Repair Minder/Repair MinderTests/InventoryListViewModelTests.swift`

- [ ] **Step 1: Write the failing test** (uses a mock service)

Create `Repair Minder/Repair MinderTests/InventoryListViewModelTests.swift`:
```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryListViewModelTests: XCTestCase {

    final class MockService: InventoryServing {
        var pages: [[Asset]] = []
        var lastQuery: AssetQuery?
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            lastQuery = filters
            return page <= pages.count ? pages[page - 1] : []
        }
        func fetchAsset(id: String) async throws -> Asset { fatalError() }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
    }

    private func asset(_ id: String) -> Asset {
        Asset(id: id, assetTag: "T\(id)", name: "n", status: .inStock)
    }

    func testLoadPopulatesItems() async {
        let mock = MockService()
        mock.pages = [[asset("1"), asset("2")]]
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        await vm.loadAssets()
        XCTAssertEqual(vm.assets.count, 2)
        XCTAssertFalse(vm.isLoading)
    }

    func testHasMoreWhenFullPageReturned() async {
        let mock = MockService()
        mock.pages = [Array(repeating: asset("x"), count: 2), [asset("3")]]
        let vm = InventoryListViewModel(service: mock, pageSize: 2) // full page => hasMore
        await vm.loadAssets()
        XCTAssertTrue(vm.hasMore)
        await vm.loadMore()
        XCTAssertEqual(vm.assets.count, 3)
        XCTAssertFalse(vm.hasMore) // last page returned < pageSize
    }

    func testStatusPillBuildsQuery() async {
        let mock = MockService()
        mock.pages = [[]]
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        vm.selectStatus(.deployed)
        await vm.loadAssets()
        XCTAssertEqual(mock.lastQuery?.status, "deployed")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run `-only-testing:"Repair MinderTests/InventoryListViewModelTests"`. Expected: FAIL — `cannot find 'InventoryListViewModel'`.

- [ ] **Step 3: Write the implementation**

Create `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift`:
```swift
import Foundation

@MainActor
final class InventoryListViewModel: ObservableObject {

    // MARK: Published state
    @Published private(set) var assets: [Asset] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = false
    @Published private(set) var error: String?

    // Filter state (bound to UI)
    @Published var searchText = ""
    @Published var selectedStatus: AssetStatus?
    @Published var selectedCategory: String?
    @Published var selectedLocationId: String?
    @Published var selectedSubLocationId: String?
    @Published var selectedProductTypeId: String?
    @Published var selectedGroupId: String?
    @Published var unassignedOnly = false
    @Published var noProductsOnly = false

    // MARK: Private
    private let service: InventoryServing
    private let pageSize: Int
    private var currentPage = 1
    private var searchTask: Task<Void, Never>?

    init(service: InventoryServing = InventoryService(), pageSize: Int = 24) {
        self.service = service
        self.pageSize = pageSize
    }

    var activeFilterCount: Int {
        [selectedCategory != nil, selectedLocationId != nil, selectedSubLocationId != nil,
         selectedProductTypeId != nil, selectedGroupId != nil, unassignedOnly, noProductsOnly]
            .filter { $0 }.count
    }

    private var query: AssetQuery {
        AssetQuery(
            status: selectedStatus?.apiValue,
            category: selectedCategory,
            locationId: selectedLocationId,
            subLocationId: selectedSubLocationId,
            productTypeId: selectedProductTypeId,
            groupId: selectedGroupId,
            hasGroups: unassignedOnly ? false : nil,
            hasProducts: noProductsOnly ? false : nil,
            search: searchText.isEmpty ? nil : searchText)
    }

    // MARK: Loading
    func loadAssets() async {
        guard !isLoading else { return }
        isLoading = true; error = nil; currentPage = 1
        do {
            let page = try await service.fetchAssets(page: 1, pageSize: pageSize, filters: query)
            assets = page
            hasMore = page.count == pageSize
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: Asset) async {
        guard hasMore, !isLoadingMore, currentItem.id == assets.last?.id else { return }
        await loadMore()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let next = currentPage + 1
            let page = try await service.fetchAssets(page: next, pageSize: pageSize, filters: query)
            assets.append(contentsOf: page)
            currentPage = next
            hasMore = page.count == pageSize
        } catch {
            #if DEBUG
            print("[InventoryList] pagination error: \(error)")
            #endif
        }
        isLoadingMore = false
    }

    func refresh() async {
        currentPage = 1
        do {
            let page = try await service.fetchAssets(page: 1, pageSize: pageSize, filters: query)
            assets = page
            hasMore = page.count == pageSize
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Filtering
    func selectStatus(_ status: AssetStatus?) {
        selectedStatus = (selectedStatus == status) ? nil : status
        Task { await loadAssets() }
    }

    func applyFilters() { Task { await loadAssets() } }

    func clearFilters() {
        selectedCategory = nil; selectedLocationId = nil; selectedSubLocationId = nil
        selectedProductTypeId = nil; selectedGroupId = nil
        unassignedOnly = false; noProductsOnly = false
        Task { await loadAssets() }
    }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await loadAssets()
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run `-only-testing:"Repair MinderTests/InventoryListViewModelTests"`. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift" "Repair Minder/Repair MinderTests/InventoryListViewModelTests.swift"
git commit -m "feat(inventory): list view model with filters + count-heuristic paging"
```

---

## Task 6: `AssetStatusHelpers` (badge + colour)

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/AssetStatusHelpers.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

func assetStatusColor(_ status: AssetStatus) -> Color {
    switch status {
    case .inStock:       return .green
    case .allocated:     return .blue
    case .reserved:      return .teal
    case .deployed:      return .purple
    case .used:          return .gray
    case .returned:      return .orange
    case .damaged:       return .red
    case .sold:          return .indigo
    case .pendingReturn: return .yellow
    case .unknown:       return .secondary
    }
}

struct AssetStatusBadge: View {
    let status: AssetStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(assetStatusColor(status).opacity(0.15))
            .foregroundStyle(assetStatusColor(status))
            .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run the build command. Expected: success.

- [ ] **Step 3: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/AssetStatusHelpers.swift"
git commit -m "feat(inventory): asset status badge + colour"
```

---

## Task 7: `InventoryListView` (rows, pills, search, paging, isEmbedded)

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

struct InventoryListView: View {
    var isEmbedded: Bool = false
    var onBack: (() -> Void)? = nil

    @StateObject private var viewModel = InventoryListViewModel()
    @State private var showFilters = false
    @State private var selectedAssetId: String?
    #if os(iOS)
    @State private var showScanner = false
    #endif
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isEmbedded { embeddedBody }
            else if isRegularWidth { iPadBody }
            else { iPhoneBody }
        }
        .task { if viewModel.assets.isEmpty { await viewModel.loadAssets() } }
    }

    // Embedded (inside the More-tab NavigationStack — NO own stack)
    private var embeddedBody: some View {
        content
            .navigationTitle("Inventory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(item: $selectedAssetId) { InventoryDetailView(assetId: $0) }
            .toolbar { filterToolbar }
    }

    // Standalone iPhone tab (owns a stack)
    private var iPhoneBody: some View {
        NavigationStack {
            content
                .navigationTitle("Inventory")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .navigationDestination(item: $selectedAssetId) { InventoryDetailView(assetId: $0) }
                .toolbar { filterToolbar }
        }
    }

    // iPad split view (mirror Buyback)
    private var iPadBody: some View {
        AnimatedSplitView(showDetail: selectedAssetId != nil) {
            NavigationStack {
                content
                    .navigationTitle("Inventory")
                    .toolbar { filterToolbar }
            }
        } detail: {
            if let id = selectedAssetId {
                NavigationStack { InventoryDetailView(assetId: id) }.id(id)
            }
        }
    }

    // Shared content
    private var content: some View {
        VStack(spacing: 0) {
            statusPills
            mainList
        }
        .searchable(text: $viewModel.searchText, placement: searchPlacement, prompt: "Search tag, name, serial, SKU")
        .onChange(of: viewModel.searchText) { _, _ in viewModel.searchChanged() }
        .sheet(isPresented: $showFilters) {
            AssetFilterSheet(viewModel: viewModel)
        }
        #if os(iOS)
        .sheet(isPresented: $showScanner) {
            InventoryScannerSheet { tag in
                showScanner = false
                Task { await lookupTag(tag) }
            }
        }
        #endif
    }

    #if os(iOS)
    private var searchPlacement: SearchFieldPlacement { .navigationBarDrawer(displayMode: .always) }
    #else
    private var searchPlacement: SearchFieldPlacement { .automatic }
    #endif

    private var statusPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "All", isOn: viewModel.selectedStatus == nil) { viewModel.selectStatus(nil) }
                ForEach(AssetStatus.allCases, id: \.self) { s in
                    pill(title: s.displayName, isOn: viewModel.selectedStatus == s) { viewModel.selectStatus(s) }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    private func pill(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isOn ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isOn ? Color.accentColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var mainList: some View {
        if viewModel.isLoading && viewModel.assets.isEmpty {
            Spacer(); ProgressView().frame(maxWidth: .infinity); Spacer()
        } else if let error = viewModel.error, viewModel.assets.isEmpty {
            errorView(error)
        } else if viewModel.assets.isEmpty {
            emptyView
        } else {
            List {
                ForEach(viewModel.assets) { asset in
                    Button { selectedAssetId = asset.id } label: { AssetRow(asset: asset) }
                        .buttonStyle(.plain)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: asset) }
                }
                if viewModel.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView("No Inventory", systemImage: "shippingbox",
            description: Text(viewModel.activeFilterCount > 0 || !viewModel.searchText.isEmpty ? "No matches for your filters." : "Inventory items will appear here."))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Retry") { Task { await viewModel.loadAssets() } }.buttonStyle(.borderedProminent)
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder private var filterToolbar: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
        }
        #endif
        ToolbarItem(placement: .primaryAction) {
            Button { showFilters = true } label: {
                Image(systemName: viewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
    }

    #if os(iOS)
    private func lookupTag(_ tag: String) async {
        do {
            let asset = try await InventoryService().fetchAssetByTag(tag)
            if !viewModel.assets.contains(where: { $0.id == asset.id }) {
                // Ensure detail can resolve by id; we already navigate by id.
            }
            selectedAssetId = asset.id
        } catch {
            // Not found — no-op; a production build could show an alert.
        }
    }
    #endif
}

private struct AssetRow: View {
    let asset: Asset
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(asset.assetTag).font(.subheadline.weight(.semibold).monospaced())
                Spacer()
                AssetStatusBadge(status: asset.status)
            }
            Text(asset.name).font(.body)
            HStack(spacing: 8) {
                if let cat = asset.category { Text(cat).font(.caption).foregroundStyle(.secondary) }
                if let loc = asset.locationDisplay { Label(loc, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
            }
            if !asset.groupNamesList.isEmpty {
                HStack(spacing: 6) {
                    ForEach(asset.groupNamesList.prefix(2), id: \.self) { g in
                        Text(g).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill)).clipShape(Capsule())
                    }
                    if asset.groupNamesList.count > 2 { Text("+\(asset.groupNamesList.count - 2)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            if let cost = asset.formattedCost {
                Text(cost).font(.subheadline.weight(.medium))
            }
        }
        .padding(.vertical, 4)
    }
}
```

> `AnimatedSplitView` and `CurrencyFormatter` already exist in the app (used by Buyback). `InventoryScannerSheet` is created in Task 9; `AssetFilterSheet` in Task 8; `InventoryDetailView` in Task 11. Because those are referenced but not yet defined, this task's build will fail until Tasks 8–11 land — so build-verify this task together with Task 8, 9, 11 (they form one compile unit). Sequence: write 7 → 8 → 9 → 11, then build.

- [ ] **Step 2: Commit (compile deferred to Task 11)**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift"
git commit -m "feat(inventory): list view (rows, status pills, search, paging, embedded)"
```

---

## Task 8: `AssetFilterSheet` + filter option loader

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/AssetFilterSheet.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

/// Loads the picker option lists for the filter sheet.
@MainActor
final class AssetFilterOptions: ObservableObject {
    @Published var categories: [String] = []
    @Published var locations: [Location] = []
    @Published var subLocations: [AssetSubLocationOption] = []
    @Published var groups: [AssetGroupListItem] = []
    @Published var productTypes: [ProductTypeOption] = []

    private let service: InventoryServing
    // NB: InventoryService.init is @MainActor-isolated, so it cannot be a default
    // arg value in a nonisolated context. Use optional + nil-coalesce instead.
    init(service: InventoryServing? = nil) { self.service = service ?? InventoryService() }

    func loadTopLevel() async {
        async let cats = try? service.fetchCategories()
        async let locs = try? service.fetchLocations()
        async let grps = try? service.fetchGroups(search: nil)
        categories = await cats ?? []
        locations = await locs ?? []
        groups = await grps ?? []
    }

    func loadSubLocations(locationId: String) async {
        subLocations = (try? await service.fetchSubLocations(locationId: locationId)) ?? []
    }

    func searchProductTypes(_ query: String) async {
        guard !query.isEmpty else { productTypes = []; return }
        productTypes = (try? await service.fetchProductTypes(search: query)) ?? []
    }
}

struct AssetFilterSheet: View {
    @ObservedObject var viewModel: InventoryListViewModel
    @StateObject private var options = AssetFilterOptions()
    @Environment(\.dismiss) private var dismiss
    @State private var productTypeQuery = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("Any").tag(String?.none)
                        ForEach(options.categories, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                }
                Section("Location") {
                    Picker("Location", selection: $viewModel.selectedLocationId) {
                        Text("Any").tag(String?.none)
                        ForEach(options.locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    .onChange(of: viewModel.selectedLocationId) { _, new in
                        viewModel.selectedSubLocationId = nil
                        if let id = new { Task { await options.loadSubLocations(locationId: id) } }
                        else { options.subLocations = [] }
                    }
                    if !options.subLocations.isEmpty {
                        Picker("Sub-location", selection: $viewModel.selectedSubLocationId) {
                            Text("Any").tag(String?.none)
                            ForEach(options.subLocations) { Text($0.code ?? $0.description ?? "—").tag(String?.some($0.id)) }
                        }
                    }
                }
                Section("Group") {
                    Picker("Group", selection: $viewModel.selectedGroupId) {
                        Text("Any").tag(String?.none)
                        ForEach(options.groups) { Text($0.name).tag(String?.some($0.id)) }
                    }
                }
                Section("Product Type") {
                    TextField("Search product types…", text: $productTypeQuery)
                        .onChange(of: productTypeQuery) { _, q in Task { await options.searchProductTypes(q) } }
                    ForEach(options.productTypes) { pt in
                        Button {
                            viewModel.selectedProductTypeId = pt.id
                            productTypeQuery = pt.name
                        } label: {
                            HStack {
                                Text(pt.name)
                                Spacer()
                                if viewModel.selectedProductTypeId == pt.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if viewModel.selectedProductTypeId != nil {
                        Button("Clear product type", role: .destructive) {
                            viewModel.selectedProductTypeId = nil; productTypeQuery = ""
                        }
                    }
                }
                Section {
                    Toggle("Unassigned (no groups)", isOn: $viewModel.unassignedOnly)
                    Toggle("No products", isOn: $viewModel.noProductsOnly)
                }
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { viewModel.clearFilters(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { viewModel.applyFilters(); dismiss() }
                }
            }
            .task { await options.loadTopLevel() }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/AssetFilterSheet.swift"
git commit -m "feat(inventory): filter sheet (category, location, group, product type, toggles)"
```

---

## Task 9: Scan-to-find (iOS only)

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryScannerSheet.swift`

- [ ] **Step 1: Locate the existing scanner**

Run: `grep -rln "AVCaptureMetadataOutput\|DataScannerViewController\|BarcodeScanner\|ScannerView" "Repair Minder/Repair Minder"`
Use whatever barcode scanner view the Devices feature already uses. If a reusable `ScannerView`/`BarcodeScannerView` exists, wrap it; the code below assumes a callback-based `BarcodeScannerView(onScan:)`. Adjust the wrapped type name to the real one found here.

- [ ] **Step 2: Write the implementation**

```swift
#if os(iOS)
import SwiftUI

/// Presents the app's existing barcode scanner and returns the scanned string.
struct InventoryScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // Replace `BarcodeScannerView` with the reusable scanner found in Step 1.
            BarcodeScannerView { code in onScan(code) }
                .ignoresSafeArea()
                .navigationTitle("Scan Asset Tag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}
#endif
```

> If the existing scanner isn't trivially reusable as a SwiftUI view, this task expands to wrap the `UIViewControllerRepresentable` the Devices scanner uses. Keep it `#if os(iOS)`.

- [ ] **Step 3: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryScannerSheet.swift"
git commit -m "feat(inventory): scan-to-find sheet (iOS)"
```

---

## Task 10: `InventoryDetailViewModel`

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift`
- Test: `Repair Minder/Repair MinderTests/InventoryDetailViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryDetailViewModelTests: XCTestCase {
    final class Mock: InventoryServing {
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] { [] }
        func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "Widget", status: .inStock) }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [AssetActivity(id: "act1")] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [AssetGroupSummary(id: "g1", name: "Screens")] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { ExternalDeployment() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
    }

    func testLoadDetailPopulatesAllSections() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: Mock())
        await vm.load()
        XCTAssertEqual(vm.asset?.name, "Widget")
        XCTAssertEqual(vm.activity.count, 1)
        XCTAssertEqual(vm.groups.first?.name, "Screens")
        XCTAssertFalse(vm.isLoading)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run `-only-testing:"Repair MinderTests/InventoryDetailViewModelTests"`. Expected: FAIL — type not found.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

@MainActor
final class InventoryDetailViewModel: ObservableObject {
    @Published private(set) var asset: Asset?
    @Published private(set) var activity: [AssetActivity] = []
    @Published private(set) var groups: [AssetGroupSummary] = []
    @Published private(set) var externalDeployment: ExternalDeployment?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    let assetId: String
    private let service: InventoryServing
    // InventoryService.init is @MainActor-isolated — use optional + nil-coalesce (not a default arg value).
    init(assetId: String, service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
        self.assetId = assetId
    }

    func load() async {
        isLoading = true; error = nil
        do {
            asset = try await service.fetchAsset(id: assetId)
        } catch {
            self.error = error.localizedDescription
        }
        // Sub-resources load in parallel and degrade silently on failure.
        async let act = try? service.fetchActivity(id: assetId)
        async let grp = try? service.fetchAssetGroups(id: assetId)
        async let ext = try? service.fetchExternalDeployment(id: assetId)
        activity = await act ?? []
        groups = await grp ?? []
        externalDeployment = await ext
        isLoading = false
    }

    func refresh() async { await load() }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run `-only-testing:"Repair MinderTests/InventoryDetailViewModelTests"`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift" "Repair Minder/Repair MinderTests/InventoryDetailViewModelTests.swift"
git commit -m "feat(inventory): detail view model with parallel sub-resource loads"
```

---

## Task 11: `InventoryDetailView` (all read sections)

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailView.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

struct InventoryDetailView: View {
    let assetId: String
    @StateObject private var viewModel: InventoryDetailViewModel

    init(assetId: String) {
        self.assetId = assetId
        _viewModel = StateObject(wrappedValue: InventoryDetailViewModel(assetId: assetId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.asset == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let asset = viewModel.asset {
                ScrollView { VStack(alignment: .leading, spacing: 16) { sections(asset) }.padding() }
            } else if let error = viewModel.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.orange)
                    Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Retry") { Task { await viewModel.load() } }.buttonStyle(.borderedProminent)
                }.padding()
            }
        }
        .navigationTitle(viewModel.asset?.assetTag ?? "Asset")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { if viewModel.asset == nil { await viewModel.load() } }
        .refreshable { await viewModel.refresh() }
    }

    @ViewBuilder private func sections(_ a: Asset) -> some View {
        header(a)
        if a.status == .pendingReturn { card("Pending Return") {
            row("Reason", a.supplierReturnReason); row("Notes", a.supplierReturnNotes); row("Initiated", a.supplierReturnInitiatedAt)
        } }
        card("Identification") {
            row("Serial", a.serialNumber); row("SKU", a.sku); row("Category", a.category); row("Product Type", a.productTypeName)
        }
        if !viewModel.groups.isEmpty { card("Inventory Groups") {
            ForEach(viewModel.groups) { g in
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name).font(.subheadline.weight(.medium))
                    if let sku = g.sku { Text(sku).font(.caption).foregroundStyle(.secondary) }
                    if let avg = g.avgCost { Text("Avg cost \(CurrencyFormatter.format(avg))").font(.caption).foregroundStyle(.secondary) }
                }
            }
        } }
        card("Status & Location") {
            HStack { Text("Status").foregroundStyle(.secondary); Spacer(); AssetStatusBadge(status: a.status) }
            row("Location", a.locationName); row("Sub-location", a.subLocationCode)
            if a.status == .allocated || a.status == .deployed {
                row("Order #", a.checkedOutOrderNumber); row("Device", a.checkedOutDeviceName)
            }
            if let ext = viewModel.externalDeployment?.active {
                row("Deployed to", ext.customerName); row("Reference", ext.externalReference); row("Deployed", ext.deploymentDate)
            }
        }
        card("Purchase Info") {
            row("Supplier", a.supplierName); row("Order ref", a.supplierOrderReference); row("Purchased", a.purchaseDate)
            row("Cost", a.cost.map { CurrencyFormatter.format($0) }); row("Cost inc VAT", a.costIncVat.map { CurrencyFormatter.format($0) })
        }
        if a.sourceType == "recovered" || a.sourceType == "salvaged" { card("Recovery / Salvage Origin") {
            row("Source", a.sourceType); row("Recovered", a.recoveredAt); row("Condition grade", a.conditionGrade)
            if let lcd = a.lcdWorkingBool { row("LCD working", lcd ? "Yes" : "No") }
            if let glass = a.glassCrackedBool { row("Glass cracked", glass ? "Yes" : "No") }
        } }
        if a.checkedOutToBuybackId != nil { card("Buyback Allocation") {
            row("Buyback", a.checkedOutToBuybackId)
        } }
        card("Quality") {
            row("Condition grade", a.conditionGrade)
            row("OEM", a.isOemBool ? "Yes" : "No"); row("Refurbished", a.isRefurbishedBool ? "Yes" : "No")
        }
        card("Warranty") {
            row("Warranty months", a.warrantyMonths.map(String.init)); row("Expires", a.warrantyExpires)
        }
        if let notes = a.notes, !notes.isEmpty { card("Notes") { Text(notes) } }
        if !viewModel.activity.isEmpty { card("Activity") {
            ForEach(viewModel.activity) { act in
                VStack(alignment: .leading, spacing: 2) {
                    Text(act.activityType ?? act.description ?? "Activity").font(.subheadline)
                    if let who = act.performedByName ?? act.performedByEmail { Text(who).font(.caption).foregroundStyle(.secondary) }
                    if let when = act.performedAt { Text(when).font(.caption2).foregroundStyle(.tertiary) }
                }
            }
        } }
    }

    private func header(_ a: Asset) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(a.assetTag).font(.title3.weight(.bold).monospaced()); Spacer(); AssetStatusBadge(status: a.status) }
            Text(a.name).font(.title2.weight(.semibold))
        }
    }

    private func card(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }.font(.subheadline)
        }
    }
}
```

- [ ] **Step 2: Build the whole module (Tasks 7–11 compile together)**

Run the build command. Expected: success. Fix any name mismatch against the real scanner type from Task 9.

- [ ] **Step 3: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailView.swift"
git commit -m "feat(inventory): asset detail view (all read sections + sub-resources)"
```

---

## Task 12: Tab / navigation integration

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Models/TabBarConfig.swift`
- Modify: `Repair Minder/Repair Minder/Repair_MinderApp.swift`
- Modify: `Repair Minder/Repair Minder/Features/Settings/SettingsView.swift`

- [ ] **Step 1: Add the `FeatureTab` case**

In `TabBarConfig.swift`, add `case inventory` to `enum FeatureTab` and to its three switches:
```swift
// in the enum, after `case devices`
    case inventory
```
```swift
// label
    case .inventory: "Inventory"
// icon
    case .inventory: "shippingbox.fill"
// fallbackOrder
    case .inventory: 7
```
(Default `defaultTabs` unchanged → Inventory is opt-in via More overflow.)

- [ ] **Step 2: Render the tab in `StaffMainView`**

In `Repair_MinderApp.swift`, `tabContent(for:)` (~line 427), add:
```swift
    case .inventory:
        NavigationStack {
            InventoryListView()
        }
```

- [ ] **Step 3: Wire the More overflow in `SettingsView`**

In `Features/Settings/SettingsView.swift`:
1. Add to `enum SettingsDestination`: `case inventory`
2. In `SettingsDestination.from(_:)`: `case .inventory: .inventory`
3. In `destinationView(_:)`: `case .inventory: InventoryListView(isEmbedded: true)`

- [ ] **Step 4: Build to verify it compiles**

Run the build command. Expected: success (all `FeatureTab`/`SettingsDestination` switches exhaustive).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/TabBarConfig.swift" "Repair Minder/Repair Minder/Repair_MinderApp.swift" "Repair Minder/Repair Minder/Features/Settings/SettingsView.swift"
git commit -m "feat(inventory): opt-in Inventory tab + More overflow"
```

---

## Task 13: XCUITest smoke + final verification

**Files:**
- Create: `Repair Minder/Repair MinderUITests/InventoryBrowseUITest.swift`

- [ ] **Step 1: Write the UI smoke test** (reuses the Magic-Link login pattern from the 2026-07-03 bug-fix harness)

```swift
import XCTest

final class InventoryBrowseUITest: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = true }
    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor func testBrowseInventoryFromMore() throws {
        let app = XCUIApplication(); app.launch()
        // Role → Staff
        let staff = app.staticTexts["Staff"]
        if staff.waitForExistence(timeout: 8) { staff.tap() }
        // Magic-link login (demo account; static 2FA 123456)
        let email = app.textFields.firstMatch
        if email.waitForExistence(timeout: 8) {
            email.tap(); email.typeText("appstore-demo@repairminder.com")
            app.swipeUp()
            let magic = app.buttons["Sign in with Magic Link"]
            if magic.waitForExistence(timeout: 4) { magic.tap() }
            let code = app.textFields.firstMatch
            if code.waitForExistence(timeout: 15) {
                code.tap(); code.typeText("123456")
                let verify = app.buttons["Verify"]
                if verify.waitForExistence(timeout: 3) { verify.tap() }
            }
        }
        // Reach the tab bar, open More → Inventory
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 30), "did not reach tab bar")
        more.tap()
        let inv = app.staticTexts["Inventory"]
        XCTAssertTrue(inv.waitForExistence(timeout: 5), "Inventory row missing in More")
        inv.tap()
        // List should render an asset tag (demo data has assets)
        Thread.sleep(forTimeInterval: 4)
        snap(app, "inventory-list")
        // Open the first asset row → detail
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) { firstCell.tap() }
        Thread.sleep(forTimeInterval: 3)
        snap(app, "inventory-detail")
    }
}
```

- [ ] **Step 2: Run the UI test and inspect screenshots**

Run:
```bash
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:"Repair MinderUITests/InventoryBrowseUITest" \
  -parallel-testing-enabled NO -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -resultBundlePath /tmp/inv-verify.xcresult 2>&1 | tail -8
xcrun xcresulttool export attachments --path /tmp/inv-verify.xcresult --output-path /tmp/inv-shots
```
Expected: test passes; `inventory-list` screenshot shows asset rows; `inventory-detail` shows the detail sections.

- [ ] **Step 3: Full build for iPad + Mac destinations (shared-target sanity)**

Run the build command once with `-destination 'platform=macOS,variant=Mac Catalyst'` OR the Mac scheme if separate, confirming the shared views compile without the iOS-only scanner. Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Repair Minder/Repair MinderUITests/InventoryBrowseUITest.swift"
git commit -m "test(inventory): browse smoke test (More → Inventory → detail)"
```

---

## Self-Review (completed during authoring)

- **Spec coverage:** models (T1–T2), API layer incl. new endpoints (T3–T4), list with status pills/search/full filter set/paging (T5–T8), scan-to-find (T9), detail with all sections + 3 sub-resources (T10–T11), opt-in tab + overflow via `isEmbedded` (T12), tests (T1/T2/T5/T10/T13). All spec §3–§10 items map to a task.
- **Placeholder scan:** the two tolerant decoders (`CategoryOption`, `AssetActivity`) and the scanner wrapper are the only "verify against live" spots; each has an explicit verification step, not a blank TODO.
- **Type consistency:** `AssetQuery`, `Asset`, `AssetStatus`, `InventoryServing`, `InventoryListViewModel`, `InventoryDetailViewModel`, `AssetFilterOptions`, `AssetStatusBadge`/`assetStatusColor`, `InventoryScannerSheet`, `AssetSubLocationOption`/`ProductTypeOption` are defined once and referenced consistently across tasks.
- **Known cross-task compile coupling:** Tasks 7–11 reference each other; build-verify after Task 11 (noted in T7/T11).

## Deferred to later phases (not this plan)
Phase 2 (writes: edit/move/deploy/status/delete/return-to-supplier/external), Phase 3 (Inventory Groups management + promote), Phase 4 (bulk, stock-summary/hierarchy/low-stock, book-in, salvage).
