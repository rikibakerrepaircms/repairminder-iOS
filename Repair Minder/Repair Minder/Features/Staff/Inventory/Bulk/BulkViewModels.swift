import Foundation
import SwiftUI

// MARK: - Selection state (edit-mode multi-select on the assets list)

@MainActor
final class BulkSelectionState: ObservableObject {
    @Published var isEditing = false
    @Published var selectedIds: Set<String> = []

    var count: Int { selectedIds.count }
    func isSelected(_ id: String) -> Bool { selectedIds.contains(id) }

    func toggle(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    func selectAll(_ ids: [String]) { selectedIds.formUnion(ids) }
    func clear() { selectedIds.removeAll() }
    func exit() { isEditing = false; selectedIds.removeAll() }

    /// The selected subset of `assets`, preserving list order.
    func selectedAssets(from assets: [Asset]) -> [Asset] {
        assets.filter { selectedIds.contains($0.id) }
    }
}

// MARK: - Bulk return-to-supplier

@MainActor
final class BulkReturnViewModel: ObservableObject {
    private let service: InventoryServing
    let assets: [Asset]

    @Published var reason: SupplierReturnReason = .defective
    @Published var notes: String = ""
    @Published var isSubmitting = false
    @Published var error: String?
    @Published var result: BulkReturnToSupplierResult?

    init(assets: [Asset], service: InventoryServing? = nil) {
        self.assets = assets
        self.service = service ?? InventoryService()
    }

    var validAssets: [Asset] { BulkActions.returnableAssets(assets) }
    var invalidCount: Int { BulkActions.invalidReturnCount(assets) }
    var supplierGroups: [BulkActions.SupplierGroup] { BulkActions.groupedBySupplier(assets) }
    var canSubmit: Bool { !validAssets.isEmpty && !isSubmitting }

    /// Returns true on success (so the sheet can dismiss).
    @discardableResult
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true; error = nil
        defer { isSubmitting = false }
        do {
            let r = try await service.bulkReturnToSupplier(
                assetIds: validAssets.map(\.id),
                reason: reason.rawValue,
                notes: notes.isEmpty ? nil : notes)
            result = r
            NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    var summaryMessage: String? {
        guard let r = result else { return nil }
        var msg = "Returned \(r.totalReturned) asset\(r.totalReturned == 1 ? "" : "s")"
        if !r.errors.isEmpty { msg += " (\(r.errors.count) skipped)" }
        return msg
    }
}

// MARK: - Bulk move (per-item loop; partial success tolerated)

@MainActor
final class BulkMoveViewModel: ObservableObject {
    private let service: InventoryServing
    let assets: [Asset]

    @Published var outcomes: [BulkOperationOutcome] = []
    @Published var isRunning = false
    @Published var finished = false

    init(assets: [Asset], service: InventoryServing? = nil) {
        self.assets = assets
        self.service = service ?? InventoryService()
    }

    func run(locationId: String, subLocationId: String?) async {
        guard !isRunning else { return }
        isRunning = true; outcomes = []
        for asset in assets {
            do {
                _ = try await service.moveAsset(id: asset.id, body: MoveAssetRequest(locationId: locationId, subLocationId: subLocationId))
                outcomes.append(BulkOperationOutcome(assetId: asset.id, assetTag: asset.assetTag, success: true, message: nil))
            } catch {
                outcomes.append(BulkOperationOutcome(assetId: asset.id, assetTag: asset.assetTag, success: false, message: error.localizedDescription))
            }
        }
        isRunning = false; finished = true
        NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
    }
}

// MARK: - Bulk deploy (in-stock only; order or external; per-item loop)

@MainActor
final class BulkDeployViewModel: ObservableObject {
    private let service: InventoryServing
    /// Only in-stock assets are deployable in bulk (mirrors web).
    let assets: [Asset]

    @Published var outcomes: [BulkOperationOutcome] = []
    @Published var isRunning = false
    @Published var finished = false

    init(assets: [Asset], service: InventoryServing? = nil) {
        self.assets = BulkActions.deployableAssets(assets)
        self.service = service ?? InventoryService()
    }

    func runOrder(orderId: String, orderItemId: String?) async {
        await run { asset in
            _ = try await self.service.allocateAsset(
                id: asset.id,
                body: AllocateRequest(orderId: orderId, orderItemId: orderItemId, deploy: false))
        }
    }

    func runExternal(_ request: DeployExternalRequest) async {
        await run { asset in
            _ = try await self.service.deployExternal(id: asset.id, body: request)
        }
    }

    private func run(_ op: @escaping (Asset) async throws -> Void) async {
        guard !isRunning else { return }
        isRunning = true; outcomes = []
        for asset in assets {
            do {
                try await op(asset)
                outcomes.append(BulkOperationOutcome(assetId: asset.id, assetTag: asset.assetTag, success: true, message: nil))
            } catch {
                outcomes.append(BulkOperationOutcome(assetId: asset.id, assetTag: asset.assetTag, success: false, message: error.localizedDescription))
            }
        }
        isRunning = false; finished = true
        NotificationCenter.default.post(name: .inventoryAssetDidChange, object: nil)
    }
}

// MARK: - Bulk scan accumulator (camera; in-stock only)

@MainActor
final class BulkScanViewModel: ObservableObject {
    private let service: InventoryServing

    struct ScanEntry: Identifiable, Equatable {
        let tag: String
        var asset: Asset?
        var error: String?
        var id: String { tag }
    }

    @Published var entries: [ScanEntry] = []
    @Published var lastMessage: String?

    init(service: InventoryServing? = nil) {
        self.service = service ?? InventoryService()
    }

    var readyAssets: [Asset] { entries.compactMap(\.asset) }
    var readyCount: Int { readyAssets.count }

    func onScan(tag: String) async {
        let trimmed = AssetScan.parse(tag)
        guard !trimmed.isEmpty else { return }
        if entries.contains(where: { $0.tag == trimmed }) {
            lastMessage = "Already scanned \(trimmed)"
            return
        }
        do {
            let asset = try await service.fetchAssetByTag(trimmed)
            if asset.status == .inStock {
                entries.append(ScanEntry(tag: trimmed, asset: asset, error: nil))
                lastMessage = "Added \(asset.name)"
            } else {
                entries.append(ScanEntry(tag: trimmed, asset: nil, error: "Must be in stock (is \(asset.status.displayName))"))
                lastMessage = "\(trimmed) is not in stock"
            }
        } catch {
            entries.append(ScanEntry(tag: trimmed, asset: nil, error: "Asset not found"))
            lastMessage = "No asset for \(trimmed)"
        }
    }

    func remove(_ tag: String) { entries.removeAll { $0.tag == tag } }
    func clear() { entries.removeAll(); lastMessage = nil }
}
