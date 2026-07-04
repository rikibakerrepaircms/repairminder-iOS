import Foundation
import SwiftUI

// MARK: - Networking seam

@MainActor
protocol KioskServicing {
    func createOrder(_ request: KioskOrderRequest) async throws -> KioskOrderResponse
    func cancelOrder(id: String) async throws
    func availableAssets(productTypeId: String?, search: String?) async throws -> [KioskAvailableAsset]
}

@MainActor
final class KioskService: KioskServicing {
    private let api: APIClient
    init(api: APIClient? = nil) { self.api = api ?? .shared }

    func createOrder(_ request: KioskOrderRequest) async throws -> KioskOrderResponse {
        try await api.request(.createKioskOrder, body: request)
    }
    func cancelOrder(id: String) async throws {
        try await api.requestVoid(.cancelKioskOrder(id: id))
    }
    func availableAssets(productTypeId: String?, search: String?) async throws -> [KioskAvailableAsset] {
        try await api.request(.kioskAvailableAssets(productTypeId: productTypeId, groupId: nil, search: search))
    }
}

// MARK: - Selected client reference (UI-only)

struct KioskClientRef: Equatable, Identifiable, Sendable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
    var displayName: String {
        let n = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return n.isEmpty ? (email ?? "Client") : n
    }
}

// MARK: - State machine

enum KioskMode: Equatable { case shopping, processing, receipt }

@MainActor
final class KioskViewModel: ObservableObject {
    @Published var mode: KioskMode = .shopping
    @Published var items: [KioskCartItem] = []
    @Published var selectedClient: KioskClientRef?
    @Published var globalDiscountPercent: Double?
    @Published var globalDiscountAmount: Double?
    @Published var globalDiscountReason: String?
    @Published var completedOrder: KioskOrderResponse?
    @Published var errorMessage: String?
    let locationId: String?

    private let service: KioskServicing

    init(service: KioskServicing? = nil, locationId: String? = nil) {
        self.service = service ?? KioskService()
        self.locationId = locationId
    }

    var totals: KioskTotals {
        KioskCartMath.computeCartTotals(items,
            globalDiscountPercent: globalDiscountPercent,
            globalDiscountAmount: globalDiscountAmount)
    }
    var isGuestCheckout: Bool { selectedClient == nil }
    var isEmpty: Bool { items.isEmpty }

    // MARK: - Cart operations

    func addItem(_ item: KioskCartItem) { items.append(item) }

    func removeItem(_ id: String) { items.removeAll { $0.id == id } }

    func setQuantity(_ id: String, _ newQty: Int) {
        guard let idx = items.firstIndex(where: { $0.id == id }), newQty >= 1 else { return }
        items[idx].quantity = newQty
        if items[idx].selectedAssets.count > newQty {
            items[idx].selectedAssets = Array(items[idx].selectedAssets.prefix(newQty))
        }
    }

    func updateItem(_ id: String, _ mutate: (inout KioskCartItem) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[idx])
    }

    // MARK: - Request building

    // Exposed for tests
    func buildRequestForTest(payment: KioskPaymentRequest?) -> KioskOrderRequest {
        buildRequest(payment: payment)
    }

    private func buildRequest(payment: KioskPaymentRequest?) -> KioskOrderRequest {
        let itemRequests = items.map { i in
            KioskOrderItemRequest(
                productTypeId: i.productTypeId,
                description: i.description,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                vatRate: i.vatRate,
                itemType: i.itemType,
                discountPercent: i.discountPercent,
                discountAmount: i.discountAmount,
                discountReason: i.discountReason,
                assetIds: i.selectedAssets.map { $0.id })
        }
        // Empty id (inline-new client) is omitted so the server creates/looks up by email/name (matches web `client_id || undefined`).
        let clientId: String? = (selectedClient?.id.isEmpty == false) ? selectedClient?.id : nil
        return KioskOrderRequest(
            clientId: clientId,
            clientEmail: selectedClient?.email,
            clientFirstName: selectedClient?.firstName,
            clientLastName: selectedClient?.lastName,
            clientPhone: selectedClient?.phone,
            guestCheckout: isGuestCheckout,
            items: itemRequests,
            globalDiscountPercent: globalDiscountPercent,
            globalDiscountAmount: globalDiscountAmount,
            globalDiscountReason: globalDiscountReason,
            payment: payment,
            locationId: locationId)
    }

    // MARK: - Payment orchestration

    func submitCashOrManual(method: String, amount: Double, notes: String?) async {
        guard !items.isEmpty else { return }
        mode = .processing
        do {
            let order = try await service.createOrder(
                buildRequest(payment: KioskPaymentRequest(amount: amount, paymentMethod: method, notes: notes)))
            completedOrder = order
            mode = .receipt
        } catch {
            errorMessage = Self.message(for: error)
            mode = .shopping
        }
    }

    func createUnpaidOrderForCard() async -> KioskOrderResponse? {
        guard !items.isEmpty else { return nil }
        do {
            return try await service.createOrder(buildRequest(payment: nil))
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    func cardPaymentSucceeded(order: KioskOrderResponse) {
        completedOrder = order
        mode = .receipt
    }

    func cancelUnpaidOrder(id: String) async {
        try? await service.cancelOrder(id: id)
    }

    // MARK: - Reset

    func startNewSale() {
        items = []
        selectedClient = nil
        globalDiscountPercent = nil
        globalDiscountAmount = nil
        globalDiscountReason = nil
        completedOrder = nil
        errorMessage = nil
        mode = .shopping
    }

    // MARK: - Error surfacing

    private static func message(for error: Error) -> String {
        // APIError conforms to LocalizedError; its `errorDescription` surfaces the
        // server-provided message for .serverError / .httpError. Fall back to a
        // generic description for any non-APIError.
        if let apiError = error as? APIError, let d = apiError.errorDescription { return d }
        return String(describing: error)
    }
}
