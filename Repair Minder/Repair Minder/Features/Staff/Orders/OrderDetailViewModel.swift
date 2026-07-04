//
//  OrderDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation

@MainActor
final class OrderDetailViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var order: Order?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var isSavingItem = false
    @Published private(set) var isDeletingItem = false
    @Published private(set) var itemError: String?

    // MARK: - Payment State

    @Published private(set) var isSavingPayment = false
    @Published private(set) var isDeletingPayment = false
    @Published private(set) var paymentError: String?
    @Published private(set) var posIntegrations: [PosIntegration] = []
    @Published private(set) var posTerminals: [PosTerminal] = []
    @Published private(set) var paymentLinks: [PosPaymentLink] = []

    // MARK: - Close-out Action State

    @Published private(set) var isPerformingAction = false
    @Published var actionError: String?

    // MARK: - Private

    private let orderId: String
    private let apiClient: APIClient
    private let paymentService = PaymentService()

    // MARK: - Initialization

    init(orderId: String, apiClient: APIClient? = nil) {
        self.orderId = orderId
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Public Methods

    /// Whether the order can be edited (not collected/despatched)
    var isOrderEditable: Bool {
        guard let order else { return false }
        return order.status != .collectedDespatched
    }

    var hasPosIntegrations: Bool {
        !posIntegrations.isEmpty
    }

    var hasActiveTerminals: Bool {
        posTerminals.contains { $0.isActive == true }
    }

    var balanceDue: Double {
        order?.totals?.balanceDue ?? order?.balanceDue ?? 0
    }

    var depositsEnabled: Bool {
        order?.company?.depositsEnabled == 1
    }

    /// Load order details
    func loadOrder() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let fetchedOrder: Order = try await apiClient.request(.order(id: orderId))
            self.order = fetchedOrder

            // Load POS config and payment links concurrently (non-blocking)
            async let posConfig: Void = loadPosConfig()
            async let links: Void = loadPaymentLinks()
            _ = await (posConfig, links)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Refresh order details
    func refresh() async {
        do {
            let fetchedOrder: Order = try await apiClient.request(.order(id: orderId))
            self.order = fetchedOrder
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Add a new line item. Returns true on success.
    func createItem(_ request: OrderItemRequest) async -> Bool {
        isSavingItem = true
        itemError = nil
        defer { isSavingItem = false }
        do {
            let _: OrderItem = try await apiClient.request(
                .createOrderItem(orderId: orderId),
                body: request
            )
            await refresh()
            return true
        } catch let apiError as APIError {
            itemError = apiError.localizedDescription
            return false
        } catch {
            itemError = error.localizedDescription
            return false
        }
    }

    /// Update an existing line item. Returns true on success.
    func updateItem(itemId: String, request: OrderItemRequest) async -> Bool {
        isSavingItem = true
        itemError = nil
        defer { isSavingItem = false }
        do {
            let _: OrderItem = try await apiClient.request(
                .updateOrderItem(orderId: orderId, itemId: itemId),
                body: request
            )
            await refresh()
            return true
        } catch let apiError as APIError {
            itemError = apiError.localizedDescription
            return false
        } catch {
            itemError = error.localizedDescription
            return false
        }
    }

    /// Delete a line item. Returns true on success.
    func deleteItem(itemId: String) async -> Bool {
        isDeletingItem = true
        itemError = nil
        defer { isDeletingItem = false }
        do {
            try await apiClient.requestVoid(
                .deleteOrderItem(orderId: orderId, itemId: itemId)
            )
            await refresh()
            return true
        } catch let apiError as APIError {
            itemError = apiError.localizedDescription
            return false
        } catch {
            itemError = error.localizedDescription
            return false
        }
    }

    /// Clear item error (called from view alert dismiss)
    func clearItemError() {
        itemError = nil
    }

    // MARK: - Payment Methods

    /// Record a manual payment. Returns true on success.
    func recordPayment(_ request: ManualPaymentRequest) async -> Bool {
        guard let orderId = order?.id else { return false }
        isSavingPayment = true
        paymentError = nil
        defer { isSavingPayment = false }
        do {
            _ = try await paymentService.recordManualPayment(orderId: orderId, request: request)
            await refresh()
            return true
        } catch let error as APIError {
            paymentError = error.localizedDescription
            return false
        } catch {
            paymentError = error.localizedDescription
            return false
        }
    }

    /// Delete a payment. Returns true on success.
    func deletePayment(paymentId: String) async -> Bool {
        guard let orderId = order?.id else { return false }
        isDeletingPayment = true
        paymentError = nil
        defer { isDeletingPayment = false }
        do {
            try await paymentService.deletePayment(orderId: orderId, paymentId: paymentId)
            await refresh()
            return true
        } catch let error as APIError {
            paymentError = error.localizedDescription
            return false
        } catch {
            paymentError = error.localizedDescription
            return false
        }
    }

    /// Load POS integrations and terminals for the company
    func loadPosConfig(locationId: String? = nil) async {
        do {
            async let integrations = paymentService.fetchIntegrations()
            async let terminals = paymentService.fetchTerminals(locationId: locationId)
            posIntegrations = try await integrations
            posTerminals = try await terminals
        } catch {
            // Silently fail — POS buttons just won't appear
            posIntegrations = []
            posTerminals = []
        }
    }

    /// Load payment links for the current order
    func loadPaymentLinks() async {
        guard let orderId = order?.id else { return }
        do {
            paymentLinks = try await paymentService.fetchPaymentLinks(orderId: orderId)
        } catch {
            paymentLinks = []
        }
    }

    /// Cancel a payment link and refresh links
    func cancelPaymentLink(linkId: String) async {
        do {
            try await paymentService.cancelPaymentLink(linkId: linkId)
            await loadPaymentLinks()
        } catch {
            // Silently fail — link status will be stale until next refresh
        }
    }

    func clearPaymentError() {
        paymentError = nil
    }

    // MARK: - Close-out Mutations

    /// Authorize the order for repair
    func authorize(_ request: AuthorizeOrderRequest) async -> Bool {
        await perform { try await self.apiClient.requestVoid(.authorizeOrder(orderId: self.orderId), body: request) }
    }

    /// Send the customer a quote
    func sendQuote() async -> Bool {
        await perform { try await self.apiClient.requestVoid(.sendQuote(orderId: self.orderId), body: SendQuoteRequest()) }
    }

    /// Mark the order as collected
    func collect(_ request: CollectOrderRequest) async -> Bool {
        await perform { try await self.apiClient.requestVoid(.collectOrder(orderId: self.orderId), body: request) }
    }

    /// Mark the order as despatched
    func despatch(_ request: DespatchOrderRequest) async -> Bool {
        await perform { try await self.apiClient.requestVoid(.despatchOrder(orderId: self.orderId), body: request) }
    }

    /// Capture a signature (authorization or collection)
    func captureSignature(_ request: CreateSignatureRequest) async -> Bool {
        await perform {
            let _: CreatedSignatureResponse = try await self.apiClient.request(
                .createOrderSignature(orderId: self.orderId), body: request)
        }
    }

    /// Create a refund against the order
    func createRefund(_ request: CreateRefundRequest) async -> Bool {
        await perform { _ = try await self.paymentService.createRefund(orderId: self.orderId, request: request) }
    }

    /// Delete a refund
    func deleteRefund(refundId: String) async -> Bool {
        await perform { try await self.paymentService.deleteRefund(orderId: self.orderId, refundId: refundId) }
    }

    /// Update a device's due date
    func updateDeviceDueDate(deviceId: String, dueDate: String) async -> Bool {
        await perform {
            try await self.apiClient.requestVoid(
                .updateOrderDevice(orderId: self.orderId, deviceId: deviceId),
                body: DeviceUpdateRequest.dueDate(dueDate)
            )
        }
    }

    /// Delete a device from the order
    func deleteDevice(deviceId: String) async -> Bool {
        await perform {
            try await self.apiClient.requestVoid(
                .deleteOrderDevice(orderId: self.orderId, deviceId: deviceId)
            )
        }
    }

    /// Set (or clear, if all fields are nil) the whole-order discount
    func setGlobalDiscount(_ request: OrderDiscountRequest) async -> Bool {
        await perform { try await self.apiClient.requestVoid(.setOrderDiscount(orderId: self.orderId), body: request) }
    }

    /// Add a note to the order's associated ticket
    func addNote(_ request: CreateTicketNoteRequest) async -> Bool {
        guard let ticketId = order?.ticketId else {
            actionError = "This order has no ticket to attach a note to."
            return false
        }
        return await perform {
            let _: EmptyResponse = try await self.apiClient.request(.createTicketNote(ticketId: ticketId), body: request)
        }
    }

    /// Shared runner for close-out mutations: manages loading/error state and refreshes the order on success.
    private func perform(_ op: @escaping () async throws -> Void) async -> Bool {
        isPerformingAction = true
        actionError = nil
        defer { isPerformingAction = false }
        do {
            try await op()
            await refresh()
            return true
        } catch let e as APIError {
            actionError = e.localizedDescription
            return false
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
}
