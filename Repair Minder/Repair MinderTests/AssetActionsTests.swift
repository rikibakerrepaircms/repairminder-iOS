import XCTest
@testable import Repair_Minder

final class AssetActionsTests: XCTestCase {
    private func asset(_ status: AssetStatus, supplier: String? = nil) -> Asset {
        var a = Asset(id: "1", assetTag: "T", name: "n", status: status)
        a.supplierName = supplier
        return a
    }

    func testCanDeployOnlyInStock() {
        XCTAssertTrue(AssetActions.canDeploy(asset(.inStock)))
        XCTAssertFalse(AssetActions.canDeploy(asset(.allocated)))
        XCTAssertFalse(AssetActions.canDeploy(asset(.deployed)))
    }

    func testCanDeleteUnlessAllocatedOrDeployed() {
        XCTAssertTrue(AssetActions.canDelete(asset(.inStock)))
        XCTAssertTrue(AssetActions.canDelete(asset(.returned)))
        XCTAssertFalse(AssetActions.canDelete(asset(.allocated)))
        XCTAssertFalse(AssetActions.canDelete(asset(.deployed)))
    }

    func testReturnToSupplierGatingAndReason() {
        // Enabled: eligible status + supplier + not pending.
        XCTAssertTrue(AssetActions.canReturnToSupplier(asset(.inStock, supplier: "Acme")))
        XCTAssertNil(AssetActions.returnToSupplierDisabledReason(asset(.deployed, supplier: "Acme")))
        // No supplier.
        XCTAssertFalse(AssetActions.canReturnToSupplier(asset(.inStock, supplier: nil)))
        XCTAssertEqual(AssetActions.returnToSupplierDisabledReason(asset(.inStock)), "No supplier assigned")
        // Already pending (priority over supplier/status).
        XCTAssertEqual(AssetActions.returnToSupplierDisabledReason(asset(.pendingReturn, supplier: "Acme")), "Return already in progress")
        // Ineligible status with a supplier.
        XCTAssertEqual(AssetActions.returnToSupplierDisabledReason(asset(.sold, supplier: "Acme")), "Cannot return asset with this status")
    }

    func testCanResolveOnlyPendingReturn() {
        XCTAssertTrue(AssetActions.canResolveReturn(asset(.pendingReturn)))
        XCTAssertFalse(AssetActions.canResolveReturn(asset(.returned)))
    }

    func testCanReturnToStockRequiresDeployedWithActiveDeployment() {
        XCTAssertTrue(AssetActions.canReturnToStock(asset(.deployed), hasActiveExternalDeployment: true))
        XCTAssertFalse(AssetActions.canReturnToStock(asset(.deployed), hasActiveExternalDeployment: false))
        XCTAssertFalse(AssetActions.canReturnToStock(asset(.inStock), hasActiveExternalDeployment: true))
    }
}
