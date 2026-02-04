//
//  DevicesStatusSection.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DevicesStatusSection: View {
    let devices: [CustomerDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Devices")
                .font(.headline)
                .padding(.horizontal)

            ForEach(devices) { device in
                DeviceStatusCard(device: device)
            }
        }
        .padding(.vertical)
    }
}

struct DeviceStatusCard: View {
    let device: CustomerDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Device icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(width: 44, height: 44)

                    Image(systemName: deviceIcon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(device.type.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CustomerDeviceStatusBadge(status: device.status)
            }

            // Issue description
            if let issue = device.issue, !issue.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Issue")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .padding(.top, 4)
            }

            // Price if available
            if let price = device.price, price > 0 {
                HStack {
                    Text("Repair cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(price.formatted(.currency(code: "GBP")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var deviceIcon: String {
        switch device.type.lowercased() {
        case "smartphone", "phone", "mobile":
            return "iphone"
        case "tablet", "ipad":
            return "ipad"
        case "laptop":
            return "laptopcomputer"
        case "desktop", "computer":
            return "desktopcomputer"
        case "console", "game":
            return "gamecontroller.fill"
        case "watch", "smartwatch":
            return "applewatch"
        default:
            return "cpu"
        }
    }
}

struct CustomerDeviceStatusBadge: View {
    let status: CustomerDeviceStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

#Preview {
    DevicesStatusSection(devices: [])
}
