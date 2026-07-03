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
        XCTAssertNil(g.avgCost)
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
        XCTAssertNil(dict["sell_price_inc_vat"])
    }

    func testGroupFormRequestEncodesInventoryKindAndCategory() throws {
        let dict = try encodeToDict(GroupFormRequest(name: "Batteries", category: "General"))
        XCTAssertEqual(dict["name"] as? String, "Batteries")
        XCTAssertEqual(dict["category"] as? String, "General")
        XCTAssertEqual(dict["product_kind"] as? String, "inventory_item")
    }
}
