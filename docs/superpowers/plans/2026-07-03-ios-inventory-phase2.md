# iOS Inventory Phase 2 (Per-Asset Write Actions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add every single-asset write action from the web `AssetDetailPage` (edit, move, deploy/allocate incl. the full To-Order wizard, external deploy/return, return-to-supplier + resolve, delete) to the iOS Inventory detail screen, plus one guarded list-row swipe, extending the Phase-1 module with zero backend changes.

**Architecture:** Extend the existing `Features/Staff/Inventory/` module. Networking via the shared `APIClient` (`request<T>` / `requestVoid`, plus one additive `requestFull<R>` for envelope-sidecar flags). Small `Encodable` request structs + a few custom response structs in `Core/Models/InventoryWriteModels.swift`, decoded with the global `.convertToSnakeCase` / `.convertFromSnakeCase`. Actions surface as a toolbar `Menu` + contextual controls on `InventoryDetailView`; mutations run through `InventoryDetailViewModel` and broadcast `Notification.Name.inventoryAssetDidChange` so the list reloads.

**Tech Stack:** Swift 5 / SwiftUI, `@MainActor` ObservableObject view models, `XCTest` encode/decode + view-model tests, `xcodebuild` against the iOS 26 simulator (iPhone 17 Pro).

---

## Conventions used throughout

- **Source root:** `Repair Minder/Repair Minder/` (paths below are relative to the iOS repo root `repairminder-iOS/repairminder-iOS/`).
- **Test target:** `Repair MinderTests`. New files land in synchronized groups — no `.xcodeproj` edits.
- **No explicit snake_case `CodingKeys`** — global `.convertFromSnakeCase` (decode) / `.convertToSnakeCase` (encode).
- **SQLite booleans** are `Int` 0/1 → model as `Int?`; send as Int 0/1 in request structs.
- **@MainActor init trap:** never use a `@MainActor` singleton (`APIClient.shared`, `InventoryService()`) as a default-arg value; use `init(x: T? = nil) { self.x = x ?? T.shared }`.
- **Build/test command** (fresh SPM dir; booted iPhone 17 Pro):
  ```bash
  cd "repairminder-iOS/repairminder-iOS"
  xcodebuild build \
    -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
    ENABLE_PREVIEWS=NO ENABLE_DEBUG_DYLIB=NO 2>&1 | tail -20
  ```
  For unit tests: swap `build` → `test -only-testing:"Repair MinderTests/<Class>"` and add `-parallel-testing-enabled NO`.
- **Branch:** all Phase 2 code lands on `feat/ios-inventory-phase2` (created off `main` by the subagent-driven-development step before Task 1).

---

## File structure

**Create:**
- `Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift` — request structs + custom response structs.
- `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetEditSheet.swift`
- `.../Actions/AssetMoveSheet.swift`
- `.../Actions/ReturnToSupplierSheet.swift`
- `.../Actions/DeployChooserSheet.swift`
- `.../Actions/DeployExternalSheet.swift`
- `.../Actions/DeployToOrderWizard.swift`
- `.../Actions/PartRecoveryForm.swift`
- `.../Actions/DeployViewModel.swift`
- Tests: `Repair MinderTests/InventoryWriteModelTests.swift`, `InventoryWriteViewModelTests.swift`

**Modify:**
- `Core/Networking/APIEndpoints.swift` — +8 cases (paths, methods).
- `Core/Networking/APIClient.swift` — +`requestFull<R>`.
- `Features/Staff/Inventory/InventoryService.swift` — +8 write methods on `InventoryServing`/`InventoryService`.
- `Features/Staff/Inventory/InventoryDetailViewModel.swift` — mutation methods + notification.
- `Features/Staff/Inventory/InventoryDetailView.swift` — toolbar menu, banner actions, sheets, return-to-stock button.
- `Features/Staff/Inventory/InventoryListViewModel.swift` — coalescing fix + change observer.
- `Features/Staff/Inventory/InventoryListView.swift` — guarded swipe-delete.

---

## Task 1: Request structs + encoding tests

**Files:**
- Create: `Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift`
- Create test: `Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift`:
```swift
import XCTest
@testable import Repair_Minder

final class InventoryWriteModelTests: XCTestCase {
    private func encodeToObject(_ value: Encodable) throws -> [String: Any] {
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        let data = try enc.encode(AnyEncodable(value))
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func testUpdateAssetRequestEncodesSnakeCaseAndIntBools() throws {
        let req = UpdateAssetRequest(serialNumber: "SN1", sku: "SKU9", category: "Screens",
                                     conditionGrade: "A", isOem: 1, isRefurbished: 0,
                                     warrantyMonths: 12, notes: "hi")
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["serial_number"] as? String, "SN1")
        XCTAssertEqual(obj["condition_grade"] as? String, "A")
        XCTAssertEqual(obj["is_oem"] as? Int, 1)
        XCTAssertEqual(obj["is_refurbished"] as? Int, 0)
        XCTAssertEqual(obj["warranty_months"] as? Int, 12)
        // Omitted optionals must be absent, not null:
        XCTAssertNil(obj["manufacturer"])
    }

    func testAllocateRequestEncodesRecovery() throws {
        let req = AllocateRequest(orderId: "o1", deviceId: nil, orderItemId: "li1", deploy: false,
                                  recovery: RecoveryInput(conditionGrade: "B", locationId: "loc1",
                                                          subLocationId: nil, notes: "pulled",
                                                          lcdWorking: 1, glassCracked: 0))
        let obj = try encodeToObject(req)
        XCTAssertEqual(obj["order_id"] as? String, "o1")
        XCTAssertEqual(obj["order_item_id"] as? String, "li1")
        XCTAssertEqual(obj["deploy"] as? Bool, false)
        let rec = obj["recovery"] as? [String: Any]
        XCTAssertEqual(rec?["condition_grade"] as? String, "B")
        XCTAssertEqual(rec?["location_id"] as? String, "loc1")
        XCTAssertEqual(rec?["lcd_working"] as? Int, 1)
    }

    func testReturnToSupplierAndResolveEncode() throws {
        let r1 = ReturnToSupplierRequest(supplierReturnReason: "defective", supplierReturnNotes: nil)
        XCTAssertEqual(try encodeToObject(r1)["supplier_return_reason"] as? String, "defective")
        let r2 = ResolveReturnRequest(resolution: "credit_received", replacementAssetId: nil, notes: nil)
        XCTAssertEqual(try encodeToObject(r2)["resolution"] as? String, "credit_received")
        let r3 = MoveAssetRequest(locationId: "loc2", subLocationId: "sub2")
        XCTAssertEqual(try encodeToObject(r3)["sub_location_id"] as? String, "sub2")
    }
}

/// Type-erasing wrapper so we can encode an `Encodable` existential in tests.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
```

- [ ] **Step 2: Run to verify it fails**

Run `-only-testing:"Repair MinderTests/InventoryWriteModelTests"`. Expected: FAIL — `cannot find type 'UpdateAssetRequest'`.

- [ ] **Step 3: Write the request structs**

Create `Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift`:
```swift
import Foundation

// MARK: - Request bodies (encoded with .convertToSnakeCase)

/// PUT /api/assets/:id — send only the fields being edited (all optional).
struct UpdateAssetRequest: Encodable {
    var serialNumber: String?
    var name: String?
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
    var notes: String?
}

/// POST /api/assets/:id/move
struct MoveAssetRequest: Encodable {
    var locationId: String
    var subLocationId: String?
}

/// POST /api/assets/:id/allocate
struct AllocateRequest: Encodable {
    var orderId: String?
    var deviceId: String?
    var orderItemId: String?
    var deploy: Bool
    var recovery: RecoveryInput?
}

struct RecoveryInput: Encodable {
    var conditionGrade: String
    var locationId: String
    var subLocationId: String?
    var notes: String?
    var lcdWorking: Int?
    var glassCracked: Int?
}

/// POST /api/assets/:id/deploy-external
struct DeployExternalRequest: Encodable {
    var customerName: String?
    var externalReference: String?
    var notes: String?
    var deploymentDate: String?
}

/// POST /api/assets/:id/return-external
struct ReturnExternalRequest: Encodable {
    var deploymentId: String
    var returnToStock: Bool?
    var notes: String?
}

/// POST /api/assets/:id/return-to-supplier
struct ReturnToSupplierRequest: Encodable {
    var supplierReturnReason: String
    var supplierReturnNotes: String?
}

/// POST /api/assets/:id/resolve-supplier-return
struct ResolveReturnRequest: Encodable {
    var resolution: String   // "credit_received" | "replacement_received"
    var replacementAssetId: String?
    var notes: String?
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run `-only-testing:"Repair MinderTests/InventoryWriteModelTests"`. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift" "Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift"
git commit -m "feat(inventory): Phase 2 write-action request structs + encoding tests"
```

---

## Task 2: Custom response structs + decode tests

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift` (append)
- Modify: `Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift` (append)

> The JSON below matches the verified `worker/asset_handlers.js` shapes. Task 15 re-captures REAL responses with an admin token and, if any field differs, these structs are the only thing to adjust.

- [ ] **Step 1: Write the failing tests** (append to `InventoryWriteModelTests`)

```swift
extension InventoryWriteModelTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    func testEditAssetResponseDecodesSkuCount() throws {
        let json = #"""
        { "success": true,
          "data": { "id":"a1","asset_tag":"AST1","name":"Screen","status":"in_stock","sku":"SKU9","category":"Screens" },
          "sku_updated_count": 3 }
        """#
        let r = try decode(EditAssetResponse.self, json)
        XCTAssertEqual(r.data.assetTag, "AST1")
        XCTAssertEqual(r.skuUpdatedCount, 3)
    }

    func testAllocateResponseDecodes() throws {
        let json = #"""
        { "success": true,
          "data": { "id":"a1","asset_tag":"AST1","name":"Part","status":"allocated" },
          "prompt_ready_to_repair": true,
          "allocated_parts": [ {"id":"p1","asset_name":"LCD","asset_tag":"AST2","source_status":"allocated"} ],
          "device": { "id":"d1","status":"authorised_awaiting_parts","display_name":"iPhone 13" },
          "recovered_asset": { "id":"r1","asset_tag":"AST3","name":"Recovered","status":"in_stock","location_name":"Main" } }
        """#
        let r = try decode(AllocateResponse.self, json)
        XCTAssertEqual(r.data.status, .allocated)
        XCTAssertEqual(r.promptReadyToRepair, true)
        XCTAssertEqual(r.allocatedParts?.first?.assetTag, "AST2")
        XCTAssertEqual(r.device?.displayName, "iPhone 13")
        XCTAssertEqual(r.recoveredAsset?.assetTag, "AST3")
    }

    func testDeployExternalDataDecodesNested() throws {
        let json = #"""
        { "asset": { "id":"a1","asset_tag":"AST1","name":"n","status":"deployed" },
          "deployment": { "id":"dep1","asset_id":"a1","customer_name":"Acme","status":"deployed","created_at":"2026-01-01" } }
        """#
        let r = try decode(DeployExternalData.self, json)
        XCTAssertEqual(r.asset.status, .deployed)
        XCTAssertEqual(r.deployment.customerName, "Acme")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the class. Expected: FAIL — `cannot find type 'EditAssetResponse'`.

- [ ] **Step 3: Append the response structs** to `InventoryWriteModels.swift`

```swift
// MARK: - Custom response shapes (envelope-level siblings of `data`, or nested)

/// PUT /api/assets/:id — full body (sku_updated_count sits beside `data`).
struct EditAssetResponse: Decodable {
    let success: Bool
    let data: Asset
    let skuUpdatedCount: Int?
}

/// POST /api/assets/:id/allocate — full body.
struct AllocateResponse: Decodable {
    let success: Bool
    let data: Asset
    let promptReadyToRepair: Bool?
    let allocatedParts: [AllocatedPart]?
    let device: AllocateDevice?
    let recoveredAsset: Asset?   // Asset already carries productTypeName/locationName/subLocationCode
}

struct AllocatedPart: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var assetName: String?
    var assetTag: String?
    var sourceStatus: String?
}

struct AllocateDevice: Decodable, Equatable, Sendable {
    let id: String
    var status: String?
    var displayName: String?
}

/// POST /api/assets/:id/deploy-external — this shape sits UNDER `data`.
struct DeployExternalData: Decodable, Equatable, Sendable {
    let asset: Asset
    let deployment: ExternalDeploymentRecord   // reused from Phase 1 (Core/Models/Inventory.swift)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the class. Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift" "Repair Minder/Repair MinderTests/InventoryWriteModelTests.swift"
git commit -m "feat(inventory): Phase 2 custom response structs + decode tests"
```

---

## Task 3: API endpoints (PUT/POST/DELETE)

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift`

- [ ] **Step 1: Add the enum cases** — after line 212 (`case assetGroupsList(...)`), inside the Inventory block:
```swift
    // Inventory / Assets — write actions (Phase 2)
    case updateAsset(id: String)
    case moveAsset(id: String)
    case allocateAsset(id: String)
    case deployExternalAsset(id: String)
    case returnExternalAsset(id: String)
    case returnToSupplierAsset(id: String)
    case resolveSupplierReturn(id: String)
    case deleteAsset(id: String)
```

- [ ] **Step 2: Add the paths** — after line 516 (`.inventoryExternalDeployment` path):
```swift
        case .updateAsset(let id): return "/api/assets/\(id)"
        case .moveAsset(let id): return "/api/assets/\(id)/move"
        case .allocateAsset(let id): return "/api/assets/\(id)/allocate"
        case .deployExternalAsset(let id): return "/api/assets/\(id)/deploy-external"
        case .returnExternalAsset(let id): return "/api/assets/\(id)/return-external"
        case .returnToSupplierAsset(let id): return "/api/assets/\(id)/return-to-supplier"
        case .resolveSupplierReturn(let id): return "/api/assets/\(id)/resolve-supplier-return"
        case .deleteAsset(let id): return "/api/assets/\(id)"
```

- [ ] **Step 3: Add to the method groups**

In the POST group (ends at line 618 with `.diagnosticsComplete:`), append before the colon:
```swift
             .moveAsset, .allocateAsset, .deployExternalAsset,
             .returnExternalAsset, .returnToSupplierAsset, .resolveSupplierReturn,
```
In the PUT group (line 633-635), add `.updateAsset`:
```swift
        case .togglePasscodeEnabled, .passcodeTimeout,
             .updatePushPreferences, .updateAsset:
            return .put
```
In the DELETE group (line 638-643), add `.deleteAsset`:
```swift
        case .deleteOrderDevice, .deleteOrderItem, .deleteOrderPayment,
             .deleteClient,
             .unregisterDeviceToken, .customerUnregisterDeviceToken,
             .cancelMacroExecution,
             .boardDeleteColumn, .boardDeleteAction,
             .deleteDeviceImage, .deleteAsset:
            return .delete
```
(No `queryItems` needed — all fall through to the default `nil`. `requiresAuth` defaults to `true`.)

- [ ] **Step 4: Build to verify it compiles**

Run the build command. Expected: success (all switches exhaustive).

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIEndpoints.swift"
git commit -m "feat(inventory): Phase 2 write-action API endpoints"
```

---

## Task 4: `APIClient.requestFull` helper

Captures the whole top-level envelope (for `sku_updated_count` / `prompt_ready_to_repair`, which the standard `APIResponse<T>` drops).

**Files:**
- Modify: `Repair Minder/Repair Minder/Core/Networking/APIClient.swift`

- [ ] **Step 1: Inspect the existing decode path**

Run: `grep -n "performRequest\|private let decoder\|func request<" "Repair Minder/Repair Minder/Core/Networking/APIClient.swift" | head`
Note the private `performRequest(_:body:)` signature and the shared `decoder`. The helper reuses whatever `performRequest` does for auth/refresh, but decodes `R` directly instead of `APIResponse<T>`.

- [ ] **Step 2: Add the method** (place it right after `request<T>(_:body:)`, ~line 86):
```swift
    /// Perform a request and decode the ENTIRE top-level JSON body as `R`,
    /// without unwrapping `.data`. Use when you need envelope-level fields that
    /// `APIResponse<T>` discards (e.g. `sku_updated_count`, `prompt_ready_to_repair`).
    func requestFull<R: Decodable>(
        _ endpoint: APIEndpoint,
        body: Encodable? = nil
    ) async throws -> R {
        let data = try await performRequestData(endpoint, body: body)
        do {
            return try decoder.decode(R.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
```

- [ ] **Step 3: Ensure a raw-Data request path exists**

If `performRequest<T>` decodes internally and does not expose raw `Data`, add a sibling that returns the validated `Data` (mirror `performRequest`'s HTTP handling — success 2xx returns body; 401 → `handleTokenRefresh()` + retry; else map to `APIError`). Name it `performRequestData(_:body:) async throws -> Data`. Reuse `buildRequest(endpoint, body:)` and `session.data(for:)` exactly as `requestRawData` does (APIClient.swift:153), but ADD the `body` parameter to `buildRequest` (the existing `request<T>` already passes a body through `performRequest`, so `buildRequest` supports it — pass it through).

Concretely, if `performRequest` already produces `Data` before decoding, refactor the minimal shared step out; otherwise add:
```swift
    private func performRequestData(_ endpoint: APIEndpoint, body: Encodable? = nil) async throws -> Data {
        let request = try buildRequest(endpoint, body: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }
        switch http.statusCode {
        case 200...299: return data
        case 401 where endpoint.requiresAuth:
            try await handleTokenRefresh()
            let retry = try buildRequest(endpoint, body: body)
            let (rd, rr) = try await session.data(for: retry)
            guard let rh = rr as? HTTPURLResponse, (200...299).contains(rh.statusCode) else { throw APIError.unauthorized }
            return rd
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden(message: nil, code: nil)
        default: throw APIError.httpError(statusCode: http.statusCode, message: nil)
        }
    }
```
> If `buildRequest` currently has no `body:` parameter, check how `performRequest` injects the body and reuse that exact mechanism instead of duplicating it. Keep this additive — do not change `request<T>`/`requestVoid`.

- [ ] **Step 4: Build to verify it compiles**

Run the build command. Expected: success.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Core/Networking/APIClient.swift"
git commit -m "feat(networking): requestFull<R> for envelope-level response fields"
```

---

## Task 5: Extend `InventoryServing` / `InventoryService`

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift`

- [ ] **Step 1: Add methods to the protocol** (append inside `protocol InventoryServing`):
```swift
    // Phase 2 write actions
    func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse
    func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset
    func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse
    func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData
    func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset
    func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset
    func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset
    func deleteAsset(id: String) async throws
    // Deploy wizard support
    func searchOrders(search: String) async throws -> [Order]
    func fetchOrderItems(orderId: String) async throws -> [OrderItem]
```

- [ ] **Step 2: Implement them** (append inside `final class InventoryService`):
```swift
    func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse {
        try await api.requestFull(.updateAsset(id: id), body: body)
    }
    func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset {
        try await api.request(.moveAsset(id: id), body: body)
    }
    func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
        try await api.requestFull(.allocateAsset(id: id), body: body)
    }
    func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData {
        try await api.request(.deployExternalAsset(id: id), body: body)
    }
    func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset {
        try await api.request(.returnExternalAsset(id: id), body: body)
    }
    func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset {
        try await api.request(.returnToSupplierAsset(id: id), body: body)
    }
    func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset {
        try await api.request(.resolveSupplierReturn(id: id), body: body)
    }
    func deleteAsset(id: String) async throws {
        try await api.requestVoid(.deleteAsset(id: id))
    }
    func searchOrders(search: String) async throws -> [Order] {
        try await api.request(.orders(page: 1, limit: 10, status: nil, paymentStatus: nil,
                                       locationId: nil, assignedUserId: nil, search: search))
    }
    func fetchOrderItems(orderId: String) async throws -> [OrderItem] {
        try await api.request(.orderItems(orderId: orderId))
    }
```
> `Order` / `OrderItem` are the existing models in `Core/Models/Order.swift`. If `.orders` decodes through a wrapper other than `[Order]`, match the shape the existing Orders list view model uses (grep `OrderListViewModel` for the exact `request` call) — reuse that call verbatim.

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryService.swift"
git commit -m "feat(inventory): InventoryService write methods + order lookup"
```

---

## Task 6: List change-notification + coalescing fix

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift`
- Create test: `Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift`:
```swift
import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryWriteViewModelTests: XCTestCase {

    /// Mock that lets a test observe every query it was called with and control timing.
    final class RecordingService: InventoryServing {
        var queries: [AssetQuery] = []
        var resultProvider: (AssetQuery) -> [Asset] = { _ in [] }
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            queries.append(filters); return resultProvider(filters)
        }
        func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
        func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse { fatalError() }
        func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset { fatalError() }
        func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse { fatalError() }
        func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData { fatalError() }
        func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset { fatalError() }
        func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset { fatalError() }
        func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset { fatalError() }
        func deleteAsset(id: String) async throws {}
        func searchOrders(search: String) async throws -> [Order] { [] }
        func fetchOrderItems(orderId: String) async throws -> [OrderItem] { [] }
    }

    func testFilterChangeDuringLoadIsNotDropped() async {
        let mock = RecordingService()
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        // First load returns "deployed" results; then we switch status mid-flight.
        vm.selectedStatus = .deployed
        async let first: Void = vm.loadAssets()
        // Change the query while the first load is (conceptually) in flight, then request another load.
        vm.selectedStatus = .damaged
        await vm.loadAssets()
        await first
        // The coalesced reload must have run with the LATEST query.
        XCTAssertEqual(mock.queries.last?.status, "damaged")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run `-only-testing:"Repair MinderTests/InventoryWriteViewModelTests/testFilterChangeDuringLoadIsNotDropped"`. Expected: FAIL (the current `guard !isLoading { return }` drops the second call, so `queries.last?.status` is `"deployed"`, not `"damaged"`).

- [ ] **Step 3: Replace the guard with coalescing** in `InventoryListViewModel`

Add a private flag near the other private state:
```swift
    private var pendingReload = false
```
Replace `loadAssets()`:
```swift
    func loadAssets() async {
        if isLoading { pendingReload = true; return }
        repeat {
            pendingReload = false
            isLoading = true; error = nil; currentPage = 1
            do {
                let page = try await service.fetchAssets(page: 1, pageSize: pageSize, filters: query)
                assets = page
                hasMore = page.count == pageSize
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        } while pendingReload
    }
```

- [ ] **Step 4: Add the change observer** — in `init`, after assigning `service`/`pageSize`:
```swift
        NotificationCenter.default.addObserver(
            forName: .inventoryAssetDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.needsReload = true }
        }
```
Add the published flag and a reload hook the view calls on appear:
```swift
    @Published var needsReload = false
    func reloadIfNeeded() async {
        guard needsReload else { return }
        needsReload = false
        await loadAssets()
    }
```
Define the notification name (put it in `InventoryWriteModels.swift` or a small extension file):
```swift
extension Notification.Name {
    /// Posted after any single-asset mutation so the inventory list refreshes.
    static let inventoryAssetDidChange = Notification.Name("inventoryAssetDidChange")
}
```

- [ ] **Step 5: Have the list observe it** — in `InventoryListView.content`, add to the outer view:
```swift
        .onReceive(NotificationCenter.default.publisher(for: .inventoryAssetDidChange)) { _ in
            Task { await viewModel.loadAssets() }
        }
```
(Belt-and-braces with `needsReload`; either path reloads. Keep only `.onReceive` if simpler — but `needsReload` covers the case where the list is off-screen.)

- [ ] **Step 6: Run the test to verify it passes**

Run the test from Step 2. Expected: PASS. Then run the full `InventoryListViewModelTests` (Phase 1) to confirm no regression.

- [ ] **Step 7: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListViewModel.swift" "Repair Minder/Repair Minder/Core/Models/InventoryWriteModels.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift" "Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift"
git commit -m "fix(inventory): coalesce filter changes during load + list-change notification"
```

---

## Task 7: `InventoryDetailViewModel` mutation methods

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift`
- Modify: `Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift` (append)

- [ ] **Step 1: Write the failing tests** (append to `InventoryWriteViewModelTests`)

```swift
extension InventoryWriteViewModelTests {
    /// Mock returning canned mutation results.
    final class MutatingService: InventoryServing {
        var deleted = false
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] { [] }
        func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
        func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse {
            EditAssetResponse(success: true, data: Asset(id: id, assetTag: "T", name: "Edited", status: .inStock), skuUpdatedCount: 2)
        }
        func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "Moved", status: .inStock) }
        func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
            AllocateResponse(success: true, data: Asset(id: id, assetTag: "T", name: "n", status: .allocated),
                             promptReadyToRepair: true, allocatedParts: nil, device: nil, recoveredAsset: nil)
        }
        func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData {
            DeployExternalData(asset: Asset(id: id, assetTag: "T", name: "n", status: .deployed),
                               deployment: ExternalDeploymentRecord(id: "dep1"))
        }
        func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
        func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .pendingReturn) }
        func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .returned) }
        func deleteAsset(id: String) async throws { deleted = true }
        func searchOrders(search: String) async throws -> [Order] { [] }
        func fetchOrderItems(orderId: String) async throws -> [OrderItem] { [] }
    }

    func testEditUpdatesAssetAndSurfacesSkuCount() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.edit(UpdateAssetRequest(name: "Edited"))
        XCTAssertEqual(vm.asset?.name, "Edited")
        XCTAssertEqual(vm.lastSkuUpdatedCount, 2)
        XCTAssertNil(vm.actionError)
    }

    func testDeleteSetsDidDelete() async {
        let mock = MutatingService()
        let vm = InventoryDetailViewModel(assetId: "a1", service: mock)
        await vm.load()
        await vm.delete()
        XCTAssertTrue(mock.deleted)
        XCTAssertTrue(vm.didDelete)
    }
}
```
> `ExternalDeploymentRecord(id: "dep1")` requires the Phase-1 struct to allow an id-only init — it does (all other fields optional).

- [ ] **Step 2: Run to verify it fails**

Run `-only-testing:"Repair MinderTests/InventoryWriteViewModelTests"`. Expected: FAIL — `value of type 'InventoryDetailViewModel' has no member 'edit'`.

- [ ] **Step 3: Add mutation state + methods** to `InventoryDetailViewModel`

Add published state:
```swift
    @Published var actionError: String?
    @Published var lastSkuUpdatedCount: Int?
    @Published var readyToRepairPrompt = false
    @Published private(set) var didDelete = false
    @Published private(set) var isMutating = false
```
Add methods:
```swift
    private func applyUpdated(_ updated: Asset) {
        asset = updated
        NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
    }
    private func refreshSubResources() async {
        async let act = try? service.fetchActivity(id: assetId)
        async let ext = try? service.fetchExternalDeployment(id: assetId)
        activity = await act ?? []
        externalDeployment = await ext
    }

    func edit(_ body: UpdateAssetRequest) async {
        isMutating = true; actionError = nil
        do {
            let resp = try await service.updateAsset(id: assetId, body: body)
            applyUpdated(resp.data)
            lastSkuUpdatedCount = (resp.skuUpdatedCount ?? 0) > 0 ? resp.skuUpdatedCount : nil
            await refreshSubResources()
        } catch { actionError = error.localizedDescription }
        isMutating = false
    }

    func move(_ body: MoveAssetRequest) async {
        await run { try await self.service.moveAsset(id: self.assetId, body: body) }
    }
    func returnToStock(_ body: ReturnExternalRequest) async {
        await run { try await self.service.returnExternal(id: self.assetId, body: body) }
    }
    func returnToSupplier(_ body: ReturnToSupplierRequest) async {
        await run { try await self.service.returnToSupplier(id: self.assetId, body: body) }
    }
    func resolveReturn(_ body: ResolveReturnRequest) async {
        await run { try await self.service.resolveSupplierReturn(id: self.assetId, body: body) }
    }

    func allocate(_ body: AllocateRequest) async -> AllocateResponse? {
        isMutating = true; actionError = nil
        defer { isMutating = false }
        do {
            let resp = try await service.allocateAsset(id: assetId, body: body)
            applyUpdated(resp.data)
            readyToRepairPrompt = resp.promptReadyToRepair ?? false
            await refreshSubResources()
            return resp
        } catch { actionError = error.localizedDescription; return nil }
    }

    func deployExternal(_ body: DeployExternalRequest) async {
        isMutating = true; actionError = nil
        do {
            let data = try await service.deployExternal(id: assetId, body: body)
            applyUpdated(data.asset)
            await refreshSubResources()
        } catch { actionError = error.localizedDescription }
        isMutating = false
    }

    func delete() async {
        isMutating = true; actionError = nil
        do {
            try await service.deleteAsset(id: assetId)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            didDelete = true
        } catch { actionError = error.localizedDescription }
        isMutating = false
    }

    /// Shared helper for mutations that just return an updated Asset.
    private func run(_ op: @escaping () async throws -> Asset) async {
        isMutating = true; actionError = nil
        do { applyUpdated(try await op()); await refreshSubResources() }
        catch { actionError = error.localizedDescription }
        isMutating = false
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run `-only-testing:"Repair MinderTests/InventoryWriteViewModelTests"`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailViewModel.swift" "Repair Minder/Repair MinderTests/InventoryWriteViewModelTests.swift"
git commit -m "feat(inventory): detail view-model mutation methods + tests"
```

---

## Task 8: `AssetEditSheet`

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetEditSheet.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

struct AssetEditSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var serialNumber: String
    @State private var sku: String
    @State private var category: String
    @State private var conditionGrade: String
    @State private var isOem: Bool
    @State private var isRefurbished: Bool
    @State private var warrantyMonths: String
    @State private var notes: String
    @State private var categorySuggestions: [String] = []

    init(asset: Asset, viewModel: InventoryDetailViewModel) {
        self.asset = asset
        self.viewModel = viewModel
        _serialNumber = State(initialValue: asset.serialNumber ?? "")
        _sku = State(initialValue: asset.sku ?? "")
        _category = State(initialValue: asset.category ?? "")
        _conditionGrade = State(initialValue: asset.conditionGrade ?? "")
        _isOem = State(initialValue: asset.isOemBool)
        _isRefurbished = State(initialValue: asset.isRefurbishedBool)
        _warrantyMonths = State(initialValue: asset.warrantyMonths.map(String.init) ?? "")
        _notes = State(initialValue: asset.notes ?? "")
    }

    private var categoryChanged: Bool { category != (asset.category ?? "") }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Serial number", text: $serialNumber)
                    TextField("SKU", text: $sku)
                    TextField("Category", text: $category)
                    if asset.sku != nil, !(asset.sku ?? "").isEmpty, categoryChanged {
                        Text("This will update all assets with SKU: \(asset.sku ?? "")")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if !categorySuggestions.isEmpty {
                        Menu("Suggestions") {
                            ForEach(categorySuggestions, id: \.self) { s in
                                Button(s) { category = s }
                            }
                        }.font(.caption)
                    }
                }
                Section("Quality") {
                    Picker("Condition grade", selection: $conditionGrade) {
                        Text("Not set").tag("")
                        Text("A - Excellent").tag("A")
                        Text("B - Good").tag("B")
                        Text("C - Fair").tag("C")
                        Text("D - Poor").tag("D")
                        Text("F - For Parts").tag("F")
                    }
                    Toggle("OEM", isOn: $isOem)
                    Toggle("Refurbished", isOn: $isRefurbished)
                }
                Section("Warranty") {
                    TextField("Warranty months", text: $warrantyMonths)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(viewModel.isMutating)
                }
            }
            .task {
                categorySuggestions = (try? await InventoryService().fetchCategories()) ?? []
            }
        }
    }

    private func save() async {
        var body = UpdateAssetRequest()
        body.name = asset.name  // carried through unchanged (web parity)
        body.serialNumber = serialNumber.isEmpty ? nil : serialNumber
        body.sku = sku.isEmpty ? nil : sku
        body.category = category.isEmpty ? nil : category
        body.conditionGrade = conditionGrade.isEmpty ? nil : conditionGrade
        body.isOem = isOem ? 1 : 0
        body.isRefurbished = isRefurbished ? 1 : 0
        body.warrantyMonths = Int(warrantyMonths)
        body.notes = notes.isEmpty ? nil : notes
        await viewModel.edit(body)
        if viewModel.actionError == nil { dismiss() }
    }
}
```

- [ ] **Step 2: Commit** (build-verified together in Task 13)

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetEditSheet.swift"
git commit -m "feat(inventory): asset edit sheet with SKU-propagation warning"
```

---

## Task 9: `AssetMoveSheet`

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetMoveSheet.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

struct AssetMoveSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var locations: [Location] = []
    @State private var subLocations: [AssetSubLocationOption] = []
    @State private var locationId: String?
    @State private var subLocationId: String?
    @State private var loadError: String?

    private var changed: Bool { locationId != asset.locationId || subLocationId != asset.subLocationId }
    private var canSubmit: Bool { locationId != nil && changed && !viewModel.isMutating }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    Picker("Location", selection: $locationId) {
                        Text("Select…").tag(String?.none)
                        ForEach(locations) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    .onChange(of: locationId) { _, new in
                        subLocationId = nil
                        subLocations = []
                        if let id = new { Task { await loadSubs(id) } }
                    }
                    if !subLocations.isEmpty {
                        Picker("Sub-location", selection: $subLocationId) {
                            Text("None").tag(String?.none)
                            ForEach(subLocations) { Text($0.code ?? $0.description ?? "—").tag(String?.some($0.id)) }
                        }
                    }
                }
                if let loadError { Text(loadError).font(.caption).foregroundStyle(.red) }
            }
            .navigationTitle("Move Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") { Task { await submit() } }.disabled(!canSubmit)
                }
            }
            .task {
                locationId = asset.locationId
                subLocationId = asset.subLocationId
                locations = (try? await InventoryService().fetchLocations()) ?? []
                if let id = asset.locationId { await loadSubs(id) }
            }
        }
    }

    private func loadSubs(_ id: String) async {
        subLocations = (try? await InventoryService().fetchSubLocations(locationId: id)) ?? []
    }
    private func submit() async {
        guard let locationId else { return }
        await viewModel.move(MoveAssetRequest(locationId: locationId, subLocationId: subLocationId))
        if viewModel.actionError == nil { dismiss() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/AssetMoveSheet.swift"
git commit -m "feat(inventory): asset move sheet (location + sub-location)"
```

---

## Task 10: `ReturnToSupplierSheet` + resolve action

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/ReturnToSupplierSheet.swift`

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI

struct ReturnToSupplierSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var reason: String = ""
    @State private var notes: String = ""

    private let reasons: [(value: String, label: String)] = [
        ("defective", "Defective / DOA"),
        ("wrong_part", "Wrong Part Sent"),
        ("damaged_in_transit", "Damaged in Transit"),
        ("quality_issue", "Quality Below Standard"),
        ("warranty_claim", "Warranty Claim"),
        ("order_error", "Ordered in Error"),
        ("other", "Other")
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let supplier = asset.supplierName {
                    Section("Supplier") { Text(supplier) }
                } else {
                    Section { Text("This asset has no supplier assigned. You won't be able to track this return.")
                        .font(.caption).foregroundStyle(.orange) }
                }
                Section("Reason") {
                    Picker("Return reason", selection: $reason) {
                        Text("Select…").tag("")
                        ForEach(reasons, id: \.value) { Text($0.label).tag($0.value) }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Return to Supplier")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Return") { Task { await submit() } }
                        .disabled(reason.isEmpty || asset.supplierName == nil || viewModel.isMutating)
                }
            }
        }
    }

    private func submit() async {
        await viewModel.returnToSupplier(
            ReturnToSupplierRequest(supplierReturnReason: reason,
                                    supplierReturnNotes: notes.isEmpty ? nil : notes))
        if viewModel.actionError == nil { dismiss() }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/ReturnToSupplierSheet.swift"
git commit -m "feat(inventory): return-to-supplier sheet"
```

---

## Task 11: `DeployViewModel` + `DeployExternalSheet`

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployViewModel.swift`
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployExternalSheet.swift`

- [ ] **Step 1: Write `DeployViewModel`**

```swift
import Foundation

@MainActor
final class DeployViewModel: ObservableObject {
    @Published var orderQuery = ""
    @Published private(set) var orders: [Order] = []
    @Published private(set) var items: [OrderItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingItems = false

    private let service: InventoryServing
    private var searchTask: Task<Void, Never>?
    init(service: InventoryServing? = nil) { self.service = service ?? InventoryService() }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await search()
        }
    }
    func search() async {
        guard !orderQuery.isEmpty else { orders = []; return }
        isSearching = true
        orders = (try? await service.searchOrders(search: orderQuery)) ?? []
        isSearching = false
    }
    func loadItems(orderId: String) async {
        isLoadingItems = true
        items = (try? await service.fetchOrderItems(orderId: orderId)) ?? []
        isLoadingItems = false
    }
}
```

- [ ] **Step 2: Write `DeployExternalSheet`**

```swift
import SwiftUI

struct DeployExternalSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var customerName = ""
    @State private var externalReference = ""
    @State private var notes = ""
    @State private var deploymentDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Customer name", text: $customerName)
                    TextField("Reference / job number", text: $externalReference)
                }
                Section("Deployment") {
                    DatePicker("Date", selection: $deploymentDate, displayedComponents: .date)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle("Deploy Externally")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Deploy") { Task { await submit() } }.disabled(viewModel.isMutating)
                }
            }
        }
    }

    private func submit() async {
        let df = DateFormatter(); df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"
        await viewModel.deployExternal(DeployExternalRequest(
            customerName: customerName.isEmpty ? nil : customerName,
            externalReference: externalReference.isEmpty ? nil : externalReference,
            notes: notes.isEmpty ? nil : notes,
            deploymentDate: df.string(from: deploymentDate)))
        if viewModel.actionError == nil { dismiss() }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployViewModel.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployExternalSheet.swift"
git commit -m "feat(inventory): deploy view model + external-deploy sheet"
```

---

## Task 12: `PartRecoveryForm` + `DeployToOrderWizard` + `DeployChooserSheet`

**Files:**
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/PartRecoveryForm.swift`
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployToOrderWizard.swift`
- Create: `Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployChooserSheet.swift`

- [ ] **Step 1: Write `PartRecoveryForm`** (a bindable sub-form; parent owns the state)

```swift
import SwiftUI

struct PartRecoveryState {
    var enabled = false
    var conditionGrade = "A"
    var locationId: String?
    var subLocationId: String?
    var notes = ""
    var lcdWorking = true
    var glassCracked = false

    /// Valid only when enabled requires a grade (A/B/C) + a location.
    var isValid: Bool { !enabled || (["A","B","C"].contains(conditionGrade) && locationId != nil) }
    func toInput() -> RecoveryInput? {
        guard enabled, let locationId else { return nil }
        return RecoveryInput(conditionGrade: conditionGrade, locationId: locationId,
                             subLocationId: subLocationId, notes: notes.isEmpty ? nil : notes,
                             lcdWorking: lcdWorking ? 1 : 0, glassCracked: glassCracked ? 1 : 0)
    }
}

struct PartRecoveryForm: View {
    @Binding var state: PartRecoveryState
    @State private var locations: [Location] = []

    var body: some View {
        Section("Recover a pulled part") {
            Toggle("Recover a part from this device", isOn: $state.enabled)
            if state.enabled {
                Picker("Condition", selection: $state.conditionGrade) {
                    Text("A - Excellent").tag("A"); Text("B - Good").tag("B"); Text("C - Fair").tag("C")
                }
                Picker("Location", selection: $state.locationId) {
                    Text("Select…").tag(String?.none)
                    ForEach(locations) { Text($0.name).tag(String?.some($0.id)) }
                }
                Toggle("LCD working", isOn: $state.lcdWorking)
                Toggle("Glass cracked", isOn: $state.glassCracked)
                TextField("Notes", text: $state.notes, axis: .vertical).lineLimit(2...4)
            }
        }
        .task { locations = (try? await InventoryService().fetchLocations()) ?? [] }
    }
}
```

- [ ] **Step 2: Write `DeployToOrderWizard`**

```swift
import SwiftUI

struct DeployToOrderWizard: View {
    let asset: Asset
    @ObservedObject var detailVM: InventoryDetailViewModel
    let onFinished: () -> Void

    @StateObject private var vm = DeployViewModel()
    @Environment(\.dismiss) private var dismiss

    private enum Step { case search, selectItem, confirm, done }
    @State private var step: Step = .search
    @State private var selectedOrder: Order?
    @State private var selectedItem: OrderItem?
    @State private var recovery = PartRecoveryState()
    @State private var recoveredAsset: Asset?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .search: searchStep
                case .selectItem: itemStep
                case .confirm: confirmStep
                case .done: doneStep
                }
            }
            .navigationTitle("Allocate to Order")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(step == .done ? "Done" : "Cancel") { if step == .done { onFinished() }; dismiss() }
            } }
        }
    }

    private var searchStep: some View {
        List {
            Section {
                TextField("Search orders…", text: $vm.orderQuery)
                    .onChange(of: vm.orderQuery) { _, _ in vm.searchChanged() }
            }
            if vm.isSearching { ProgressView() }
            ForEach(vm.orders) { order in
                Button {
                    selectedOrder = order
                    Task { await vm.loadItems(orderId: order.id); step = .selectItem }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Order #\(order.ticketNumber.map(String.init) ?? order.id)").font(.subheadline.weight(.semibold))
                        if let s = order.status { Text(s).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }

    private var itemStep: some View {
        List {
            if vm.isLoadingItems { ProgressView() }
            else if vm.items.isEmpty {
                Text("No line items on this order. Add one in the order first.").foregroundStyle(.secondary)
            } else {
                Section("Select a line item (optional)") {
                    Button("No specific line item") { selectedItem = nil; step = .confirm }
                    ForEach(vm.items) { item in
                        Button {
                            selectedItem = item; step = .confirm
                        } label: { Text(item.description ?? item.name ?? item.id) }
                    }
                }
            }
        }
    }

    private var confirmStep: some View {
        Form {
            Section("Allocation") {
                LabeledContent("Asset", value: asset.assetTag)
                LabeledContent("Order", value: selectedOrder?.ticketNumber.map(String.init) ?? "—")
            }
            if asset.enablePartRecoveryBool { PartRecoveryForm(state: $recovery) }
            Section {
                Button("Allocate") { Task { await allocate() } }
                    .disabled(!recovery.isValid || detailVM.isMutating)
            }
            if let err = detailVM.actionError { Text(err).font(.caption).foregroundStyle(.red) }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
            Text("Asset Allocated").font(.headline)
            if let r = recoveredAsset {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pulled Part Recovered").font(.subheadline.weight(.semibold))
                    Text(r.assetTag).font(.caption.monospaced())
                }
                .padding().background(Color.orange.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.padding()
    }

    private func allocate() async {
        let body = AllocateRequest(orderId: selectedOrder?.id, deviceId: nil,
                                   orderItemId: selectedItem?.id, deploy: false,
                                   recovery: recovery.toInput())
        if let resp = await detailVM.allocate(body) {
            recoveredAsset = resp.recoveredAsset
            step = .done
        }
    }
}
```
> `order.ticketNumber`, `order.status`, `item.description`/`item.name` are on the existing `Order`/`OrderItem` models. If a field name differs, grep `Core/Models/Order.swift` and match — do NOT invent fields.

- [ ] **Step 3: Write `DeployChooserSheet`**

```swift
import SwiftUI

struct DeployChooserSheet: View {
    let asset: Asset
    @ObservedObject var viewModel: InventoryDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var route: Route?

    private enum Route: Identifiable { case order, external; var id: Int { hashValue } }

    var body: some View {
        NavigationStack {
            List {
                Button { route = .order } label: {
                    Label { VStack(alignment: .leading) {
                        Text("To Order"); Text("Allocate to an existing RepairMinder order").font(.caption).foregroundStyle(.secondary)
                    } } icon: { Image(systemName: "shippingbox") }
                }
                Button { route = .external } label: {
                    Label { VStack(alignment: .leading) {
                        Text("External"); Text("Deploy to an external job or customer").font(.caption).foregroundStyle(.secondary)
                    } } icon: { Image(systemName: "arrow.up.forward.app") }
                }
            }
            .navigationTitle("Deploy Asset")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(item: $route) { r in
                switch r {
                case .order: DeployToOrderWizard(asset: asset, detailVM: viewModel) { dismiss() }
                case .external: DeployExternalSheet(asset: asset, viewModel: viewModel)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/PartRecoveryForm.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployToOrderWizard.swift" "Repair Minder/Repair Minder/Features/Staff/Inventory/Actions/DeployChooserSheet.swift"
git commit -m "feat(inventory): deploy chooser + to-order wizard + part recovery"
```

---

## Task 13: Wire actions into `InventoryDetailView`

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailView.swift`

- [ ] **Step 1: Add sheet + dialog state** to `InventoryDetailView`
```swift
    @State private var showEdit = false
    @State private var showMove = false
    @State private var showDeploy = false
    @State private var showReturnSupplier = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss
```

- [ ] **Step 2: Add the toolbar + modifiers** — replace the `.task`/`.refreshable` tail of `body` with:
```swift
        .task { if viewModel.asset == nil { await viewModel.load() } }
        .refreshable { await viewModel.refresh() }
        .toolbar { if let asset = viewModel.asset { toolbarMenu(asset) } }
        .sheet(isPresented: $showEdit) { if let a = viewModel.asset { AssetEditSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showMove) { if let a = viewModel.asset { AssetMoveSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showDeploy) { if let a = viewModel.asset { DeployChooserSheet(asset: a, viewModel: viewModel) } }
        .sheet(isPresented: $showReturnSupplier) { if let a = viewModel.asset { ReturnToSupplierSheet(asset: a, viewModel: viewModel) } }
        .confirmationDialog("Delete asset \(viewModel.asset?.assetTag ?? "")? This cannot be undone.",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await viewModel.delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Action failed", isPresented: Binding(
            get: { viewModel.actionError != nil },
            set: { if !$0 { viewModel.actionError = nil } })) {
            Button("OK") { viewModel.actionError = nil }
        } message: { Text(viewModel.actionError ?? "") }
        .onChange(of: viewModel.didDelete) { _, deleted in if deleted { dismiss() } }
```

- [ ] **Step 3: Add the toolbar menu builder** (mirrors web gating):
```swift
    @ToolbarContentBuilder private func toolbarMenu(_ a: Asset) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                Button { showMove = true } label: { Label("Move", systemImage: "arrow.left.arrow.right") }
                if a.status == .inStock {
                    Button { showDeploy = true } label: { Label("Deploy", systemImage: "paperplane") }
                }
                Button { showReturnSupplier = true } label: { Label("Return to Supplier", systemImage: "arrow.uturn.backward") }
                    .disabled(!canReturnToSupplier(a))
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                    .disabled(a.status == .allocated || a.status == .deployed)
            } label: { Image(systemName: "ellipsis.circle") }
        }
    }

    private func canReturnToSupplier(_ a: Asset) -> Bool {
        [.inStock, .allocated, .deployed].contains(a.status)
            && a.supplierName != nil && a.status != .pendingReturn
    }
```

- [ ] **Step 4: Add the "Return to Stock" button** to the Status & Location card — inside the `if let ext = viewModel.externalDeployment?.active { ... }` block, after the history row:
```swift
                if a.status == .deployed {
                    Button("Return to Stock") {
                        Task { await viewModel.returnToStock(
                            ReturnExternalRequest(deploymentId: ext.id, returnToStock: true, notes: nil)) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isMutating)
                }
```

- [ ] **Step 5: Add resolve actions to the Pending-Return banner** — replace the `if a.status == .pendingReturn { card("Pending Return") { ... } }` block with one that appends resolve buttons:
```swift
        if a.status == .pendingReturn { card("Pending Return") {
            row("Reason", a.supplierReturnReason); row("Notes", a.supplierReturnNotes); row("Initiated", a.supplierReturnInitiatedAt)
            HStack {
                Button("Credit Received") {
                    Task { await viewModel.resolveReturn(ResolveReturnRequest(resolution: "credit_received", replacementAssetId: nil, notes: nil)) }
                }.buttonStyle(.bordered)
                Button("Replacement Received") {
                    Task { await viewModel.resolveReturn(ResolveReturnRequest(resolution: "replacement_received", replacementAssetId: nil, notes: nil)) }
                }.buttonStyle(.bordered)
            }.disabled(viewModel.isMutating).padding(.top, 4)
        } }
```
> Replacement-asset linking is optional server-side; Phase 2 resolves without linking (matches the web "Resolve Without Link" path). A future phase can add asset search.

- [ ] **Step 6: Surface the SKU-count toast** — add below the header, driven by `viewModel.lastSkuUpdatedCount`:
```swift
        if let n = viewModel.lastSkuUpdatedCount {
            Text("Category also applied to \(n) other asset\(n == 1 ? "" : "s") with the same SKU")
                .font(.caption).foregroundStyle(.blue)
                .task { try? await Task.sleep(nanoseconds: 4_000_000_000); viewModel.lastSkuUpdatedCount = nil }
        }
```

- [ ] **Step 7: Full build**

Run the build command. Expected: success (Tasks 8–12 views now all resolve). Fix any `Order`/`OrderItem` field-name mismatches by grepping `Core/Models/Order.swift`.

- [ ] **Step 8: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryDetailView.swift"
git commit -m "feat(inventory): detail toolbar, deploy/return/resolve actions, delete confirm"
```

---

## Task 14: Guarded swipe-delete on the list

**Files:**
- Modify: `Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift`

- [ ] **Step 1: Add swipe state + action** — in the `ForEach(viewModel.assets)` row, add `.swipeActions` and a confirm dialog. Replace the row `Button { ... } label: { AssetRow(asset: asset) }` block with:
```swift
                ForEach(viewModel.assets) { asset in
                    Button { selectedAssetId = asset.id } label: { AssetRow(asset: asset) }
                        .buttonStyle(.plain)
                        .task { await viewModel.loadMoreIfNeeded(currentItem: asset) }
                        .swipeActions(edge: .trailing) {
                            if asset.status != .allocated && asset.status != .deployed {
                                Button(role: .destructive) { pendingDelete = asset } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                }
```

- [ ] **Step 2: Add the state + confirm dialog + delete call** — add to `InventoryListView`:
```swift
    @State private var pendingDelete: Asset?
```
And on `content` (or `mainList`):
```swift
        .confirmationDialog("Delete asset \(pendingDelete?.assetTag ?? "")?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let a = pendingDelete { Task { await deleteFromList(a) } }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
```
Add the helper:
```swift
    private func deleteFromList(_ asset: Asset) async {
        do {
            try await InventoryService().deleteAsset(id: asset.id)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
        } catch { /* list stays; detail surfaces errors */ }
        pendingDelete = nil
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run the build command. Expected: success.

- [ ] **Step 4: Commit**

```bash
git add "Repair Minder/Repair Minder/Features/Staff/Inventory/InventoryListView.swift"
git commit -m "feat(inventory): guarded swipe-to-delete on list rows"
```

---

## Task 15: Full verification + runtime smoke

**Files:** none (verification only) — plus possible tweaks to Task-2 structs if real JSON differs.

- [ ] **Step 1: Run the full inventory test suite**

```bash
xcodebuild test -project "Repair Minder/Repair Minder.xcodeproj" -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ../build-derived-data -clonedSourcePackagesDirPath /tmp/rm-spm \
  -parallel-testing-enabled NO \
  -only-testing:"Repair MinderTests/InventoryWriteModelTests" \
  -only-testing:"Repair MinderTests/InventoryWriteViewModelTests" \
  -only-testing:"Repair MinderTests/InventoryModelTests" \
  -only-testing:"Repair MinderTests/InventoryListViewModelTests" 2>&1 | tail -25
```
Expected: all pass.

- [ ] **Step 2: Capture REAL JSON and reconcile decode structs**

Get an admin token per `repairminder/docs/REFERENCE-test-tokens/CLAUDE.md` (test the existing token FIRST). Then, for the admin company `4b63c1e6ade1885e73171e10221cac53` (HAS assets), capture a real edit response:
```bash
# pick a real asset id from the list
ASSET=$(curl -s "https://api.repairminder.com/api/assets?limit=1" -H "Authorization: Bearer <TOKEN>" | jq -r '.data[0].id')
# edit its notes (harmless) and inspect the envelope
curl -s -X PUT "https://api.repairminder.com/api/assets/$ASSET" -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" -d '{"notes":"phase2 smoke"}' | jq '{keys: keys, sku_updated_count, data_keys: (.data|keys)}'
```
Confirm `sku_updated_count` is present and `data` is a full asset row. If any field type differs from the Task-2 structs, adjust the struct and re-run Step 1.

- [ ] **Step 3: Runtime mutation smoke (seed → mutate → clean up)**

```bash
# Seed a disposable asset
NEW=$(curl -s -X POST "https://api.repairminder.com/api/assets" -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name":"P2 Smoke Asset","category":"Test","status":"in_stock"}' | jq -r '.data.id')
# Move it (needs a real location id)
LOC=$(curl -s "https://api.repairminder.com/api/locations" -H "Authorization: Bearer <TOKEN>" | jq -r '.data[0].id')
curl -s -X POST "https://api.repairminder.com/api/assets/$NEW/move" -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" -d "{\"location_id\":\"$LOC\"}" | jq '.success'
# Edit it
curl -s -X PUT "https://api.repairminder.com/api/assets/$NEW" -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" -d '{"notes":"edited"}' | jq '.success'
# Delete it (cleanup)
curl -s -X DELETE "https://api.repairminder.com/api/assets/$NEW" -H "Authorization: Bearer <TOKEN>" | jq '.success'
```
Expected: each `true`. This proves the request/response contracts the app uses are correct against prod. (Deploy-to-order requires a seeded order + line item; if that is impractical, decode-verify the `allocate` response shape instead and report honestly.)

- [ ] **Step 4: iOS build (both schemes' new-file compilation)**

Run the build command for the "Repair Minder" scheme — expect success. Confirm the new files also compile for Mac by building the Mac scheme and checking that NO NEW errors appear in the Inventory files (the pre-existing Diagnostics errors are unrelated and must not be touched).

- [ ] **Step 5: Commit any struct reconciliation**

```bash
git add -A
git commit -m "test(inventory): reconcile Phase 2 decode structs against live JSON" || echo "no changes"
```

---

## Self-review notes (for the executor)

- **Spec coverage:** Edit (T1/2/8/13), Move (T9/13), Deploy chooser + to-order wizard + external + part recovery (T11/12/13), return-external "Return to Stock" (T13 step 4), return-to-supplier (T10/13), resolve on banner (T13 step 5), delete guarded (T13/14), SKU-propagation warning + count (T8/13), status change intentionally OMITTED (spec §2), coalescing fix (T6), list invalidation (T6). All spec §3 gating rules encoded in T13 step 3 + T10 disable logic.
- **Type consistency:** `UpdateAssetRequest`/`AllocateRequest`/`AllocateResponse`/`EditAssetResponse`/`DeployExternalData` defined in T1/T2 and used identically in T5/T7/T8/T12. `Notification.Name.inventoryAssetDidChange` defined in T6, used in T7/T13/T14. `viewModel.isMutating`/`actionError`/`lastSkuUpdatedCount`/`didDelete`/`allocate(_:)->AllocateResponse?` defined in T7, used in T8–T14.
- **Known executor checks:** `Order`/`OrderItem` field names (`ticketNumber`, `status`, `description`/`name`, `id`) must be confirmed against `Core/Models/Order.swift` (T5/T12 notes). `APIClient.buildRequest` body-parameter mechanism must be confirmed (T4 step 3). The `.orders` request return shape must match `OrderListViewModel` (T5 note).
```
