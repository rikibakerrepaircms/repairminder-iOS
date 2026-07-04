import XCTest
@testable import Repair_Minder

final class APIClientErrorTests: XCTestCase {
    func testNon2xxSurfacesServerErrorMessage() throws {
        let body = #"{"success":false,"error":"Asset is already a member of this group"}"#.data(using: .utf8)!
        let msg = APIClient.serverErrorMessage(from: body)
        XCTAssertEqual(msg, "Asset is already a member of this group")
    }

    func testNonJSONBodyReturnsNil() {
        XCTAssertNil(APIClient.serverErrorMessage(from: Data("not json".utf8)))
    }
}
