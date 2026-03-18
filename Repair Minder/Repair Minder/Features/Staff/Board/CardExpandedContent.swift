//
//  CardExpandedContent.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Card Expanded Content

/// Expanded card body showing device details, identifiers, notes, and CTA buttons.
/// Displayed below the card header when a card is tapped in the wallet stack.
struct CardExpandedContent: View {
    let device: BoardDeviceItem
    var onViewDetails: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            // Status & workflow badges
            HStack(spacing: 6) {
                StatusBadge(status: device.deviceStatus)

                if !device.workflowType.isEmpty {
                    Text(device.workflowType.capitalized)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }

            // Engineer
            if let engineerName = device.engineerName {
                HStack(spacing: 6) {
                    if let engineerId = device.engineerId {
                        Circle()
                            .fill(EngineerColors.color(for: engineerId))
                            .frame(width: 10, height: 10)
                    }
                    Text(engineerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Identifiers
            if device.serialNumber != nil || device.imei != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let serial = device.serialNumber {
                        HStack(spacing: 4) {
                            Text("S/N")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                            Text(serial)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if let imei = device.imei {
                        HStack(spacing: 4) {
                            Text("IMEI")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                            Text(imei)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            // Notes preview
            if let note = device.notePreview {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.platformGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // CTA buttons
            HStack(spacing: 8) {
                Button {
                    onViewDetails?()
                } label: {
                    Text("View Details")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: DeviceStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.backgroundColor)
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}
