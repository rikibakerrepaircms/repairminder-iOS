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
    init(api: APIClient = .shared) { self.api = api }

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
        try await api.request(.assetGroupsList(page: 1, limit: 100, search: search))
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
}
