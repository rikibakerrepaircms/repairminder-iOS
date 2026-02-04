//
//  MyQueueSection.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct MyQueueSection: View {
    let devices: [Device]
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Queue")
                    .font(.headline)

                Spacer()

                Button("See All") {
                    router.selectedTab = .orders
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(devices) { device in
                    MyQueueDeviceRow(device: device)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            router.navigate(to: .deviceDetail(id: device.id))
                        }

                    if device.id != devices.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct MyQueueDeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 40, height: 40)
                .background(statusColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(device.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let issue = device.issue, !issue.isEmpty {
                Text(issue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 100, alignment: .trailing)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var deviceIcon: String {
        switch device.type.lowercased() {
        case "iphone", "phone", "smartphone":
            return "iphone"
        case "ipad", "tablet":
            return "ipad"
        case "macbook", "laptop":
            return "laptopcomputer"
        case "imac", "desktop":
            return "desktopcomputer"
        case "watch", "apple watch":
            return "applewatch"
        default:
            return "wrench.and.screwdriver"
        }
    }

    private var statusColor: Color {
        switch device.status {
        case .bookedIn: return .blue
        case .diagnosing: return .purple
        case .awaitingApproval: return .orange
        case .approved: return .teal
        case .inRepair: return .indigo
        case .awaitingParts: return .yellow
        case .repaired: return .mint
        case .qualityCheck: return .cyan
        case .ready: return .green
        case .collected: return .gray
        case .unrepairable: return .red
        }
    }
}

#Preview {
    MyQueueSection(devices: [])
        .environment(AppRouter())
}
