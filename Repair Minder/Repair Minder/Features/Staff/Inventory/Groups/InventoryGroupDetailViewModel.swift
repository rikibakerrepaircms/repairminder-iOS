import SwiftUI

@MainActor
final class InventoryGroupDetailViewModel: ObservableObject {
    enum Tab { case assets, products }

    let groupId: String
    @Published var group: InventoryGroup?
    @Published var assets: [Asset] = []
    @Published var products: [LinkedProduct] = []
    @Published var tab: Tab = .assets
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var errorMessage: String?
    @Published private(set) var hasMoreAssets = false

    private let service: InventoryServing
    private var page = 1
    private let pageSize = 20

    init(groupId: String, service: InventoryServing? = nil) {
        self.groupId = groupId
        self.service = service ?? InventoryService()
    }

    func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            async let g = service.fetchGroup(id: groupId)
            async let a = service.fetchGroupAssets(id: groupId, page: 1, limit: pageSize)
            async let p = service.fetchGroupProducts(id: groupId)
            group = try await g
            let assetsResult = try await a
            assets = assetsResult; hasMoreAssets = assetsResult.count == pageSize; page = 1
            products = try await p
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreAssets() async {
        guard hasMoreAssets, !isMutating, !isLoading else { return }
        do {
            let next = page + 1
            let result = try await service.fetchGroupAssets(id: groupId, page: next, limit: pageSize)
            assets.append(contentsOf: result); page = next; hasMoreAssets = result.count == pageSize
        } catch { /* keep existing list on pagination failure */ }
    }

    @discardableResult
    func addMember(assetId: String) async -> Bool {
        isMutating = true; defer { isMutating = false }
        do {
            _ = try await service.addMembership(assetId: assetId, groupId: groupId)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            await load()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    /// Two-step remove (group-assets rows carry no membership_id): look up this asset's
    /// groups, find the membership for THIS group, delete it.
    func removeMember(assetId: String) async {
        isMutating = true; defer { isMutating = false }
        do {
            let groups = try await service.fetchAssetGroups(id: assetId)
            guard let membershipId = groups.first(where: { $0.id == groupId })?.membershipId else {
                errorMessage = "Membership not found"; return
            }
            try await service.removeMembership(id: membershipId)
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
}
