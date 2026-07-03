import XCTest
@testable import Repair_Minder

@MainActor
final class InventoryWriteViewModelTests: XCTestCase {

    // MARK: - Coalescing (Phase-1 follow-up fix)

    /// Parks the FIRST fetch on a continuation so a load is genuinely in-flight when the
    /// second load request arrives — this deterministically exercises the coalescing path
    /// (a naive `guard !isLoading` would drop the second request under MainActor serialization).
    final class GatedService: InventoryServing {
        var queries: [AssetQuery] = []
        private var gate: CheckedContinuation<Void, Never>?
        private var fetchingSignal: CheckedContinuation<Void, Never>?
        private var firstStarted = false

        func waitUntilFetching() async {
            if firstStarted { return }
            await withCheckedContinuation { fetchingSignal = $0 }
        }
        func release() { gate?.resume(); gate = nil }

        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] {
            queries.append(filters)
            if !firstStarted {
                firstStarted = true
                fetchingSignal?.resume(); fetchingSignal = nil
                await withCheckedContinuation { gate = $0 }
            }
            return []
        }
        func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
        func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse { fatalError() }
        func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset { fatalError() }
        func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse { fatalError() }
        func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData { fatalError() }
        func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset { fatalError() }
        func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset { fatalError() }
        func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset { fatalError() }
        func deleteAsset(id: String) async throws {}
        func searchOrders(search: String) async throws -> [Order] { [] }
        func fetchOrderItems(orderId: String) async throws -> [OrderItem] { [] }
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
    final class MutatingService: InventoryServing {
        var deleted = false
        func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] { [] }
        func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
        func fetchAssetByTag(_ tag: String) async throws -> Asset { fatalError() }
        func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
        func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
        func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
        func fetchCategories() async throws -> [String] { [] }
        func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
        func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
        func fetchLocations() async throws -> [Location] { [] }
        func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
        func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse {
            EditAssetResponse(success: true, data: Asset(id: id, assetTag: "T", name: "Edited", status: .inStock), skuUpdatedCount: 2)
        }
        func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "Moved", status: .inStock) }
        func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
            AllocateResponse(success: true, data: Asset(id: id, assetTag: "T", name: "n", status: .allocated),
                             promptReadyToRepair: true, allocatedParts: nil, device: nil, recoveredAsset: nil)
        }
        func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData {
            DeployExternalData(asset: Asset(id: id, assetTag: "T", name: "n", status: .deployed),
                               deployment: ExternalDeploymentRecord(id: "dep1"))
        }
        func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
        func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .pendingReturn) }
        func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .returned) }
        func deleteAsset(id: String) async throws { deleted = true }
        func searchOrders(search: String) async throws -> [Order] { [] }
        func fetchOrderItems(orderId: String) async throws -> [OrderItem] { [] }
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
}
