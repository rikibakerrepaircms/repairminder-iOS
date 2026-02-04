//
//  DeviceListItem.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DeviceListItem: View {
    let device: Device

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let serial = device.serialNumber, !serial.isEmpty {
                    Text("S/N: \(serial)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                DeviceStatusBadge(status: device.status)

                if let assignedName = device.assignedUserName, !assignedName.isEmpty {
                    Text(assignedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    VStack {
        DeviceListItem(device: .sample)
        DeviceListItem(device: .sampleMacBook)
    }
    .padding()
}
