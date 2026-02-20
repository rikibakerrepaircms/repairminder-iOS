//
//  PosModels.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import Foundation

// MARK: - POS Integration

struct PosIntegration: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let provider: String           // "revolut", "square", "sumup", "dojo"
    let displayName: String?
    let environment: String?       // "production", "sandbox"
    let isEnabled: Bool?           // Backend field is "is_enabled" (not "is_active")
    let isVerified: Bool?
    let config: PosIntegrationConfig?
}

struct PosIntegrationConfig: Decodable, Equatable, Sendable {
    let locationId: String?
}

// MARK: - POS Terminal

struct PosTerminal: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let integrationId: String?
    let providerTerminalId: String?
    let displayName: String
    let provider: String           // "revolut", "square", "sumup", "dojo"
    let isActive: Bool?

    var providerLabel: String {
        switch provider {
        case "revolut": return "Revolut"
        case "square": return "Square"
        case "sumup": return "SumUp"
        case "dojo": return "Dojo"
        default: return provider.capitalized
        }
    }

    var providerIcon: String {
        switch provider {
        case "revolut": return "creditcard.trianglebadge.exclamationmark"
        case "square": return "square"
        case "sumup": return "wave.3.right"
        case "dojo": return "creditcard"
        default: return "creditcard"
        }
    }
}

// MARK: - POS Transaction Status

enum PosTransactionStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
    case timeout

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .timeout: return true
        case .pending, .processing: return false
        }
    }

    var label: String {
        switch self {
        case .pending: return "Waiting for card..."
        case .processing: return "Processing..."
        case .completed: return "Payment Successful"
        case .failed: return "Payment Failed"
        case .cancelled: return "Payment Cancelled"
        case .timeout: return "Payment Timed Out"
        }
    }
}

// MARK: - POS Transaction (poll response)

struct PosTransactionPollResponse: Decodable, Sendable {
    let transactionId: String
    let status: PosTransactionStatus
    let providerTransactionId: String?
    let cardBrand: String?
    let cardLastFour: String?
    let authCode: String?
    let failureReason: String?
    let completedAt: String?
    // Note: orderId, amount, currency, createdAt are NOT returned by the poll endpoint
}

// MARK: - Initiate Terminal Payment

struct InitiateTerminalPaymentRequest: Encodable {
    let orderId: String
    let terminalId: String
    let amount: Int              // pence
    let currency: String
    let deviceIds: [String]?
    // Note: is_deposit is NOT read by the POS backend — deposit handling
    // is done server-side when the POS payment completes and creates an order_payment
}

struct InitiateTerminalPaymentResponse: Decodable, Sendable {
    let transactionId: String
    let providerOrderId: String?
    let paymentIntentId: String?
    let status: String?
    // Note: provider and terminalId are NOT returned by the backend
}

// MARK: - Payment Link

struct PosPaymentLink: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let provider: String?
    let checkoutUrl: String
    let amount: Int              // pence
    let currency: String?
    let status: PaymentLinkStatus
    let createdAt: String?
    let completedAt: String?
    let cancelledAt: String?
    let lastEmailSentAt: String?

    var formattedAmount: String {
        CurrencyFormatter.format(Double(amount) / 100.0)
    }

    var formattedCreatedAt: String? {
        guard let createdAt else { return nil }
        return DateFormatters.formatRelativeDate(createdAt)
    }
}

enum PaymentLinkStatus: String, Codable, Sendable {
    case pending
    case completed
    case failed
    case cancelled
    case expired
}

struct CreatePaymentLinkRequest: Encodable {
    let orderId: String
    let amount: Int              // pence
    let currency: String
    let customerEmail: String?
    let description: String?
    let deviceIds: [String]?
    // Note: is_deposit is NOT read by the POS backend
}

struct CreatePaymentLinkResponse: Decodable, Sendable {
    let paymentLinkId: String
    let checkoutUrl: String
    let amount: Int
    let currency: String?
    let providerOrderId: String?
    let emailSent: Bool?
    let ticketMessageId: String?
    // Note: alreadyExists is NOT returned by the backend
}
