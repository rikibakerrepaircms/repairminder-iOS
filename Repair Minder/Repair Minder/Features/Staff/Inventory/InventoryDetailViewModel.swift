import Foundation

@MainActor
final class InventoryDetailViewModel: ObservableObject {
    @Published private(set) var asset: Asset?
    @Published private(set) var activity: [AssetActivity] = []
    @Published private(set) var groups: [AssetGroupSummary] = []
    @Published private(set) var externalDeployment: ExternalDeployment?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

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
}
