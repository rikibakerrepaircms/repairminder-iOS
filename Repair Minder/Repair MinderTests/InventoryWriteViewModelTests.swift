import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryWriteViewModelTests: XCTestCase {

    // MARK: - Coalescing (Phase-1 follow-up fix)

    /// Parks the FIRST fetch on a continuation so a load is genuinely in-flight when the
    /// second load request arrives — this deterministically exercises the coalescing path
    /// (a naive `guard !isLoading` would drop the second request under MainActor serialization).
    final class GatedService: InventoryServingStub {
        var queries: [AssetQuery] = []
        private var gate: CheckedContinuation<Void, Never>?
        private var fetchingSignal: CheckedContinuation<Void, Never>?
        private var firstStarted = false

        func waitUntilFetching() async {
            if firstStarted { return }
            await withCheckedContinuation { fetchingSignal = $0 }
        }
        func release() { gate?.resume(); gate = nil }

        override func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            queries.append(filters)
            if !firstStarted {
                firstStarted = true
                fetchingSignal?.resume(); fetchingSignal = nil
                await withCheckedContinuation { gate = $0 }
            }
            return []
        }
    }

    func testFilterChangeDuringLoadIsCoalesced() async {
        let mock = GatedService()
        let vm = InventoryListViewModel(service: mock, pageSize: 24)
        vm.selectedStatus = .deployed
        let first = Task { await vm.loadAssets() }   // parks inside fetchAssets
        await mock.waitUntilFetching()               // first load now in-flight
        vm.selectedStatus = .damaged
        await vm.loadAssets()                          // sees isLoading → sets pendingReload, returns
        mock.release()                                 // first load completes → coalesced reload runs
        await first.value
        // The coalesced reload must have re-queried with the LATEST filter.
        XCTAssertEqual(mock.queries.map(\.status), ["deployed", "damaged"])
    }

    // MARK: - Detail view-model mutations

    /// Canned-result service for the detail mutation tests.
    ///
    /// `fetchAsset` mimics the real GET /api/assets/:id join by returning whatever the most
    /// recent mutation produced (`latest`), rather than a fixed value — this is what makes it
    /// a faithful stand-in for MF-7's re-fetch-after-mutation behaviour: the refetch is a
    /// join-ed superset of the SAME underlying row, not a different snapshot, so every
    /// existing assertion here still holds once `InventoryDetailViewModel` reconciles against it.
    final class MutatingService: InventoryServingStub {
        var deleted = false
        private var latest = Asset(id: "a1", assetTag: "T", name: "n", status: .inStock)

        override func fetchAsset(id: String) async throws -> Asset { latest }
        override func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse {
            latest = Asset(id: id, assetTag: "T", name: "Edited", status: .inStock)
            return EditAssetResponse(success: true, data: latest, skuUpdatedCount: 2)
        }
        override func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset {
            latest = Asset(id: id, assetTag: "T", name: "Moved", status: .inStock)
            return latest
        }
        override func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
            latest = Asset(id: id, assetTag: "T", name: "n", status: .allocated)
            return AllocateResponse(success: true, data: latest,
                             promptReadyToRepair: true, allocatedParts: nil, device: nil, recoveredAsset: nil)
        }
        override func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData {
            latest = Asset(id: id, assetTag: "T", name: "n", status: .deployed)
            return DeployExternalData(asset: latest, deployment: ExternalDeploymentRecord(id: "dep1"))
        }
        override func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset {
            latest = Asset(id: id, assetTag: "T", name: "n", status: .inStock)
            return latest
        }
        override func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset {
            latest = Asset(id: id, assetTag: "T", name: "n", status: .pendingReturn)
            return latest
        }
        override func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset {
            latest = Asset(id: id, assetTag: "T", name: "n", status: .returned)
            return latest
        }
        override func deleteAsset(id: String) async throws { deleted = true }
    }

    func testEditUpdatesAssetAndSurfacesSkuCount() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.edit(UpdateAssetRequest(name: "Edited"))
        XCTAssertEqual(vm.asset?.name, "Edited")
        XCTAssertEqual(vm.lastSkuUpdatedCount, 2)
        XCTAssertNil(vm.actionError)
    }

    func testAllocateSurfacesReadyToRepairPrompt() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        let resp = await vm.allocate(AllocateRequest(deploy: false))
        XCTAssertNotNil(resp)
        XCTAssertEqual(vm.asset?.status, .allocated)
        XCTAssertTrue(vm.readyToRepairPrompt)
    }

    func testDeleteSetsDidDelete() async {
        let mock = MutatingService()
        let vm = InventoryDetailViewModel(assetId: "a1", service: mock)
        await vm.load()
        await vm.delete()
        XCTAssertTrue(mock.deleted)
        XCTAssertTrue(vm.didDelete)
    }

    func testMoveUpdatesAsset() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.move(MoveAssetRequest(locationId: "loc"))
        XCTAssertEqual(vm.asset?.name, "Moved")
        XCTAssertNil(vm.actionError)
    }

    func testReturnToSupplierUpdatesStatus() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.returnToSupplier(ReturnToSupplierRequest(supplierReturnReason: "defective"))
        XCTAssertEqual(vm.asset?.status, .pendingReturn)
    }

    func testResolveReturnUpdatesStatus() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.resolveReturn(ResolveReturnRequest(resolution: "credit_received"))
        XCTAssertEqual(vm.asset?.status, .returned)
    }

    func testDeployExternalUpdatesStatus() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.deployExternal(DeployExternalRequest())
        XCTAssertEqual(vm.asset?.status, .deployed)
    }

    func testReturnToStockUpdatesStatus() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: MutatingService())
        await vm.load()
        await vm.returnToStock(ReturnExternalRequest(deploymentId: "dep1", returnToStock: true))
        XCTAssertEqual(vm.asset?.status, .inStock)
    }

    // MARK: - MF-7: re-fetch the joined asset after every mutation

    /// Mimics the real worker: mutation handlers (move/edit/allocate/return*/deploy-external)
    /// return a join-LESS `SELECT * FROM assets` row (no `location_name`/`product_type_name`),
    /// while the GET /api/assets/:id detail read returns the fully-joined row.
    final class JoinLessMutationService: InventoryServingStub {
        override func fetchAsset(id: String) async throws -> Asset {
            Asset(id: id, assetTag: "T", name: "n", status: .inStock,
                  productTypeName: "Screen", locationName: "Shelf B")
        }
        override func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset {
            // Join-less, as the real /move handler's `SELECT * FROM assets` returns.
            Asset(id: id, assetTag: "T", name: "n", status: .inStock)
        }
    }

    func testMutationRefetchesJoinedAsset() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: JoinLessMutationService())
        await vm.load()
        await vm.move(MoveAssetRequest(locationId: "loc1"))
        XCTAssertEqual(vm.asset?.locationName, "Shelf B")
        XCTAssertEqual(vm.asset?.productTypeName, "Screen")
    }

    /// If the re-fetch fails, the VM must degrade gracefully and keep the optimistic
    /// mutation result rather than blanking the screen.
    final class RefetchFailingService: InventoryServingStub {
        struct RefetchError: Error {}
        override func fetchAsset(id: String) async throws -> Asset {
            throw RefetchError()
        }
        override func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset {
            Asset(id: id, assetTag: "T", name: "Moved", status: .inStock)
        }
    }

    func testMutationKeepsOptimisticResultWhenRefetchFails() async {
        let vm = InventoryDetailViewModel(assetId: "a1", service: RefetchFailingService())
        // Skip vm.load() — its fetchAsset would also throw, leaving asset nil, which isn't
        // what we're testing here. Directly exercise the mutation's own degrade path.
        await vm.move(MoveAssetRequest(locationId: "loc1"))
        XCTAssertEqual(vm.asset?.name, "Moved")
        XCTAssertNil(vm.actionError)
    }
}
