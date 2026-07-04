import XCTest
@testable import Repair_Minder

final class ScannerParseTests: XCTestCase {
    func testParseAssetScanUrl() {
        // Full URL from a printed QR label: /scan/asset/<TAG>
        XCTAssertEqual(AssetScan.parse("https://app.repairminder.com/scan/asset/AST000000001"), "AST000000001")
        // Partial path form
        XCTAssertEqual(AssetScan.parse("/scan/asset/AST000000002"), "AST000000002")
        // Query string params (context/id) after the tag must not leak into the result
        XCTAssertEqual(AssetScan.parse("https://app.repairminder.com/scan/asset/AST000000009?context=order&id=123"), "AST000000009")
        // Direct tag from a CODE128 barcode scan
        XCTAssertEqual(AssetScan.parse("AST000000003"), "AST000000003")
        // Trims whitespace
        XCTAssertEqual(AssetScan.parse("  AST000000007  "), "AST000000007")
        // Normalizes to uppercase, matching web's parseAssetScanUrl
        XCTAssertEqual(AssetScan.parse("ast000000001"), "AST000000001")
        // Unrecognized formats fall back to the trimmed raw string
        XCTAssertEqual(AssetScan.parse("  not-a-valid-code  "), "not-a-valid-code")
    }
}
