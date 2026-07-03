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
