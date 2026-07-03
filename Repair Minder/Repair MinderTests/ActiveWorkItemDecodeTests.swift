import XCTest
@testable import Repair_Minder

final class ActiveWorkItemDecodeTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testDecodesWithNullOrderNumber() throws {
        let json = """
        [{"id":"d1","order_id":"o1","order_number":null,"status":"repairing",
          "display_name":"iPhone 15","work_type":"repair","started_at":"2026-07-01T09:00:00Z"}]
        """.data(using: .utf8)!
        let items = try decoder().decode([ActiveWorkItem].self, from: json)
        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items[0].orderNumber)
    }

    func testOrderNumberStringHandlesNil() throws {
        let json = """
        [{"id":"d1","status":"repairing","display_name":"iPhone","work_type":"repair","started_at":"x"}]
        """.data(using: .utf8)!
        let items = try decoder().decode([ActiveWorkItem].self, from: json)
        XCTAssertEqual(items[0].orderNumberString, "-")
    }
}
