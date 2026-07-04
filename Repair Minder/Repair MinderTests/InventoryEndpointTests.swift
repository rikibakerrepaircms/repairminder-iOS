import XCTest
@testable import Repair_Minder

/// The asset filter's product-type picker must hit the inventory-aware variant of
/// /api/product-types (is_active + limit=50, NO product_kind restriction) — assets
/// commonly reference `inventory_item`-kind product types via `product_type_id`,
/// which the shared `.productTypes(search:)` case (used by Booking/Orders) excludes
/// via its hardcoded `product_kind=product,service`.
final class InventoryEndpointTests: XCTestCase {

    func testAssetFilterProductTypesQueryItems() {
        let ep = APIEndpoint.assetFilterProductTypes(search: "screen")
        let items = Dictionary(uniqueKeysWithValues: (ep.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(items["search"], "screen")
        XCTAssertEqual(items["is_active"], "true")
        XCTAssertEqual(items["limit"], "50")
        XCTAssertNil(items["product_kind"])
    }

    func testAssetFilterProductTypesOmitsEmptySearch() {
        for ep in [APIEndpoint.assetFilterProductTypes(search: nil),
                   APIEndpoint.assetFilterProductTypes(search: "")] {
            let names = (ep.queryItems ?? []).map(\.name)
            XCTAssertFalse(names.contains("search"))
            XCTAssertTrue(names.contains("is_active"))
            XCTAssertTrue(names.contains("limit"))
        }
    }
}
