//
//  BuybackStatusHelpers.swift
//  Repair Minder
//
//  Created on 20/02/2026.
//

import SwiftUI

// MARK: - Status Color

/// Maps a buyback status string to its display color (matches web frontend).
func buybackStatusColor(_ status: String) -> Color {
    switch status {
    case "purchased": return .blue
    case "awaiting_parts": return .yellow
    case "ready_to_repair": return .purple
    case "refurbishing": return .orange
    case "for_sale": return .green
    case "sold": return .gray
    case "salvaged": return .secondary
    default: return .gray
    }
}

// MARK: - Status Badge

/// Capsule badge displaying the buyback status with matching color.
struct BuybackStatusBadge: View {
    let status: String

    private var displayName: String {
        BuybackStatus(rawValue: status)?.displayName ?? status
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var body: some View {
        Text(displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(buybackStatusColor(status).opacity(0.15))
            .foregroundStyle(buybackStatusColor(status))
            .clipShape(Capsule())
    }
}

// MARK: - Status Transitions

/// Valid next statuses for a manual "change status" action. `sold` is never
/// offered here — that transition only happens via the Sell flow. `sold` and
/// `salvaged` are terminal (no further manual transitions).
func nextBuybackStatuses(for status: BuybackStatus) -> [BuybackStatus] {
    switch status {
    case .purchased:
        return [.awaitingParts, .readyToRepair, .forSale]
    case .awaitingParts:
        return [.readyToRepair]
    case .readyToRepair:
        return [.refurbishing, .forSale]
    case .refurbishing:
        return [.forSale, .awaitingParts, .readyToRepair]
    case .forSale:
        return [.salvaged, .refurbishing, .readyToRepair]
    case .sold, .salvaged, .unknown:
        return []
    }
}
