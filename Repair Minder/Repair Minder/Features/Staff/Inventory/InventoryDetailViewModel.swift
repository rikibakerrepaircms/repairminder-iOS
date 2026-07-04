import Foundation

@MainActor
final class InventoryDetailViewModel: ObservableObject {
    @Published private(set) var asset: Asset?
    @Published private(set) var activity: [AssetActivity] = []
    @Published private(set) var groups: [AssetGroupSummary] = []
    @Published private(set) var externalDeployment: ExternalDeployment?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // Mutation state (Phase 2)
    @Published var actionError: String?
    @Published var lastSkuUpdatedCount: Int?
    @Published var readyToRepairPrompt = false
    @Published private(set) var didDelete = false
    @Published private(set) var isMutating = false
    @Published var groupActionMessage: String?

    let assetId: String
    private let service: InventoryServing
    // InventoryService.init is @MainActor-isolated — use optional + nil-coalesce (not a default arg value).
    init(assetId: String, service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
        self.assetId = assetId
    }

    func load() async {
        isLoading = true; error = nil
        do {
            asset = try await service.fetchAsset(id: assetId)
        } catch {
            self.error = error.localizedDescription
        }
        // Sub-resources load in parallel and degrade silently on failure.
        async let act = try? service.fetchActivity(id: assetId)
        async let grp = try? service.fetchAssetGroups(id: assetId)
        async let ext = try? service.fetchExternalDeployment(id: assetId)
        activity = await act ?? []
        groups = await grp ?? []
        externalDeployment = await ext
        isLoading = false
    }

    func refresh() async { await load() }

    // MARK: - Mutations (Phase 2)

    /// Reconciles a mutation with the fully joined GET /api/assets/:id row. The mutation
    /// handlers (move/edit/allocate/return*/deploy-external) return a join-less
    /// `SELECT * FROM assets` row — no `location_name`, `product_type_name`,
    /// `checked_out_order_number`, `checked_out_device_name`, `enable_part_recovery` — so
    /// publishing that row would blank those fields on screen (the exact MF-7 symptom).
    /// We publish the joined value once on success: during the await the UI keeps showing the
    /// prior asset (no blank-joined-fields flicker), then updates to the joined row. Only if
    /// the re-fetch fails do we fall back to the optimistic join-less `updated` row rather
    /// than blanking the screen. Posts `.inventoryAssetDidChange` exactly once.
    private func applyUpdated(_ updated: Asset) async {
        if let joined = try? await service.fetchAsset(id: assetId) {
            asset = joined
        } else {
            asset = updated
        }
        NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
    }

    private func refreshSubResources() async {
        async let act = try? service.fetchActivity(id: assetId)
        async let ext = try? service.fetchExternalDeployment(id: assetId)
        activity = await act ?? []
        externalDeployment = await ext
    }

    func edit(_ body: UpdateAssetRequest) async {
        isMutating = true; actionError = nil
        do {
            let resp = try await service.updateAsset(id: assetId, body: body)
            await applyUpdated(resp.data)
            lastSkuUpdatedCount = (resp.skuUpdatedCount ?? 0) > 0 ? resp.skuUpdatedCount : nil
            await refreshSubResources()
        } catch { actionError = error.localizedDescription }
        isMutating = false
    }

    func move(_ body: MoveAssetRequest) async {
        await run { try await self.service.moveAsset(id: self.assetId, body: body) }
    }
    func returnToStock(_ body: ReturnExternalRequest) async {
        await run { try await self.service.returnExternal(id: self.assetId, body: body) }
    }
    func returnToSupplier(_ body: ReturnToSupplierRequest) async {
        await run { try await self.service.returnToSupplier(id: self.assetId, body: body) }
    }
    func resolveReturn(_ body: ResolveReturnRequest) async {
        await run { try await self.service.resolveSupplierReturn(id: self.assetId, body: body) }
    }

    /// Returns the full allocate response so the wizard can show recovered-part info.
    @discardableResult
    func allocate(_ body: AllocateRequest) async -> AllocateResponse? {
        isMutating = true; actionError = nil
        defer { isMutating = false }
        do {
            let resp = try await service.allocateAsset(id: assetId, body: body)
            await applyUpdated(resp.data)
            readyToRepairPrompt = resp.promptReadyToRepair ?? false
            await refreshSubResources()
            return resp
        } catch { actionError = error.localizedDescription; return nil }
    }

    func deployExternal(_ body: DeployExternalRequest) async {
        isMutating = true; actionError = nil
        do {
            let data = try await service.deployExternal(id: assetId, body: body)
            await applyUpdated(data.asset)
            await refreshSubResources()
        } catch { actionError = error.localizedDescription }
        isMutating = false
    }

    func delete() async {
        isMutating = true; actionError = nil
        do {
            try await service.deleteAsset(id: assetId)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            didDelete = true
        } catch { actionError = error.localizedDescription }
        isMutating = false
    }

    /// Shared helper for mutations that just return an updated `Asset`.
    private func run(_ op: @escaping () async throws -> Asset) async {
        isMutating = true; actionError = nil
        do { await applyUpdated(try await op()); await refreshSubResources() }
        catch { actionError = error.localizedDescription }
        isMutating = false
    }

    // MARK: - Groups (Phase 3)

    @discardableResult
    func manageGroups(groupIds: [String]) async -> Bool {
        isMutating = true; actionError = nil; defer { isMutating = false }
        do {
            let result = try await service.bulkAssignGroups(assetId: assetId, groupIds: groupIds)
            groupActionMessage = Self.siblingMessage(result)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            await refresh()
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }

    static func siblingMessage(_ r: BulkAssignGroupsResult) -> String {
        guard r.assetsAffected > 1 else { return "Groups updated" }
        if r.siblingMatch == "sku", let sku = r.skuValue {
            return "Groups updated across \(r.assetsAffected) assets with SKU \"\(sku)\""
        }
        return "Groups updated across \(r.assetsAffected) assets with same name"
    }
}
