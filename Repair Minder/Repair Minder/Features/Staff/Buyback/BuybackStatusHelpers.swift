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
