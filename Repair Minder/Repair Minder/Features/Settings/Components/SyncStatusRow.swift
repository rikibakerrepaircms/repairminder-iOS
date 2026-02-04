//
//  SyncStatusRow.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct SyncStatusRow: View {
    let status: SyncEngine.SyncStatus
    let lastSyncDate: Date?
    let pendingCount: Int

    var body: some View {
        HStack {
            Label {
                Text("Sync Status")
            } icon: {
                statusIcon
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)

                if pendingCount > 0 && !status.isInProgress {
                    Text("\(pendingCount) pending")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sync Status: \(statusText)")
        .accessibilityHint(pendingCount > 0 ? "\(pendingCount) changes pending upload" : "")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle, .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
                .scaleEffect(0.8)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
        }
    }

    private var statusText: String {
        switch status {
        case .idle:
            if let lastSync = lastSyncDate {
                return "Last sync: \(lastSync.relativeFormatted())"
            }
            return "Ready"
        case .syncing(let progress):
            return "Syncing \(Int(progress * 100))%"
        case .completed:
            return "Complete"
        case .error(let message):
            return message
        case .offline:
            return "Offline"
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle, .completed:
            return .secondary
        case .syncing:
            return .blue
        case .error:
            return .red
        case .offline:
            return .orange
        }
    }
}

#Preview {
    List {
        SyncStatusRow(
            status: .idle,
            lastSyncDate: Date().addingTimeInterval(-300),
            pendingCount: 0
        )

        SyncStatusRow(
            status: .syncing(progress: 0.45),
            lastSyncDate: nil,
            pendingCount: 3
        )

        SyncStatusRow(
            status: .offline,
            lastSyncDate: Date().addingTimeInterval(-3600),
            pendingCount: 5
        )

        SyncStatusRow(
            status: .error("Network timeout"),
            lastSyncDate: nil,
            pendingCount: 2
        )
    }
}
