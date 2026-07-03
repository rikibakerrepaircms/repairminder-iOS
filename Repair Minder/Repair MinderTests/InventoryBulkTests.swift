import XCTest
@testable import Repair_Minder

final class InventoryBulkTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase
        return try JSONSerialization.jsonObject(with: try e.encode(value)) as! [String: Any]
    }

    // MARK: - Encoding

    func testBulkReturnRequestEncodesSnakeCase() throws {
        let req = BulkReturnToSupplierRequest(assetIds: ["a1", "a2"], supplierReturnReason: "defective", supplierReturnNotes: "cracked")
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["asset_ids"] as? [String], ["a1", "a2"])
        XCTAssertEqual(dict["supplier_return_reason"] as? String, "defective")
        XCTAssertEqual(dict["supplier_return_notes"] as? String, "cracked")
    }

    func testBulkReturnRequestOmitsNilNotes() throws {
        let req = BulkReturnToSupplierRequest(assetIds: ["a1"], supplierReturnReason: "other")
        let dict = try encodeToDict(req)
        XCTAssertNil(dict["supplier_return_notes"])
    }

    // MARK: - Decoding (shape verified against handleBulkReturnToSupplier; real body backfilled in E2E)

    func testBulkReturnResultDecodes() throws {
        let json = #"""
        {"batches":[
          {"supplier_name":"Mobasight","count":2,"assets":[
            {"id":"a1","asset_tag":"AST000000001","name":"Screen","status":"pending_return","supplier_name":"Mobasight"},
            {"id":"a2","asset_tag":"AST000000002","name":"Screen 2","status":"pending_return","supplier_name":"Mobasight"}
          ]}
        ],
        "total_returned":2,
        "errors":[{"asset_id":"a3","error":"No supplier assigned"}]}
        """#
        let r = try decode(BulkReturnToSupplierResult.self, json)
        XCTAssertEqual(r.totalReturned, 2)
        XCTAssertEqual(r.batches.count, 1)
        XCTAssertEqual(r.batches.first?.supplierName, "Mobasight")
        XCTAssertEqual(r.batches.first?.count, 2)
        XCTAssertEqual(r.batches.first?.assets.first?.assetTag, "AST000000001")
        XCTAssertEqual(r.errors.first?.assetId, "a3")
        XCTAssertEqual(r.errors.first?.error, "No supplier assigned")
    }

    // MARK: - BulkActions gating

    private func asset(_ id: String, status: AssetStatus, supplier: String?) -> Asset {
        var a = Asset(id: id, assetTag: id, name: id, status: status)
        a.supplierName = supplier
        return a
    }

    func testDeployableCountOnlyInStock() {
        let assets = [asset("1", status: .inStock, supplier: nil),
                      asset("2", status: .allocated, supplier: nil),
                      asset("3", status: .inStock, supplier: "S")]
        XCTAssertEqual(BulkActions.deployableCount(assets), 2)
    }

    func testReturnableAssetsRequireStatusAndSupplier() {
        let assets = [asset("1", status: .inStock, supplier: "S"),      // valid
                      asset("2", status: .allocated, supplier: "S"),    // valid
                      asset("3", status: .deployed, supplier: "S"),     // valid
                      asset("4", status: .inStock, supplier: nil),      // no supplier
                      asset("5", status: .sold, supplier: "S"),         // bad status
                      asset("6", status: .inStock, supplier: "")]       // empty supplier
        let valid = BulkActions.returnableAssets(assets)
        XCTAssertEqual(Set(valid.map(\.id)), ["1", "2", "3"])
        XCTAssertEqual(BulkActions.invalidReturnCount(assets), 3)
    }

    func testGroupBySupplier() {
        let assets = [asset("1", status: .inStock, supplier: "A"),
                      asset("2", status: .inStock, supplier: "B"),
                      asset("3", status: .inStock, supplier: "A")]
        let groups = BulkActions.groupedBySupplier(assets)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.first(where: { $0.supplier == "A" })?.assets.count, 2)
    }

    // MARK: - CSV export

    func testCSVStringHeaderAndEscaping() {
        var a = Asset(id: "1", assetTag: "AST1", name: "Screen, OLED", status: .inStock)
        a.category = "Screens"; a.serialNumber = "SN\"1"; a.sku = "SKU1"; a.conditionGrade = "A"; a.cost = 12.5
        a.locationName = "Bench"; a.subLocationCode = "B1"
        let csv = CSVExporter.csvString(for: [a])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(lines.first, "Asset Tag,Name,Status,Category,Location,Sub-Location,Serial Number,SKU,Condition,Cost")
        // comma-containing name is quoted; embedded quote is doubled
        XCTAssertTrue(lines[1].contains("\"Screen, OLED\""))
        XCTAssertTrue(lines[1].contains("\"SN\"\"1\""))
        XCTAssertTrue(lines[1].hasSuffix(",12.5"))
    }
}
