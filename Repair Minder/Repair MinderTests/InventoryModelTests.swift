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

    func testCategoriesResponseDecodes() throws {
        let json = #"{"categories":[{"category":"Screens","count":5},{"category":"Batteries","count":2}],"suggested":["X"]}"#
        let r = try decode(CategoriesResponse.self, json)
        XCTAssertEqual(r.categories.map(\.category), ["Screens", "Batteries"])
        XCTAssertEqual(r.categories.first?.count, 5)
    }
    func testAssetActivityDecodesRealColumns() throws {
        let json = #"{"id":"al1","asset_id":"a1","activity_type":"moved","performed_by_email":"e@x.com","performed_at":"2026-01-01"}"#
        let a = try decode(AssetActivity.self, json)
        XCTAssertEqual(a.activityType, "moved")
        XCTAssertEqual(a.performedByEmail, "e@x.com")
        XCTAssertEqual(a.performedAt, "2026-01-01")
    }

    // Regression: an allocated asset returns checked_out_order_number as an Int
    // (the linked order's ticket_number). It was previously typed String? which
    // failed to decode any real list containing an allocated/deployed asset.
    func testAllocatedAssetDecodesIntOrderNumber() throws {
        let json = #"""
        {"id":"a1","asset_tag":"AST1","name":"Screen","status":"allocated",
         "checked_out_to_order_id":"o1","checked_out_order_number":100000021}
        """#
        let a = try decode(Asset.self, json)
        XCTAssertEqual(a.status, .allocated)
        XCTAssertEqual(a.checkedOutOrderNumber, 100000021)
    }

    // MF-5 regression: a single row with `status: null` must not throw and
    // must not blank the entire [Asset] list decode.
    func testAssetStatusNullDecodesToUnknownAndListSurvives() throws {
        let json = #"""
        [{"id":"a1","asset_tag":"AST-1","name":"Part","status":null},
         {"id":"a2","asset_tag":"AST-2","name":"Part2","status":"in_stock"}]
        """#
        let assets = try decode([Asset].self, json)
        XCTAssertEqual(assets.count, 2)
        XCTAssertEqual(assets[0].status, .unknown)
        XCTAssertEqual(assets[1].status, .inStock)
    }

    // MF-5 completion: the spec was "null OR ABSENT". An asset object with the
    // `status` key missing entirely (not just null) must also fall back to
    // `.unknown` rather than throwing keyNotFound and blanking the whole list.
    func testAssetAbsentStatusKeyDecodesToUnknown() throws {
        let json = #"[{"id":"a1","asset_tag":"AST-1","name":"Part"}]"#
        let assets = try decode([Asset].self, json)
        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets[0].status, .unknown)
    }

    // Guards the @DefaultUnknown-wrapped `status` property against drift: a full,
    // realistic asset payload (as the SELECT a.* handlers return) must still decode
    // every field correctly now that `status` is a property-wrapper-backed var.
    func testAssetFullJSONDecodesAllFields() throws {
        let json = #"""
        {
          "id": "a1", "asset_tag": "AST000000001", "name": "iPhone 13 Screen",
          "status": "allocated", "company_id": "c1", "product_type_id": "pt1",
          "serial_number": "SN123", "sku": "SKU-1", "category": "Screens",
          "manufacturer": "Apple", "model_number": "A2482",
          "cost": 42.5, "cost_inc_vat": 51.0, "is_oem": 1, "is_refurbished": 0,
          "warranty_months": 12, "location_id": "loc1", "location_name": "Main Store",
          "sub_location_id": "sub1", "sub_location_code": "A1",
          "checked_out_to_order_id": "o1", "checked_out_order_number": 100000021,
          "product_type_name": "Screens", "product_type_category": "parts",
          "group_names": "Screens, Genuine", "group_ids": "g1,g2",
          "notes": "handle with care", "created_at": "2026-01-01", "updated_at": "2026-01-02"
        }
        """#
        let a = try decode(Asset.self, json)
        XCTAssertEqual(a.id, "a1")
        XCTAssertEqual(a.assetTag, "AST000000001")
        XCTAssertEqual(a.name, "iPhone 13 Screen")
        XCTAssertEqual(a.status, .allocated)
        XCTAssertEqual(a.companyId, "c1")
        XCTAssertEqual(a.productTypeId, "pt1")
        XCTAssertEqual(a.serialNumber, "SN123")
        XCTAssertEqual(a.sku, "SKU-1")
        XCTAssertEqual(a.category, "Screens")
        XCTAssertEqual(a.manufacturer, "Apple")
        XCTAssertEqual(a.modelNumber, "A2482")
        XCTAssertEqual(a.cost, 42.5)
        XCTAssertEqual(a.costIncVat, 51.0)
        XCTAssertTrue(a.isOemBool)
        XCTAssertFalse(a.isRefurbishedBool)
        XCTAssertEqual(a.warrantyMonths, 12)
        XCTAssertEqual(a.locationId, "loc1")
        XCTAssertEqual(a.locationName, "Main Store")
        XCTAssertEqual(a.subLocationId, "sub1")
        XCTAssertEqual(a.subLocationCode, "A1")
        XCTAssertEqual(a.checkedOutToOrderId, "o1")
        XCTAssertEqual(a.checkedOutOrderNumber, 100000021)
        XCTAssertEqual(a.productTypeName, "Screens")
        XCTAssertEqual(a.productTypeCategory, "parts")
        XCTAssertEqual(a.groupNamesList, ["Screens", "Genuine"])
        XCTAssertEqual(a.groupIdsList, ["g1", "g2"])
        XCTAssertEqual(a.notes, "handle with care")
        XCTAssertEqual(a.createdAt, "2026-01-01")
        XCTAssertEqual(a.updatedAt, "2026-01-02")
    }
}
