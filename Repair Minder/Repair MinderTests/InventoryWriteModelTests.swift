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

    func testResolveWithReplacementAssetEncodes() throws {
        let r = ResolveReturnRequest(resolution: "replacement_received", replacementAssetId: "rep1", notes: nil)
        let obj = try encodeToObject(r)
        XCTAssertEqual(obj["resolution"] as? String, "replacement_received")
        XCTAssertEqual(obj["replacement_asset_id"] as? String, "rep1")
    }

    func testUpdateAssetSendsEmptyConditionGradeToClear() throws {
        // Choosing "Not set" must send condition_grade:"" (present), not omit it, so the
        // grade is actually cleared server-side (web parity).
        let obj = try encodeToObject(UpdateAssetRequest(conditionGrade: ""))
        XCTAssertTrue(obj.keys.contains("condition_grade"))
        XCTAssertEqual(obj["condition_grade"] as? String, "")
    }
}

/// Type-erasing wrapper so we can encode an `Encodable` existential in tests.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

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
