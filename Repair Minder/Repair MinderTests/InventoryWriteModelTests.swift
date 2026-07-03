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
}

/// Type-erasing wrapper so we can encode an `Encodable` existential in tests.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
