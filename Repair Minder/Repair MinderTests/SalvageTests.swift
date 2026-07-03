import XCTest
@testable import Repair_Minder

final class SalvageTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase
        return try JSONSerialization.jsonObject(with: try e.encode(value)) as! [String: Any]
    }

    // MARK: - Encoding

    func testSalvageItemRequestEncodesAndOmitsScreenFieldsWhenNil() throws {
        let req = SalvageItemRequest(productTypeId: "g1", conditionGrade: "A", locationId: "l1", value: 5.0)
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["product_type_id"] as? String, "g1")
        XCTAssertEqual(dict["condition_grade"] as? String, "A")
        XCTAssertEqual(dict["location_id"] as? String, "l1")
        XCTAssertEqual(dict["value"] as? Double, 5.0)
        XCTAssertNil(dict["lcd_working"])
        XCTAssertNil(dict["glass_cracked"])
    }

    func testSalvageItemRequestEncodesScreenFields() throws {
        let req = SalvageItemRequest(productTypeId: "g1", conditionGrade: "B", locationId: "l1", lcdWorking: 1, glassCracked: 0)
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["lcd_working"] as? Int, 1)
        XCTAssertEqual(dict["glass_cracked"] as? Int, 0)
    }

    // MARK: - Decoding (shape from buyback_salvage_handlers.js; real body confirmed in E2E)

    func testSalvageResponseDecodes() throws {
        let json = #"""
        {"assets":[{"id":"a1","asset_tag":"AST100","name":"Screen","status":"in_stock","source_type":"salvaged","recovered_from_buyback_id":"b1","lcd_working":1,"glass_cracked":0}],
         "salvaged_assets":[{"id":"a1","asset_tag":"AST100","name":"Screen","condition_grade":"A","cost":5.0,"location_id":"l1","lcd_working":1,"glass_cracked":0,"created_at":"2026-07-03T00:00:00Z","location_name":"Bench"}],
         "new_status":"salvaged",
         "salvage_budget":{"cap":100.0,"booked":5.0,"remaining":95.0}}
        """#
        let resp = try decode(SalvageResponse.self, json)
        XCTAssertEqual(resp.assets.first?.sourceType, "salvaged")
        XCTAssertEqual(resp.assets.first?.lcdWorking, 1)
        XCTAssertEqual(resp.salvagedAssets.first?.cost, 5.0)
        XCTAssertEqual(resp.newStatus, "salvaged")
        XCTAssertEqual(resp.salvageBudget.remaining, 95.0)
    }

    func testDeleteSalvageResultDecodes() throws {
        let json = #"{"salvaged_assets":[],"booked":0,"reverted_to":"refurbishing"}"#
        let r = try decode(DeleteSalvageResult.self, json)
        XCTAssertTrue(r.salvagedAssets.isEmpty)
        XCTAssertEqual(r.revertedTo, "refurbishing")
    }

    // MARK: - SalvageBudget helper

    func testBudgetOverCapAndRemaining() {
        XCTAssertEqual(SalvageBudgetMath.remaining(cap: 100, booked: 30, pending: 20), 50)
        XCTAssertFalse(SalvageBudgetMath.overCap(cap: 100, booked: 30, pending: 70))   // exactly at cap
        XCTAssertTrue(SalvageBudgetMath.overCap(cap: 100, booked: 30, pending: 71))
    }

    func testScreenDetectionAndCanAdd() {
        XCTAssertTrue(SalvageBudgetMath.isScreen(category: "iPhone Screen"))
        XCTAssertFalse(SalvageBudgetMath.isScreen(category: "Battery"))
        // non-screen: group + location enough
        XCTAssertTrue(SalvageBudgetMath.canAdd(groupId: "g", locationId: "l", isScreen: false, lcd: nil, glass: nil))
        // screen: needs lcd + glass
        XCTAssertFalse(SalvageBudgetMath.canAdd(groupId: "g", locationId: "l", isScreen: true, lcd: 1, glass: nil))
        XCTAssertTrue(SalvageBudgetMath.canAdd(groupId: "g", locationId: "l", isScreen: true, lcd: 1, glass: 0))
        // missing location
        XCTAssertFalse(SalvageBudgetMath.canAdd(groupId: "g", locationId: nil, isScreen: false, lcd: nil, glass: nil))
    }

    // MARK: - SalvageViewModel

    @MainActor
    final class SalvageSpy: InventoryServingStub {
        var salvagedItems: [SalvageItemRequest]?
        var deletedAssetId: String?
        override func salvageBuyback(id: String, items: [SalvageItemRequest]) async throws -> SalvageResponse {
            salvagedItems = items
            let summaries = items.enumerated().map { i, it in
                SalvagedAssetSummary(id: "new\(i)", assetTag: "T\(i)", name: "n", conditionGrade: it.conditionGrade,
                                     cost: it.value, locationId: it.locationId, lcdWorking: it.lcdWorking,
                                     glassCracked: it.glassCracked, createdAt: nil, locationName: nil)
            }
            return SalvageResponse(assets: [], salvagedAssets: summaries, newStatus: "salvaged",
                                   salvageBudget: SalvageBudgetInfo(cap: 100, booked: 0, remaining: 100))
        }
        override func deleteSalvageItem(buybackId: String, assetId: String) async throws -> DeleteSalvageResult {
            deletedAssetId = assetId
            return DeleteSalvageResult(salvagedAssets: [], booked: 0, revertedTo: "refurbishing")
        }
    }

    @MainActor
    func testAddToBatchAndBook() async {
        let spy = SalvageSpy()
        let vm = SalvageViewModel(buybackId: "b1", purchaseAmount: 100, salvaged: [], service: spy)
        vm.selectedGroup = AssetGroupListItem(id: "g1", name: "Battery")   // non-screen
        vm.locationId = "l1"; vm.value = "10"
        XCTAssertTrue(vm.canAdd)
        vm.addToBatch()
        XCTAssertEqual(vm.staged.count, 1)
        XCTAssertNil(vm.selectedGroup)             // form reset
        XCTAssertEqual(vm.pending, 10)
        XCTAssertTrue(vm.needsConfirmation)         // no salvage yet
        let ok = await vm.book()
        XCTAssertTrue(ok)
        XCTAssertEqual(spy.salvagedItems?.first?.productTypeId, "g1")
        XCTAssertEqual(vm.salvaged.count, 1)
        XCTAssertTrue(vm.staged.isEmpty)
    }

    @MainActor
    func testScreenGroupRequiresLcdGlassBeforeAdd() {
        let vm = SalvageViewModel(buybackId: "b1", purchaseAmount: 100, salvaged: [], service: SalvageSpy())
        vm.selectedGroup = AssetGroupListItem(id: "g1", name: "Screen", category: "iPhone Screen")
        vm.locationId = "l1"
        XCTAssertTrue(vm.isScreen)
        XCTAssertFalse(vm.canAdd)          // lcd/glass missing
        vm.lcdWorking = 1; vm.glassCracked = 0
        XCTAssertTrue(vm.canAdd)
    }

    @MainActor
    func testBookBlockedWhenOverCap() async {
        let vm = SalvageViewModel(buybackId: "b1", purchaseAmount: 10, salvaged: [], service: SalvageSpy())
        vm.selectedGroup = AssetGroupListItem(id: "g1", name: "Battery")
        vm.locationId = "l1"; vm.value = "50"
        vm.addToBatch()
        XCTAssertTrue(vm.overCap)
        XCTAssertFalse(vm.canBook)
        let ok = await vm.book()
        XCTAssertFalse(ok)
    }

    @MainActor
    func testRemoveSalvagedCallsDelete() async {
        let spy = SalvageSpy()
        let existing = SalvagedAssetSummary(id: "a9", assetTag: "T9", name: "n", conditionGrade: "A", cost: 5,
                                            locationId: "l", lcdWorking: nil, glassCracked: nil, createdAt: nil, locationName: nil)
        let vm = SalvageViewModel(buybackId: "b1", purchaseAmount: 100, salvaged: [existing], service: spy)
        XCTAssertFalse(vm.needsConfirmation)   // already has salvage
        await vm.removeSalvaged("a9")
        XCTAssertEqual(spy.deletedAssetId, "a9")
        XCTAssertTrue(vm.salvaged.isEmpty)
    }
}
