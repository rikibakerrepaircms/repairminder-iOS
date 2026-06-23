//
//  CustomerOrderDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Identifiable wrapper for a locally-cached file URL — drives `.sheet(item:)` for QuickLook
struct PoPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// ViewModel for customer order detail
@MainActor
final class CustomerOrderDetailViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var order: CustomerOrderDetail?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    // Approval flow state
    @Published var showApprovalSheet: Bool = false
    @Published var selectedDeviceForApproval: CustomerDevice?
    @Published var isSubmittingApproval: Bool = false
    @Published var approvalError: String?
    @Published var approvalSuccess: Bool = false

    // Message compose state
    @Published var showMessageCompose: Bool = false
    @Published var newMessageText: String = ""
    @Published var isSendingMessage: Bool = false
    @Published var messageError: String?

    // PO Documents state
    @Published private(set) var poDocuments: [PoDocument] = []
    @Published var poPreviewItem: PoPreviewItem?

    // MARK: - Properties

    let orderId: String

    // MARK: - Dependencies

    private let customerAuth = CustomerAuthManager.shared

    // MARK: - Initialization

    init(orderId: String) {
        self.orderId = orderId
    }

    // MARK: - Data Loading

    /// Load order detail from API
    func loadOrder() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            order = try await fetchOrderDetail()
            await fetchPoDocuments()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch let decodingError as DecodingError {
            errorMessage = "Failed to decode order data"
            #if DEBUG
            print("[CustomerOrderDetailVM] Decode error: \(decodingError)")
            #endif
        } catch {
            errorMessage = "Failed to load order"
        }

        isLoading = false
    }

    /// Refresh order (for pull-to-refresh)
    func refresh() async {
        await loadOrder()
    }

    // MARK: - Quote Approval

    /// Approve quote for entire order
    func approveQuote(signatureType: String, signatureData: String, bankDetails: (accountHolder: String, sortCode: String, accountNumber: String)? = nil) async {
        guard let order = order else { return }

        isSubmittingApproval = true
        approvalError = nil

        do {
            try await submitApproval(
                action: "approve",
                signatureType: signatureType,
                signatureData: signatureData,
                amountAcknowledged: order.totals.grandTotal,
                bankDetails: bankDetails
            )
            approvalSuccess = true
            // Reload order to get updated state
            await loadOrder()
        } catch let error as APIError {
            approvalError = error.localizedDescription
            #if DEBUG
            print("[CustomerOrderDetailVM] Approval error: \(error)")
            #endif
        } catch {
            approvalError = "Failed to approve quote"
            #if DEBUG
            print("[CustomerOrderDetailVM] Unexpected approval error: \(error)")
            #endif
        }

        isSubmittingApproval = false
    }

    /// Reject quote for entire order
    func rejectQuote(reason: String?, signatureType: String, signatureData: String) async {
        isSubmittingApproval = true
        approvalError = nil

        do {
            try await submitRejection(reason: reason, signatureType: signatureType, signatureData: signatureData)
            approvalSuccess = true
            // Reload order to get updated state
            await loadOrder()
        } catch let error as APIError {
            approvalError = error.localizedDescription
            #if DEBUG
            print("[CustomerOrderDetailVM] Rejection error: \(error)")
            #endif
        } catch {
            approvalError = "Failed to reject quote"
            #if DEBUG
            print("[CustomerOrderDetailVM] Unexpected rejection error: \(error)")
            #endif
        }

        isSubmittingApproval = false
    }

    // MARK: - Messaging

    /// Send a reply message
    func sendMessage() async {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSendingMessage = true
        messageError = nil

        do {
            try await submitReply(message: newMessageText.trimmingCharacters(in: .whitespacesAndNewlines))
            newMessageText = ""
            showMessageCompose = false
            // Reload order to get new message
            await loadOrder()
        } catch let error as APIError {
            messageError = error.localizedDescription
            #if DEBUG
            print("[CustomerOrderDetailVM] Message send error: \(error)")
            #endif
        } catch {
            messageError = "Failed to send message"
            #if DEBUG
            print("[CustomerOrderDetailVM] Unexpected message error: \(error)")
            #endif
        }

        isSendingMessage = false
    }

    // MARK: - Private API Methods

    private func fetchOrderDetail() async throws -> CustomerOrderDetail {
        guard let token = customerAuth.accessToken else {
            throw APIError.unauthorized
        }

        let url = URL(string: "https://api.repairminder.com/api/customer/orders/\(orderId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode == 404 {
            throw APIError.notFound
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Note: dates are decoded manually in models due to mixed formats

        let apiResponse = try decoder.decode(APIResponse<CustomerOrderDetail>.self, from: data)

        guard apiResponse.success, let orderData = apiResponse.data else {
            throw APIError.serverError(message: apiResponse.error ?? "Unknown error", code: nil)
        }

        return orderData
    }

    private func fetchPoDocuments() async {
        // Reset first so a removed-server-side doc can't linger if this fetch fails.
        poDocuments = []
        guard let token = customerAuth.accessToken else { return }
        let url = URL(string: "https://api.repairminder.com/api/customer/orders/\(orderId)/po-documents")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                errorMessage = "Failed to load purchase order documents (error \(code))"
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let apiResponse = try decoder.decode(APIResponse<[PoDocument]>.self, from: data)
            if let docs = apiResponse.data { self.poDocuments = docs }
        } catch {
            errorMessage = "Failed to load purchase order documents"
            #if DEBUG
            print("[CustomerOrderDetailVM] fetchPoDocuments error: \(error)")
            #endif
        }
    }

    func openPoDocument(_ doc: PoDocument) async {
        guard let token = customerAuth.accessToken else { return }
        let url = URL(string: "https://api.repairminder.com/api/customer/orders/\(orderId)/po-documents/\(doc.id)/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                errorMessage = "Failed to download \(doc.filename) (error \(code))"
                return
            }
            // Prefix with the doc id so distinct documents never collide in temp.
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(doc.id)-\(doc.filename)")
            try data.write(to: tmpURL, options: .atomic)
            #if os(iOS)
            poPreviewItem = PoPreviewItem(url: tmpURL)
            #elseif os(macOS)
            NSWorkspace.shared.open(tmpURL)
            #endif
        } catch {
            errorMessage = "Failed to download \(doc.filename)"
            #if DEBUG
            print("[CustomerOrderDetailVM] openPoDocument error: \(error)")
            #endif
        }
    }

    private func submitApproval(action: String, signatureType: String, signatureData: String, amountAcknowledged: Decimal, bankDetails: (accountHolder: String, sortCode: String, accountNumber: String)? = nil) async throws {
        guard let token = customerAuth.accessToken else {
            throw APIError.unauthorized
        }

        let url = URL(string: "https://api.repairminder.com/api/customer/orders/\(orderId)/approve")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "action": action,
            "signature_type": signatureType,
            "signature_data": signatureData,
            "amount_acknowledged": (amountAcknowledged as NSDecimalNumber).doubleValue
        ]

        if let bankDetails = bankDetails {
            body["bank_details"] = [
                "account_holder": bankDetails.accountHolder,
                "sort_code": bankDetails.sortCode.replacingOccurrences(of: "-", with: ""),
                "account_number": bankDetails.accountNumber
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(APIResponse<ApprovalResponse>.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Approval failed", code: nil)
        }
    }

    private func submitRejection(reason: String?, signatureType: String, signatureData: String) async throws {
        guard let token = customerAuth.accessToken else {
            throw APIError.unauthorized
        }

        let url = URL(string: "https://api.repairminder.com/api/customer/orders/\(orderId)/approve")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "action": "reject",
            "signature_type": signatureType,
            "signature_data": signatureData
        ]

        if let reason = reason {
            body["rejection_reason"] = reason
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(APIResponse<ApprovalResponse>.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Rejection failed", code: nil)
        }
    }

    private func submitReply(message: String, deviceId: String? = nil) async throws {
        guard let token = customerAuth.accessToken else {
            throw APIError.unauthorized
        }

        let url = URL(string: "https://api.repairminder.com/api/customer/orders/\(orderId)/reply")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = ["message": message]
        if let deviceId = deviceId {
            body["device_id"] = deviceId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse = try decoder.decode(APIResponse<CustomerReplyResponse>.self, from: data)

        guard apiResponse.success else {
            throw APIError.serverError(message: apiResponse.error ?? "Failed to send message", code: nil)
        }
    }

    // MARK: - Computed Properties

    /// Currency code for formatting
    var currencyCode: String {
        order?.currencyCode ?? "GBP"
    }

    /// Format a decimal amount with currency symbol
    func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: amount as NSDecimalNumber) ?? "£\(amount)"
    }

    /// Whether the order can be approved
    var canApprove: Bool {
        guard let order = order else { return false }
        return order.isAwaitingAction
    }

    /// Whether to show approval button
    var showApprovalButton: Bool {
        canApprove
    }
}

// MARK: - Response Models

private struct ApprovalResponse: Decodable {
    let message: String?
    let approvedAt: String?  // Keep as String since we don't need to parse it
    let rejectedAt: String?
    let signatureId: String?

    // Note: Using automatic snake_case conversion via decoder.keyDecodingStrategy
    enum CodingKeys: String, CodingKey {
        case message, approvedAt, rejectedAt, signatureId
    }
}
