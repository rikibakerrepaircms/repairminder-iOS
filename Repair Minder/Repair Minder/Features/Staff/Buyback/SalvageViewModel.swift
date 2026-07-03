import Foundation

/// A configured-but-not-yet-booked salvage line.
struct StagedSalvage: Identifiable, Equatable {
    let id: String
    let name: String
    let request: SalvageItemRequest
}

@MainActor
final class SalvageViewModel: ObservableObject {
    private let service: InventoryServing
    let buybackId: String
    let purchaseAmount: Double

    // Reference data
    @Published var groups: [AssetGroupListItem] = []
    @Published var locations: [Location] = []
    @Published var subLocations: [AssetSubLocationOption] = []

    // Booked (from the server) + staged (client-side)
    @Published var salvaged: [SalvagedAssetSummary]
    @Published var staged: [StagedSalvage] = []

    // Staging form
    @Published var selectedGroup: AssetGroupListItem?
    @Published var grade: String = "A"
    @Published var value: String = ""
    @Published var lcdWorking: Int?
    @Published var glassCracked: Int?
    @Published var locationId: String?
    @Published var subLocationId: String?
    @Published var notes: String = ""

    @Published var isBooking = false
    @Published var error: String?

    init(buybackId: String, purchaseAmount: Double, salvaged: [SalvagedAssetSummary], service: InventoryServing? = nil) {
        self.buybackId = buybackId
        self.purchaseAmount = purchaseAmount
        self.salvaged = salvaged
        self.service = service ?? InventoryService()
    }

    // MARK: Budget
    var booked: Double { salvaged.reduce(0) { $0 + ($1.cost ?? 0) } }
    var pending: Double { staged.reduce(0) { $0 + ($1.request.value ?? 0) } }
    var remaining: Double { SalvageBudgetMath.remaining(cap: purchaseAmount, booked: booked, pending: pending) }
    var overCap: Bool { SalvageBudgetMath.overCap(cap: purchaseAmount, booked: booked, pending: pending) }

    var isScreen: Bool { SalvageBudgetMath.isScreen(category: selectedGroup?.category) }
    var canAdd: Bool {
        SalvageBudgetMath.canAdd(groupId: selectedGroup?.id, locationId: locationId, isScreen: isScreen, lcd: lcdWorking, glass: glassCracked)
    }

    // MARK: Reference data
    func loadReferenceData() async {
        async let g = try? service.fetchGroups(search: nil)
        async let l = try? service.fetchLocations()
        groups = (await g) ?? []
        locations = (await l) ?? []
    }
    func loadSubLocations(_ id: String) async {
        subLocations = (try? await service.fetchSubLocations(locationId: id)) ?? []
    }

    // MARK: Staging
    func addToBatch() {
        guard canAdd, let group = selectedGroup, let locationId else { return }
        let req = SalvageItemRequest(
            productTypeId: group.id,
            conditionGrade: grade,
            locationId: locationId,
            subLocationId: subLocationId,
            lcdWorking: isScreen ? lcdWorking : nil,
            glassCracked: isScreen ? glassCracked : nil,
            value: Double(value),
            notes: notes.isEmpty ? nil : notes)
        staged.append(StagedSalvage(id: UUID().uuidString, name: group.name, request: req))
        resetForm()
    }

    func removeStaged(_ id: String) { staged.removeAll { $0.id == id } }

    private func resetForm() {
        selectedGroup = nil; grade = "A"; value = ""; lcdWorking = nil; glassCracked = nil
        subLocationId = nil; notes = ""
    }

    var needsConfirmation: Bool { salvaged.isEmpty }
    var canBook: Bool { !staged.isEmpty && !overCap && !isBooking }

    /// Books the staged items. Returns true on success.
    @discardableResult
    func book() async -> Bool {
        guard canBook else { return false }
        isBooking = true; error = nil
        defer { isBooking = false }
        do {
            let resp = try await service.salvageBuyback(id: buybackId, items: staged.map(\.request))
            salvaged = resp.salvagedAssets
            staged = []
            return true
        } catch let e as APIError {
            error = salvageErrorMessage(e)
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func removeSalvaged(_ assetId: String) async {
        error = nil
        do {
            let resp = try await service.deleteSalvageItem(buybackId: buybackId, assetId: assetId)
            salvaged = resp.salvagedAssets
        } catch let e as APIError {
            error = salvageErrorMessage(e)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Friendlier copy for the cost-cap / VAT-lock / allocation cases.
    private func salvageErrorMessage(_ e: APIError) -> String {
        let msg = e.localizedDescription
        if msg.lowercased().contains("exceed") { return "Over budget — reduce salvage values (only \(CurrencyFormatter.format(remaining)) remaining)." }
        return msg
    }
}
