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

                if let issue = device.issue {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                DeviceStatusBadge(status: device.status)

                if let price = device.price {
                    Text(formatCurrency(price))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GBP"
        return formatter.string(from: value as NSDecimalNumber) ?? "£0"
    }
}

#Preview {
    VStack {
        DeviceListItem(device: Device(
            id: "1",
            orderId: "order1",
            type: "iPhone",
            brand: "Apple",
            model: "iPhone 14 Pro",
            serial: nil,
            imei: nil,
            passcode: nil,
            status: .inRepair,
            issue: "Cracked screen - needs full display replacement",
            diagnosis: nil,
            resolution: nil,
            price: 150.00,
            assignedUserId: nil,
            assignedUserName: nil,
            createdAt: Date(),
            updatedAt: Date()
        ))

        DeviceListItem(device: Device(
            id: "2",
            orderId: "order1",
            type: "Phone",
            brand: nil,
            model: nil,
            serial: nil,
            imei: nil,
            passcode: nil,
            status: .bookedIn,
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
}
