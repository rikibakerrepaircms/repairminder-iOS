//
//  StatusActionsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct StatusActionsView: View {
    let currentStatus: OrderStatus
    let isUpdating: Bool
    let onStatusChange: (OrderStatus) -> Void

    var nextStatuses: [OrderStatus] {
        switch currentStatus {
        case .awaitingDevice:
            return [.inProgress]
        case .inProgress:
            return [.serviceComplete]
        case .serviceComplete:
            return [.awaitingCollection]
        case .awaitingCollection:
            return [.collectedDespatched]
        case .collectedDespatched:
            return []
        // Legacy statuses
        case .bookedIn:
            return [.inProgress]
        case .awaitingParts:
            return [.inProgress]
        case .ready:
            return [.collected]
        case .collected, .complete, .cancelled, .unknown:
            return []
        }
    }

    var body: some View {
        if !nextStatuses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Update Status")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(nextStatuses, id: \.self) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            if isUpdating {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            } else {
                                Text(status.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(buttonColor(for: status))
                        .disabled(isUpdating)
                    }
                }

                if currentStatus != .cancelled {
                    Button {
                        onStatusChange(.cancelled)
                    } label: {
                        Text("Cancel Order")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isUpdating)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func buttonColor(for status: OrderStatus) -> Color {
        switch status {
        case .inProgress: return .orange
        case .awaitingParts: return .yellow
        case .ready: return .green
        case .collected: return .blue
        default: return .blue
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusActionsView(
            currentStatus: .bookedIn,
            isUpdating: false,
            onStatusChange: { _ in }
        )

        StatusActionsView(
            currentStatus: .inProgress,
            isUpdating: false,
            onStatusChange: { _ in }
        )

        StatusActionsView(
            currentStatus: .ready,
            isUpdating: true,
            onStatusChange: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
