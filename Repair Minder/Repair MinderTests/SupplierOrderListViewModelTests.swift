import XCTest
@testable import Repair_Minder

/// The cancel branch (empty -> delete, non-empty -> PATCH cancel) is already covered by
/// `BookInTests` (`testSupplierListStatusFilterAndCancel`, `testCancelDeletesEmptyOrder`,
/// `testCancelCancelsNonEmptyOrder`, `testCancelTreatsNilTotalReceivedAsEmpty`) — not
/// duplicated here. This file covers the remaining gap: `load()`'s decode/populate path and
/// the client-side status filter actually applying to a server-loaded list (the existing
/// coverage only exercised `filtered` against manually-assigned `vm.orders`).
@MainActor
final class SupplierOrderListViewModelTests: XCTestCase {
    final class ListSpy: InventoryServingStub {
        var lastSupplier: String?
        var orders = [
            SupplierOrder(id: "1", supplierName: "Acme", status: "pending"),
            SupplierOrder(id: "2", supplierName: "Beta", status: "received"),
            SupplierOrder(id: "3", supplierName: "Gamma", status: "cancelled"),
        ]
        override func listSupplierOrders(page: Int, limit: Int, supplier: String?, status: String?) async throws -> [SupplierOrder] {
            lastSupplier = supplier
            return orders
        }
    }

    func testLoadDecodesAndPopulatesOrders() async {
        let spy = ListSpy()
        let vm = SupplierOrderListViewModel(service: spy)

        await vm.load()

        XCTAssertEqual(vm.orders.map(\.id), ["1", "2", "3"])
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadForwardsNonEmptySearchAsSupplierFilter() async {
        let spy = ListSpy()
        let vm = SupplierOrderListViewModel(service: spy)
        vm.search = "acme"

        await vm.load()

        XCTAssertEqual(spy.lastSupplier, "acme")
    }

    func testEmptySearchForwardsNilSupplierFilter() async {
        let spy = ListSpy()
        let vm = SupplierOrderListViewModel(service: spy)

        await vm.load()

        XCTAssertNil(spy.lastSupplier)
    }

    /// Default `enabledStatuses` hides received/cancelled — a client-side filter applied
    /// over whatever `load()` actually populated from the server.
    func testStatusFilterAppliesToLoadedOrders() async {
        let spy = ListSpy()
        let vm = SupplierOrderListViewModel(service: spy)

        await vm.load()
        XCTAssertEqual(vm.filtered.map(\.id), ["1"])

        vm.toggleStatus("received")
        vm.toggleStatus("cancelled")
        XCTAssertEqual(Set(vm.filtered.map(\.id)), ["1", "2", "3"])

        vm.toggleStatus("pending")
        XCTAssertEqual(Set(vm.filtered.map(\.id)), ["2", "3"])
    }

    func testLoadSurfacesErrorOnFailure() async {
        final class FailingService: InventoryServingStub {
            struct E: Error {}
            override func listSupplierOrders(page: Int, limit: Int, supplier: String?, status: String?) async throws -> [SupplierOrder] {
                throw E()
            }
        }
        let vm = SupplierOrderListViewModel(service: FailingService())

        await vm.load()

        XCTAssertNotNil(vm.error)
        XCTAssertTrue(vm.orders.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }
}
