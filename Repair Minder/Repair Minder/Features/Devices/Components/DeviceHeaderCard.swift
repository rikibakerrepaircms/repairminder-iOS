//
//  DeviceHeaderCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DeviceHeaderCard: View {
    let device: Device

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: deviceIcon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text(device.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(device.type)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DeviceStatusBadge(status: device.status)

            Text("Created \(device.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let assignedName = device.assignedUserName {
                Label(assignedName, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var deviceIcon: String {
        let type = device.type.lowercased()
        if type.contains("iphone") || type.contains("phone") {
            return "iphone"
        } else if type.contains("ipad") || type.contains("tablet") {
            return "ipad"
        } else if type.contains("macbook") || type.contains("laptop") {
            return "laptopcomputer"
        } else if type.contains("imac") || type.contains("desktop") || type.contains("mac") {
            return "desktopcomputer"
        } else if type.contains("watch") {
            return "applewatch"
        } else if type.contains("airpod") || type.contains("headphone") {
            return "airpodspro"
        } else {
            return "iphone"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DeviceHeaderCard(device: Device(
            id: "1",
            orderId: "order1",
            type: "iPhone",
            brand: "Apple",
            model: "iPhone 14 Pro",
            serial: "ABC123",
            imei: nil,
            passcode: nil,
            status: .inRepair,
            issue: "Cracked screen",
            diagnosis: nil,
            resolution: nil,
            price: 150.00,
            assignedUserId: "user1",
            assignedUserName: "John Smith",
            createdAt: Date(),
            updatedAt: Date()
        ))

        DeviceHeaderCard(device: Device(
            id: "2",
            orderId: "order1",
            type: "MacBook",
            brand: "Apple",
            model: "MacBook Pro 14\"",
            serial: nil,
            imei: nil,
            passcode: nil,
            status: .awaitingParts,
            issue: nil,
            diagnosis: nil,
            resolution: nil,
            price: nil,
            assignedUserId: nil,
            assignedUserName: nil,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
