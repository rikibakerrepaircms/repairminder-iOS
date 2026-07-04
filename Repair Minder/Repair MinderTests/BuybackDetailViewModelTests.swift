import XCTest
@testable import Repair_Minder

/// `BuybackDetailViewModel` doesn't go through `InventoryServing`/`APIClient` — it hits
/// `URLSession.shared` directly and reads the access token straight from `AuthManager.shared`
/// (backed by the real Keychain). We stub the network via `StubURLProtocol` and seed/clear a
/// real Keychain token per test (same pattern as `PasscodeColdLaunchLockTests`).
@MainActor
final class BuybackDetailViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        KeychainManager.shared.setAccessToken("test-access-token")
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        URLProtocol.unregisterClass(StubURLProtocol.self)
        KeychainManager.shared.clearStaffTokens()
        super.tearDown()
    }

    func testLoadDetailDecodesAndExposesBuyback() async {
        let json = #"""
        {"success":true,"data":{"id":"bb1","status":"purchased","brand":"Apple","model":"iPhone 13","purchase_amount":250.0}}
        """#
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let vm = BuybackDetailViewModel(buybackId: "bb1")

        await vm.loadDetail()

        XCTAssertEqual(vm.buyback?.id, "bb1")
        XCTAssertEqual(vm.buyback?.brand, "Apple")
        XCTAssertEqual(vm.buyback?.purchaseAmount, 250.0)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
    }

    /// State transition: `refresh()` re-hits the network and republishes whatever comes back
    /// (e.g. after a mutation elsewhere changed the buyback's status server-side).
    func testRefreshReloadsDetailFromServer() async {
        var callCount = 0
        let statuses = ["purchased", "for_sale"]
        StubURLProtocol.handler = { _ in
            defer { callCount += 1 }
            let json = #"{"success":true,"data":{"id":"bb1","status":"\#(statuses[min(callCount, statuses.count - 1)])"}}"#
            return (200, Data(json.utf8))
        }
        let vm = BuybackDetailViewModel(buybackId: "bb1")

        await vm.loadDetail()
        XCTAssertEqual(vm.buyback?.status, "purchased")

        await vm.refresh()
        XCTAssertEqual(vm.buyback?.status, "for_sale")
        XCTAssertEqual(callCount, 2)
    }

    /// Without a session token the VM must surface an error rather than crash or hang —
    /// `loadDetail()` throws `.userAuthenticationRequired` before ever touching the network.
    func testMissingAccessTokenSurfacesErrorWithoutNetworkCall() async {
        KeychainManager.shared.clearStaffTokens()
        var networkCalled = false
        StubURLProtocol.handler = { _ in networkCalled = true; return (200, Data("{}".utf8)) }

        let vm = BuybackDetailViewModel(buybackId: "bb1")
        await vm.loadDetail()

        XCTAssertNil(vm.buyback)
        XCTAssertNotNil(vm.error)
        XCTAssertFalse(networkCalled)
    }
}
