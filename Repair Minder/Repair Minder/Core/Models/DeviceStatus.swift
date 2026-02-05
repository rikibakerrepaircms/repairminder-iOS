//
//  DeviceStatus.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Status

/// Device workflow status matching backend device-workflows.js
/// Handles both repair and buyback workflow statuses
enum DeviceStatus: String, Codable, CaseIterable, Sendable {
    // Common statuses (both workflows)
    case deviceReceived = "device_received"
    case diagnosing = "diagnosing"
    case readyToQuote = "ready_to_quote"
    case companyRejected = "company_rejected"
    case awaitingAuthorisation = "awaiting_authorisation"
    case rejected = "rejected"
    case rejectionQc = "rejection_qc"
    case rejectionReady = "rejection_ready"
    case collected = "collected"
    case despatched = "despatched"

    // Repair workflow specific
    case authorisedSourceParts = "authorised_source_parts"
    case authorisedAwaitingParts = "authorised_awaiting_parts"
    case readyToRepair = "ready_to_repair"
    case repairing = "repairing"
    case awaitingRevisedQuote = "awaiting_revised_quote"
    case repairedQc = "repaired_qc"
    case repairedReady = "repaired_ready"

    // Buyback workflow specific
    case readyToPay = "ready_to_pay"
    case paymentMade = "payment_made"
    case addedToBuyback = "added_to_buyback"

    // MARK: - Display Properties

    /// Human-readable label for the status
    var label: String {
        switch self {
        case .deviceReceived: return "Received"
        case .diagnosing: return "Being Assessed"
        case .readyToQuote: return "Quote Ready"
        case .awaitingAuthorisation: return "Awaiting Approval"
        case .authorisedSourceParts: return "Sourcing Parts"
        case .authorisedAwaitingParts: return "Awaiting Parts"
        case .readyToRepair: return "Repair Scheduled"
        case .repairing: return "Being Repaired"
        case .awaitingRevisedQuote: return "Revised Quote"
        case .repairedQc: return "Quality Check"
        case .repairedReady: return "Ready for Collection"
        case .readyToPay: return "Payment Processing"
        case .paymentMade: return "Payment Complete"
        case .addedToBuyback: return "Added to Buyback"
        case .rejected: return "Quote Declined"
        case .companyRejected: return "Assessment Failed"
        case .rejectionQc: return "Preparing Return"
        case .rejectionReady: return "Ready for Return"
        case .collected: return "Collected"
        case .despatched: return "Despatched"
        }
    }

    /// Color for status badge
    var color: Color {
        switch self {
        case .deviceReceived: return .gray
        case .diagnosing: return .purple
        case .readyToQuote: return .indigo
        case .awaitingAuthorisation: return .yellow
        case .authorisedSourceParts: return .orange
        case .authorisedAwaitingParts: return .orange
        case .readyToRepair: return .cyan
        case .repairing: return .teal
        case .awaitingRevisedQuote: return .yellow
        case .repairedQc: return .pink
        case .repairedReady: return .green
        case .readyToPay: return .blue
        case .paymentMade: return Color(red: 0.2, green: 0.8, blue: 0.4) // emerald
        case .addedToBuyback: return Color(red: 0.55, green: 0.35, blue: 0.85) // violet
        case .rejected: return .red
        case .companyRejected: return .orange
        case .rejectionQc: return .pink
        case .rejectionReady: return .green
        case .collected: return Color(red: 0.2, green: 0.8, blue: 0.4) // emerald
        case .despatched: return Color(red: 0.2, green: 0.8, blue: 0.4) // emerald
        }
    }

    /// Background color for status badge (lighter tint)
    var backgroundColor: Color {
        color.opacity(0.15)
    }

    // MARK: - Status Categories

    /// Whether this is a terminal status (no further transitions)
    var isTerminal: Bool {
        switch self {
        case .collected, .despatched, .addedToBuyback:
            return true
        default:
            return false
        }
    }

    /// Whether service is complete for this status
    var isServiceComplete: Bool {
        switch self {
        case .repairedReady, .paymentMade, .addedToBuyback,
             .rejected, .companyRejected, .rejectionQc, .rejectionReady,
             .collected, .despatched:
            return true
        default:
            return false
        }
    }

    /// Whether device is ready for collection
    var isReadyForCollection: Bool {
        switch self {
        case .repairedReady, .paymentMade, .rejectionReady:
            return true
        default:
            return false
        }
    }

    /// Whether this status indicates active work in progress
    var isActiveWork: Bool {
        switch self {
        case .diagnosing, .repairing:
            return true
        default:
            return false
        }
    }

    // MARK: - Workflow Type

    /// Statuses available in repair workflow
    static var repairStatuses: [DeviceStatus] {
        [
            .deviceReceived, .diagnosing, .readyToQuote, .companyRejected,
            .awaitingAuthorisation, .authorisedSourceParts, .authorisedAwaitingParts,
            .readyToRepair, .repairing, .awaitingRevisedQuote, .repairedQc, .repairedReady,
            .rejected, .rejectionQc, .rejectionReady, .collected, .despatched
        ]
    }

    /// Statuses available in buyback workflow
    static var buybackStatuses: [DeviceStatus] {
        [
            .deviceReceived, .diagnosing, .companyRejected, .readyToQuote,
            .awaitingAuthorisation, .readyToPay, .paymentMade, .addedToBuyback,
            .rejected, .rejectionQc, .rejectionReady, .collected, .despatched
        ]
    }
}

// MARK: - Device Workflow Type

/// Type of workflow for a device
enum DeviceWorkflowType: String, Codable, Sendable {
    case repair
    case buyback

    var displayName: String {
        switch self {
        case .repair: return "Repair"
        case .buyback: return "Buyback"
        }
    }

    var icon: String {
        switch self {
        case .repair: return "wrench.and.screwdriver"
        case .buyback: return "arrow.triangle.2.circlepath"
        }
    }
}
