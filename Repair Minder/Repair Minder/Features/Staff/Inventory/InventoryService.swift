import Foundation

/// Abstraction over the inventory endpoints so view models can be tested with a mock.
@MainActor
protocol InventoryServing {
    func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset]
    func fetchAsset(id: String) async throws -> Asset
    func fetchAssetByTag(_ tag: String) async throws -> Asset
    func fetchActivity(id: String) async throws -> [AssetActivity]
    func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary]
    func fetchExternalDeployment(id: String) async throws -> ExternalDeployment
    func fetchCategories() async throws -> [String]
    func fetchGroups(search: String?) async throws -> [AssetGroupListItem]
    func fetchProductTypes(search: String) async throws -> [ProductTypeOption]
    func fetchLocations() async throws -> [Location]
    func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption]

    // Phase 2 write actions
    func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse
    func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset
    func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse
    func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData
    func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset
    func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset
    func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset
    func deleteAsset(id: String) async throws
    // Deploy wizard support
    func searchOrders(search: String) async throws -> [Order]
    func fetchOrderItems(orderId: String) async throws -> [OrderItem]

    // Phase 3 — Groups
    func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup]
    func fetchGroup(id: String) async throws -> InventoryGroup
    func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset]
    func fetchGroupProducts(id: String) async throws -> [LinkedProduct]
    func addMembership(assetId: String, groupId: String) async throws -> GroupMembership
    func removeMembership(id: String) async throws
    func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult
    func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult
    func createGroup(_ body: GroupFormRequest) async throws -> InventoryGroup
    func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup

    // Phase 4 — bulk
    func bulkReturnToSupplier(assetIds: [String], reason: String, notes: String?) async throws -> BulkReturnToSupplierResult
}

/// The filter parameters that vary per list request.
struct AssetQuery: Equatable {
    var status: String?
    var category: String?
    var locationId: String?
    var subLocationId: String?
    var productTypeId: String?
    var groupId: String?
    var hasGroups: Bool?
    var hasProducts: Bool?
    var search: String?
}

/// Minimal product-type row for the filter picker.
struct ProductTypeOption: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    var sku: String?
}

/// Minimal sub-location row for the filter picker.
struct AssetSubLocationOption: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    var code: String?
    var description: String?
}

@MainActor
final class InventoryService: InventoryServing {
    private let api: APIClient
    // APIClient.shared is @MainActor-isolated, so it cannot be a default-arg
    // value (default args are evaluated in a nonisolated context — an error in
    // Swift 6 mode). Use optional + nil-coalesce; the init body runs on the
    // MainActor (this class is @MainActor), where `.shared` is valid.
    init(api: APIClient? = nil) { self.api = api ?? APIClient.shared }

    func fetchAssets(page: Int, pageSize: Int, filters q: AssetQuery) async throws -> [Asset] {
        try await api.request(.inventoryList(
            page: page, limit: pageSize,
            status: q.status, category: q.category,
            locationId: q.locationId, subLocationId: q.subLocationId,
            productTypeId: q.productTypeId, groupId: q.groupId,
            hasGroups: q.hasGroups, hasProducts: q.hasProducts, search: q.search))
    }

    func fetchAsset(id: String) async throws -> Asset {
        try await api.request(.inventoryDetail(id: id))
    }
    func fetchAssetByTag(_ tag: String) async throws -> Asset {
        try await api.request(.inventoryByTag(tag: tag))
    }
    func fetchActivity(id: String) async throws -> [AssetActivity] {
        try await api.request(.inventoryActivity(id: id, limit: 50))
    }
    func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] {
        try await api.request(.inventoryAssetGroups(id: id))
    }
    func fetchExternalDeployment(id: String) async throws -> ExternalDeployment {
        try await api.request(.inventoryExternalDeployment(id: id))
    }
    func fetchCategories() async throws -> [String] {
        let resp: CategoriesResponse = try await api.request(.productTypeCategories)
        return resp.categories.map(\.category).filter { !$0.isEmpty }
    }
    func fetchGroups(search: String?) async throws -> [AssetGroupListItem] {
        try await api.request(.assetGroupsList(page: 1, limit: 100, search: search, category: nil, hasProducts: nil, unlinkedOnly: nil, sortBy: nil, sortOrder: nil))
    }
    func fetchProductTypes(search: String) async throws -> [ProductTypeOption] {
        try await api.request(.productTypes(search: search))
    }
    func fetchLocations() async throws -> [Location] {
        try await api.request(.locations)
    }
    func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] {
        try await api.request(.locationSubLocations(locationId: locationId))
    }

    // MARK: - Phase 2 write actions

    func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse {
        try await api.requestFull(.updateAsset(id: id), body: body)
    }
    func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset {
        try await api.request(.moveAsset(id: id), body: body)
    }
    func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
        try await api.requestFull(.allocateAsset(id: id), body: body)
    }
    func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData {
        try await api.request(.deployExternalAsset(id: id), body: body)
    }
    func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset {
        try await api.request(.returnExternalAsset(id: id), body: body)
    }
    func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset {
        try await api.request(.returnToSupplierAsset(id: id), body: body)
    }
    func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset {
        try await api.request(.resolveSupplierReturn(id: id), body: body)
    }
    func deleteAsset(id: String) async throws {
        try await api.requestVoid(.deleteAsset(id: id))
    }

    // MARK: - Deploy wizard support

    func searchOrders(search: String) async throws -> [Order] {
        try await api.request(.orders(page: 1, limit: 10, status: nil, paymentStatus: nil,
                                       locationId: nil, assignedUserId: nil, search: search))
    }
    /// Line items come from the order-detail endpoint (verified `request<Order>` path);
    /// the standalone `.orderItems` endpoint is unused/unverified, so we read `order.items`.
    func fetchOrderItems(orderId: String) async throws -> [OrderItem] {
        let order: Order = try await api.request(.order(id: orderId))
        return order.items ?? []
    }

    // MARK: - Phase 3 group actions
    func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup] {
        try await api.request(.assetGroupsList(page: page, limit: limit, search: search, category: category, hasProducts: hasProducts, unlinkedOnly: unlinkedOnly, sortBy: sortBy, sortOrder: sortOrder))
    }
    func fetchGroup(id: String) async throws -> InventoryGroup {
        try await api.request(.assetGroup(id: id))
    }
    func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset] {
        try await api.request(.assetGroupAssets(id: id, page: page, limit: limit))
    }
    func fetchGroupProducts(id: String) async throws -> [LinkedProduct] {
        try await api.request(.assetGroupProducts(id: id))
    }
    func addMembership(assetId: String, groupId: String) async throws -> GroupMembership {
        try await api.request(.addMembership, body: AddMembershipRequest(assetId: assetId, groupId: groupId))
    }
    func removeMembership(id: String) async throws {
        try await api.requestVoid(.removeMembership(id: id))
    }
    func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult {
        try await api.request(.bulkAssignGroups(assetId: assetId), body: BulkAssignGroupsRequest(groupIds: groupIds))
    }
    func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult {
        try await api.request(.promoteGroup, body: body)
    }
    func createGroup(_ body: GroupFormRequest) async throws -> InventoryGroup {
        try await api.request(.createProductType, body: body)
    }
    func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup {
        try await api.request(.updateProductType(id: id), body: body)
    }

    // MARK: - Phase 4 bulk actions
    func bulkReturnToSupplier(assetIds: [String], reason: String, notes: String?) async throws -> BulkReturnToSupplierResult {
        try await api.request(.bulkReturnToSupplier,
                              body: BulkReturnToSupplierRequest(assetIds: assetIds, supplierReturnReason: reason, supplierReturnNotes: notes))
    }
}
