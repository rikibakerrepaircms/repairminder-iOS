import Foundation
@testable import Repair_Minder

/// Base test double: conforms to InventoryServing with harmless defaults.
/// Subclass in tests and override only the methods under test.
@MainActor
class InventoryServingStub: InventoryServing {
    func fetchAssets(page: Int, pageSize: Int, filters: AssetQuery) async throws -> [Asset] { [] }
    func fetchAsset(id: String) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
    func fetchAssetByTag(_ tag: String) async throws -> Asset { Asset(id: "a", assetTag: tag, name: "n", status: .inStock) }
    func fetchActivity(id: String) async throws -> [AssetActivity] { [] }
    func fetchAssetGroups(id: String) async throws -> [AssetGroupSummary] { [] }
    func fetchExternalDeployment(id: String) async throws -> ExternalDeployment { .init() }
    func fetchCategories() async throws -> [String] { [] }
    func fetchGroups(search: String?) async throws -> [AssetGroupListItem] { [] }
    func fetchProductTypes(search: String) async throws -> [ProductTypeOption] { [] }
    func fetchLocations() async throws -> [Location] { [] }
    func fetchSubLocations(locationId: String) async throws -> [AssetSubLocationOption] { [] }
    func updateAsset(id: String, body: UpdateAssetRequest) async throws -> EditAssetResponse {
        EditAssetResponse(success: true, data: Asset(id: id, assetTag: "T", name: "n", status: .inStock), skuUpdatedCount: nil)
    }
    func moveAsset(id: String, body: MoveAssetRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
    func allocateAsset(id: String, body: AllocateRequest) async throws -> AllocateResponse {
        AllocateResponse(success: true, data: Asset(id: id, assetTag: "T", name: "n", status: .inStock),
                         promptReadyToRepair: nil, allocatedParts: nil, device: nil, recoveredAsset: nil)
    }
    func deployExternal(id: String, body: DeployExternalRequest) async throws -> DeployExternalData {
        DeployExternalData(asset: Asset(id: id, assetTag: "T", name: "n", status: .inStock),
                           deployment: ExternalDeploymentRecord(id: "dep1"))
    }
    func returnExternal(id: String, body: ReturnExternalRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
    func returnToSupplier(id: String, body: ReturnToSupplierRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
    func resolveSupplierReturn(id: String, body: ResolveReturnRequest) async throws -> Asset { Asset(id: id, assetTag: "T", name: "n", status: .inStock) }
    func deleteAsset(id: String) async throws {}
    func searchOrders(search: String) async throws -> [Order] { [] }
    func fetchOrderItems(orderId: String) async throws -> [OrderItem] { [] }
    func listGroups(page: Int, limit: Int, search: String?, category: String?, hasProducts: Bool?, unlinkedOnly: Bool?, sortBy: String?, sortOrder: String?) async throws -> [InventoryGroup] { [] }
    func fetchGroup(id: String) async throws -> InventoryGroup { InventoryGroup(id: id, name: "n") }
    func fetchGroupAssets(id: String, page: Int, limit: Int) async throws -> [Asset] { [] }
    func fetchGroupProducts(id: String) async throws -> [LinkedProduct] { [] }
    func addMembership(assetId: String, groupId: String) async throws -> GroupMembership { GroupMembership(id: "m") }
    func removeMembership(id: String) async throws {}
    func bulkAssignGroups(assetId: String, groupIds: [String]) async throws -> BulkAssignGroupsResult { BulkAssignGroupsResult(groupsAdded: 0, groupsRemoved: 0, assetsAffected: 1) }
    func promoteGroup(_ body: PromoteGroupRequest) async throws -> PromoteResult { fatalError("not stubbed") }
    func createGroup(_ body: GroupFormRequest) async throws -> InventoryGroup { InventoryGroup(id: "g", name: body.name) }
    func updateGroup(id: String, body: GroupFormRequest) async throws -> InventoryGroup { InventoryGroup(id: id, name: body.name) }
    func bulkReturnToSupplier(assetIds: [String], reason: String, notes: String?) async throws -> BulkReturnToSupplierResult {
        BulkReturnToSupplierResult(batches: [], totalReturned: assetIds.count, errors: [])
    }
    func fetchStockSummary() async throws -> [StockSummaryItem] { [] }
    func fetchHierarchy(status: String?) async throws -> AssetHierarchyResponse { AssetHierarchyResponse(grouped: [], unlinked: []) }
    func fetchLowStock() async throws -> LowStockResponse {
        LowStockResponse(alerts: LowStockBuckets(parts: [], masters: [], services: []),
                         all: [], summary: LowStockSummary(total: 0, byCategory: LowStockByCategory(parts: 0, masters: 0, services: 0)))
    }
    func salvageBuyback(id: String, items: [SalvageItemRequest]) async throws -> SalvageResponse {
        SalvageResponse(assets: [], salvagedAssets: [], newStatus: "salvaged",
                        salvageBudget: SalvageBudgetInfo(cap: nil, booked: nil, remaining: nil))
    }
    func deleteSalvageItem(buybackId: String, assetId: String) async throws -> DeleteSalvageResult {
        DeleteSalvageResult(salvagedAssets: [], booked: 0, revertedTo: nil)
    }
    func listSupplierOrders(page: Int, limit: Int, supplier: String?, status: String?) async throws -> [SupplierOrder] { [] }
    func getSupplierOrder(id: String) async throws -> SupplierOrder {
        SupplierOrder(id: id, supplierName: "S", status: "pending")
    }
    func createSupplierOrder(_ body: CreateSupplierOrderRequest) async throws -> SupplierOrder {
        SupplierOrder(id: "so1", supplierName: body.supplierName, status: "pending")
    }
    func updateSupplierOrder(id: String, body: UpdateSupplierOrderRequest) async throws -> SupplierOrder {
        SupplierOrder(id: id, supplierName: body.supplierName ?? "S", status: body.status ?? "pending")
    }
    func addOrderLine(orderId: String, body: SupplierOrderLineRequest) async throws -> SupplierOrderLine {
        SupplierOrderLine(id: "line1", name: body.name, quantityOrdered: body.quantityOrdered ?? 1, quantityReceived: 0, unitCost: body.unitCost ?? 0)
    }
    func updateOrderLine(orderId: String, lineId: String, body: SupplierOrderLineRequest) async throws -> SupplierOrderLine {
        SupplierOrderLine(id: lineId, name: body.name, quantityOrdered: body.quantityOrdered ?? 1, quantityReceived: 0, unitCost: body.unitCost ?? 0)
    }
    func deleteOrderLine(orderId: String, lineId: String) async throws {}
    func receiveItems(orderId: String, items: [ReceiveItemInput]) async throws -> ReceiveItemsResult {
        ReceiveItemsResult(order: SupplierOrder(id: orderId, supplierName: "S", status: "received"), createdAssets: [], assetsCreatedCount: 0)
    }
    func extractInvoice(fileData: Data, fileName: String, mimeType: String) async throws -> ExtractInvoiceResponse {
        ExtractInvoiceResponse(success: true, data: ExtractedInvoice(lineItems: []), invoiceFileKey: nil, fileType: nil)
    }
    func listSuppliers() async throws -> [SupplierNameOption] { [] }
    func importAssets(csvData: Data, fileName: String, createMissing: Bool) async throws -> AssetImportResponse {
        AssetImportResponse(success: true, message: "ok", data: AssetImportCounts(imported: 0))
    }
}
