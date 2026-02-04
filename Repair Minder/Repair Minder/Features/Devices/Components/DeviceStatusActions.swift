//
//  DeviceStatusActions.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DeviceStatusActions: View {
    let currentStatus: DeviceStatus
    let isUpdating: Bool
    let onStatusChange: (DeviceStatus) -> Void

    var body: some View {
        if !nextStatuses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Update Status")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(nextStatuses, id: \.self) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            if isUpdating {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                HStack {
                                    Image(systemName: iconForStatus(status))
                                    Text(status.displayName)
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colorForStatus(status))
                        .disabled(isUpdating)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var nextStatuses: [DeviceStatus] {
        switch currentStatus {
        case .bookedIn:
            return [.diagnosing]
        case .diagnosing:
            return [.awaitingApproval, .unrepairable]
        case .awaitingApproval:
            return [.approved]
        case .approved:
            return [.inRepair, .awaitingParts]
        case .inRepair:
            return [.awaitingParts, .repaired]
        case .awaitingParts:
            return [.inRepair]
        case .repaired:
            return [.qualityCheck]
        case .qualityCheck:
            return [.ready, .inRepair]
        case .ready:
            return [.collected]
        case .collected, .unrepairable:
            return []
        }
    }

    private func colorForStatus(_ status: DeviceStatus) -> Color {
        switch status {
        case .diagnosing:
            return .purple
        case .awaitingApproval:
            return .orange
        case .approved:
            return .teal
        case .inRepair:
            return .indigo
        case .awaitingParts:
            return .yellow
        case .repaired:
            return .mint
        case .qualityCheck:
            return .cyan
        case .ready:
            return .green
        case .collected:
            return .gray
        case .unrepairable:
            return .red
        default:
            return .blue
        }
    }

    private func iconForStatus(_ status: DeviceStatus) -> String {
        switch status {
        case .bookedIn:
            return "tray.and.arrow.down.fill"
        case .diagnosing:
            return "magnifyingglass"
        case .awaitingApproval:
            return "clock.fill"
        case .approved:
            return "checkmark.circle.fill"
        case .inRepair:
            return "wrench.and.screwdriver.fill"
        case .awaitingParts:
            return "shippingbox.fill"
        case .repaired:
            return "checkmark.seal.fill"
        case .qualityCheck:
            return "checklist"
        case .ready:
            return "hand.thumbsup.fill"
        case .collected:
            return "bag.fill"
        case .unrepairable:
            return "xmark.circle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DeviceStatusActions(
            currentStatus: .bookedIn,
            isUpdating: false,
            onStatusChange: { _ in }
        )

        DeviceStatusActions(
            currentStatus: .diagnosing,
            isUpdating: false,
            onStatusChange: { _ in }
        )

        DeviceStatusActions(
            currentStatus: .inRepair,
            isUpdating: false,
            onStatusChange: { _ in }
        )

        DeviceStatusActions(
            currentStatus: .qualityCheck,
            isUpdating: true,
            onStatusChange: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
