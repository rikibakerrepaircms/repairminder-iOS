//
//  EnquiryStatsHeader.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryStatsHeader: View {
    let stats: EnquiryStats

    var body: some View {
        HStack(spacing: 16) {
            StatPill(
                value: stats.newToday,
                label: "New Today",
                color: .blue,
                icon: "envelope.badge"
            )

            StatPill(
                value: stats.awaitingReply,
                label: "Awaiting Reply",
                color: .orange,
                icon: "clock"
            )

            StatPill(
                value: stats.convertedThisWeek,
                label: "Converted",
                color: .green,
                icon: "checkmark.circle"
            )
        }
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    EnquiryStatsHeader(stats: EnquiryStats(
        newToday: 5,
        awaitingReply: 12,
        convertedThisWeek: 8,
        totalActive: 25
    ))
    .padding()
}
