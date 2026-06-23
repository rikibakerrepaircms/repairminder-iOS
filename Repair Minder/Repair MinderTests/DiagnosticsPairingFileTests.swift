import XCTest
@testable import Repair_Minder

final class DiagnosticsPairingFileTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pairing-\(UUID().uuidString).json")
    }
    override func tearDown() { DiagnosticsShopPairing.unpair(); super.tearDown() }

    func test_consumesValidFile_pairsAndDeletes() throws {
        let u = tempURL()
        try #"{"token":"abc123def","shop_name":"Acme Repairs"}"#.data(using: .utf8)!.write(to: u)
        XCTAssertTrue(DiagnosticsPairingFile.consumeIfPresent(u))
        XCTAssertEqual(DiagnosticsShopPairing.token, "abc123def")
        XCTAssertEqual(DiagnosticsShopPairing.companyName, "Acme Repairs")
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.path))
    }
    func test_absentFile_isNoop() {
        XCTAssertFalse(DiagnosticsPairingFile.consumeIfPresent(tempURL()))
        XCTAssertFalse(DiagnosticsShopPairing.isPaired)
    }
    func test_malformedFile_ignoredAndDeleted() throws {
        let u = tempURL()
        try "not json".data(using: .utf8)!.write(to: u)
        XCTAssertFalse(DiagnosticsPairingFile.consumeIfPresent(u))
        XCTAssertFalse(DiagnosticsShopPairing.isPaired)
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.path))
    }
}
