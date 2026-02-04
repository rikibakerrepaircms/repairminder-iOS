//
//  DevicesSection.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DevicesSection: View {
    let devices: [Device]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Devices (\(devices.count))", systemImage: "iphone")
                .font(.headline)

            if devices.isEmpty {
                Text("No devices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(devices) { device in
                    DeviceListItem(device: device)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DevicesSection(devices: [
        Device(
            id: "1",
            orderId: "order1",
            type: "iPhone",
            brand: "Apple",
            model: "iPhone 14 Pro",
            serial: nil,
            imei: nil,
            passcode: nil,
            status: .inRepair,
            issue: "Cracked screen",
            diagnosis: nil,
            resolution: nil,
            price: 150.00,
            assignedUserId: nil,
            assignedUserName: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Device(
            id: "2",
            orderId: "order1",
            type: "iPad",
            brand: "Apple",
            model: "iPad Air",
            serial: nil,
            imei: nil,
            passcode: nil,
            status: .awaitingParts,
            issue: "Battery replacement",
            diagnosis: nil,
            resolution: nil,
            price: 80.00,
            assignedUserId: nil,
            assignedUserName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    ])
    .padding()
    .background(Color(.systemGroupedBackground))
}
