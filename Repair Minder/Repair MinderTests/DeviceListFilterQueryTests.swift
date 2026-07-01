import XCTest
@testable import Repair_Minder

/// Verifies the Devices list requests the SAME subset as the web /devices page:
/// hide collected/despatched/added_to_buyback by default, but never break the
/// scanner/search lookups (which must find devices of any status).
final class DeviceListFilterQueryTests: XCTestCase {

    private func value(_ items: [URLQueryItem], _ name: String) -> String? {
        items.first { $0.name == name }?.value
    }

    // Scanner + serial/IMEI search build a bare DeviceListFilter() — it must NOT
    // exclude any statuses, or looking up a collected/despatched device would fail.
    func testBareFilterDoesNotExcludeOrFilterStatus() {
        let items = DeviceListFilter().queryItems
        XCTAssertNil(value(items, "exclude_status"), "bare filter must not exclude statuses (scanner/search)")
        XCTAssertNil(value(items, "status"))
    }

    // When only excludeStatus is set, it is sent.
    func testExcludeStatusSentWhenNoStatusFilter() {
        var f = DeviceListFilter()
        f.excludeStatus = "collected,despatched,added_to_buyback"
        let items = f.queryItems
        XCTAssertEqual(value(items, "exclude_status"), "collected,despatched,added_to_buyback")
        XCTAssertNil(value(items, "status"))
    }

    // An explicit status filter must SUPPRESS exclude_status (mirrors the web:
    // exclude_status only applies when no status filter is active). Sending both
    // would be contradictory.
    func testExplicitStatusSuppressesExcludeStatus() {
        var f = DeviceListFilter()
        f.status = "diagnosing"
        f.excludeStatus = "collected,despatched,added_to_buyback"
        let items = f.queryItems
        XCTAssertEqual(value(items, "status"), "diagnosing")
        XCTAssertNil(value(items, "exclude_status"), "status filter must override the default exclusion")
    }

    // The default exclusion should not read as a user-applied "active filter".
    func testDefaultExclusionIsNotAnActiveFilter() {
        var f = DeviceListFilter()
        f.excludeStatus = DeviceListFilter.defaultExcludedStatuses
        XCTAssertFalse(f.hasActiveFilters, "default exclusion should not count as an active filter")
    }

    // The Devices list default must request buyback inventory, matching web /devices.
    func testDevicesListDefaultRequestsBuyback() {
        let items = DeviceListFilter.devicesListDefault.queryItems
        XCTAssertEqual(value(items, "include_buyback"), "true")
        XCTAssertEqual(value(items, "exclude_status"), "collected,despatched,added_to_buyback")
    }

    // Scanner/serial lookups must NOT pull in buyback stock.
    func testBareFilterDoesNotRequestBuyback() {
        XCTAssertNil(value(DeviceListFilter().queryItems, "include_buyback"))
    }
}

/// The Devices LIST screen must default to the web's DEFAULT_EXCLUDED_STATUSES.
@MainActor
final class DevicesListDefaultExclusionTests: XCTestCase {

    func testDevicesViewModelDefaultsToExcludingCompletedDevices() {
        let vm = DevicesViewModel()
        XCTAssertEqual(
            vm.filterState.excludeStatus,
            "collected,despatched,added_to_buyback",
            "Devices list must hide collected/despatched/added_to_buyback by default, matching web /devices"
        )
    }
}
