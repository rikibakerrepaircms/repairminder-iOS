//
//  PaymentService.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import Foundation

@MainActor
final class PaymentService: ObservableObject {
    private let apiClient: APIClient

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient.shared
    }

    // MARK: - Manual Payments

    /// Record a manual payment (cash, bank transfer, invoice, etc.)
    func recordManualPayment(orderId: String, request: ManualPaymentRequest) async throws -> OrderPayment {
        try await apiClient.request(
            .createOrderPayment(orderId: orderId),
            body: request
        )
    }

    /// Delete a recorded payment
    func deletePayment(orderId: String, paymentId: String) async throws {
        try await apiClient.requestVoid(
            .deleteOrderPayment(orderId: orderId, paymentId: paymentId)
        )
    }

    // MARK: - POS Integrations & Terminals

    /// Check if the company has any POS integrations configured
    func fetchIntegrations() async throws -> [PosIntegration] {
        try await apiClient.request(.posIntegrations)
    }

    /// List available terminals, optionally filtered by location
    func fetchTerminals(locationId: String? = nil) async throws -> [PosTerminal] {
        try await apiClient.request(.posTerminals(locationId: locationId))
    }

    // MARK: - Terminal Payments

    /// Initiate a card payment on a POS terminal
    func initiateTerminalPayment(_ request: InitiateTerminalPaymentRequest) async throws -> InitiateTerminalPaymentResponse {
        try await apiClient.request(.initiateTerminalPayment, body: request)
    }

    /// Poll for terminal payment status (call every 2s)
    func pollPaymentStatus(transactionId: String) async throws -> PosTransactionPollResponse {
        try await apiClient.request(.pollTerminalPayment(transactionId: transactionId))
    }

    /// Cancel a pending terminal payment
    func cancelTerminalPayment(transactionId: String) async throws {
        try await apiClient.requestVoid(.cancelTerminalPayment(transactionId: transactionId))
    }

    // MARK: - Payment Links

    /// Create a payment link (checkout URL) for remote payment
    func createPaymentLink(_ request: CreatePaymentLinkRequest) async throws -> CreatePaymentLinkResponse {
        try await apiClient.request(.createPaymentLink, body: request)
    }

    /// Fetch payment links for an order
    func fetchPaymentLinks(orderId: String) async throws -> [PosPaymentLink] {
        try await apiClient.request(.paymentLinks(orderId: orderId))
    }

    /// Cancel a pending payment link
    func cancelPaymentLink(linkId: String) async throws {
        try await apiClient.requestVoid(.cancelPaymentLink(linkId: linkId))
    }

    /// Resend the payment link email
    func resendPaymentLinkEmail(linkId: String) async throws {
        try await apiClient.requestVoid(.resendPaymentLinkEmail(linkId: linkId))
    }
}
