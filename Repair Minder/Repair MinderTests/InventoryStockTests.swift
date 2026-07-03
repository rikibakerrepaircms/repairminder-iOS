import XCTest
@testable import Repair_Minder

/// Decode tests use REAL captured JSON from prod (admin company 4b63c1e6…),
/// captured 2026-07-03 via GET /api/assets/{stock-summary,hierarchy,low-stock}.
final class InventoryStockTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    func testStockSummaryItemDecodesWithChildren() throws {
        let json = #"""
        {"product_type_id":"db06e94f-8daa-48e5-9add-c9b4603c6e27","name":"Test Asset 1 UPDATED AGAIN",
         "sku":"TEST-SKU-001","parent_id":null,"in_stock_count":0,"allocated_count":1,"total_count":2,
         "reorder_level":5,"is_low_stock":true,"aggregate_in_stock":1,"aggregate_allocated":2,
         "children":[{"product_type_id":"69970515-d73a-4ff0-847e-2bc670cb288d","name":"Child Product OEM Variant",
           "sku":"CHILD-TEST-001","parent_id":"db06e94f-8daa-48e5-9add-c9b4603c6e27","in_stock_count":1,
           "allocated_count":1,"total_count":2,"reorder_level":0,"is_low_stock":false}]}
        """#
        let item = try decode(StockSummaryItem.self, json)
        XCTAssertEqual(item.aggregateInStock, 1)
        XCTAssertEqual(item.aggregateAllocated, 2)
        XCTAssertTrue(item.isLowStock)           // true JSON boolean
        XCTAssertTrue(item.isOutOfStock)         // in_stock 0, reorder 5
        XCTAssertEqual(item.children?.count, 1)
        let child = item.children!.first!
        XCTAssertNil(child.aggregateInStock)     // children omit aggregates
        XCTAssertNil(child.children)             // children omit `children`
        XCTAssertFalse(child.isLowStock)
        XCTAssertEqual(child.displayInStock, 1)  // falls back to own count
    }

    func testHierarchyDecodes() throws {
        let json = #"""
        {"grouped":[{"product_type":{"id":"db06e94f","name":"Test Asset 1 UPDATED AGAIN","parent_id":null},
          "assets":[{"id":"19db5048","asset_tag":"AST000000007","name":"Test Asset 1","status":"returned","location_name":"mendmyi"},
                    {"id":"ff8ae01d","asset_tag":"TEST-TRACK-001","name":"Test Asset Tracking","status":"allocated","location_name":null}],
          "children":[{"product_type":{"id":"69970515","name":"Child Product OEM Variant","parent_id":"db06e94f"},
            "assets":[{"id":"1bde2ded","asset_tag":"AST000000019","name":"Test Child Asset","status":"allocated","location_name":null},
                      {"id":"333bd106","asset_tag":"AST000000020","name":"Test Child Asset (Recovered)","status":"in_stock","location_name":"Renamed Stage3 Location"}]}]}],
         "unlinked":[{"id":"6a0af456","asset_tag":"AST000000009","name":"Samsung LCD","status":"deployed","location_name":"mendmyi"}]}
        """#
        let resp = try decode(AssetHierarchyResponse.self, json)
        XCTAssertEqual(resp.grouped.count, 1)
        let group = resp.grouped[0]
        XCTAssertEqual(group.productType.name, "Test Asset 1 UPDATED AGAIN")
        XCTAssertEqual(group.assets.first?.assetTag, "AST000000007")
        XCTAssertEqual(group.assets.first?.status, .returned)
        XCTAssertEqual(group.children?.count, 1)
        XCTAssertNil(group.children?.first?.children)  // nested child groups omit `children`
        XCTAssertEqual(group.totalAssetCount, 4)        // 2 own + 2 child
        XCTAssertEqual(resp.unlinked.first?.status, .deployed)
    }

    // MARK: - StockViewModel sort (pure)

    private func summaryItem(_ id: String, name: String, inStock: Int, reorder: Int) -> StockSummaryItem {
        StockSummaryItem(productTypeId: id, name: name, sku: nil, parentId: nil,
                         inStockCount: inStock, allocatedCount: 0, totalCount: inStock, reorderLevel: reorder,
                         isLowStock: false, aggregateInStock: inStock, aggregateAllocated: 0, children: nil)
    }

    func testStockSortByInStockDescending() {
        let items = [summaryItem("a", name: "Alpha", inStock: 5, reorder: 1),
                     summaryItem("b", name: "Bravo", inStock: 2, reorder: 3),
                     summaryItem("c", name: "Charlie", inStock: 9, reorder: 2)]
        let asc = StockViewModel.sort(items, by: .inStock, ascending: true).map(\.productTypeId)
        XCTAssertEqual(asc, ["b", "a", "c"])
        let desc = StockViewModel.sort(items, by: .inStock, ascending: false).map(\.productTypeId)
        XCTAssertEqual(desc, ["c", "a", "b"])
        let byReorder = StockViewModel.sort(items, by: .reorder, ascending: true).map(\.productTypeId)
        XCTAssertEqual(byReorder, ["a", "c", "b"])
    }

    @MainActor
    func testStockViewModelSetSortTogglesDirection() {
        let vm = StockViewModel(service: InventoryServingStub())
        vm.setSort(.inStock)
        XCTAssertEqual(vm.sortField, .inStock)
        XCTAssertTrue(vm.sortAscending)
        vm.setSort(.inStock)          // same field toggles
        XCTAssertFalse(vm.sortAscending)
        vm.setSort(.total)            // new field resets to ascending
        XCTAssertTrue(vm.sortAscending)
    }

    func testLowStockDecodes() throws {
        let json = #"""
        {"alerts":{"parts":[{"product_type_id":"88a3f6bd","name":"Import Test Product 1","sku":"IMPORT-TEST-001",
            "category":"Camera","product_category":"parts","in_stock_count":0,"reorder_level":5,"deficit":5,
            "preferred_supplier":"Tech Supplier","parent_name":null,"is_child_service":false,"parent_id":null}],
          "masters":[{"product_type_id":"db06e94f","name":"Test Asset 1 UPDATED AGAIN","sku":"TEST-SKU-001",
            "category":"Screen","product_category":"masters","in_stock_count":1,"reorder_level":5,"deficit":4,
            "preferred_supplier":"MMI Refurb","parent_name":null,"is_child_service":false,"parent_id":null}],
          "services":[]},
         "all":[{"product_type_id":"88a3f6bd","name":"Import Test Product 1","sku":"IMPORT-TEST-001","category":"Camera",
           "product_category":"parts","in_stock_count":0,"reorder_level":5,"deficit":5,"preferred_supplier":"Tech Supplier",
           "parent_name":null,"is_child_service":false,"parent_id":null}],
         "summary":{"total":3,"by_category":{"parts":2,"masters":1,"services":0}}}
        """#
        let resp = try decode(LowStockResponse.self, json)
        XCTAssertEqual(resp.summary.total, 3)
        XCTAssertEqual(resp.summary.byCategory.parts, 2)
        XCTAssertEqual(resp.alerts.parts.count, 1)
        XCTAssertTrue(resp.alerts.services.isEmpty)
        let alert = resp.all.first!
        XCTAssertEqual(alert.deficit, 5)
        XCTAssertFalse(alert.isChildService)   // true JSON boolean
        XCTAssertTrue(alert.isCritical)        // in_stock 0
        XCTAssertEqual(alert.productCategory, "parts")
    }
}
