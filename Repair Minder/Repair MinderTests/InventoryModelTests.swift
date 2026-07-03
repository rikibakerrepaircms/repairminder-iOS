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
}
