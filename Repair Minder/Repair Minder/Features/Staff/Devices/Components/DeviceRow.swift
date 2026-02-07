//
//  DeviceRow.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Row

/// Row component for device list
struct DeviceRow: View {
    let device: DeviceListItem
    var showClient: Bool = true
    var showOrderNumber: Bool = true
    var isWide: Bool = false

    var body: some View {
        if isWide {
            wideLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(alignment: .top) {
                // Device info
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    if showClient, let clientName = device.clientName {
                        Text(clientName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status badge
                DeviceStatusBadge(status: device.deviceStatus)
            }

            // Identifiers row
            HStack(spacing: 12) {
                if showOrderNumber, let orderNumber = device.orderNumber {
                    Label(orderNumber, systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let serial = device.serialNumber {
                    Label(serial, systemImage: "barcode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let imei = device.imei {
                    Label(imei, systemImage: "simcard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Metadata row
            HStack(spacing: 12) {
                // Workflow type
                WorkflowTypeBadge(workflowType: device.workflow)

                // Device type
                if let deviceType = device.deviceType {
                    Label(deviceType.name, systemImage: "iphone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Assigned engineer
                if let engineer = device.assignedEngineer {
                    Label(engineer.name, systemImage: "person")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Overdue indicator
                if device.isOverdue {
                    OverdueBadge()
                } else if let dueDate = device.formattedDueDate {
                    Label(dueDate, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Notes preview (if any)
            if let notePreview = device.notePreview {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.orange)

                    Text(notePreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }

            // Sub-location (if assigned)
            if let subLocation = device.subLocation {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .font(.caption2)
                        .foregroundStyle(.blue)

                    Text(subLocation.code)
                        .font(.caption)
                        .foregroundStyle(.blue)

                    if let description = subLocation.description {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Wide Layout (iPad)

    private var wideLayout: some View {
        HStack(spacing: 16) {
            // Device name + client
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if showClient, let clientName = device.clientName {
                    Text(clientName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 160, alignment: .leading)

            // Device type
            if let deviceType = device.deviceType {
                Label(deviceType.name, systemImage: "iphone")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 100, alignment: .leading)
            }

            // Status badge
            DeviceStatusBadge(status: device.deviceStatus)

            // Workflow type
            WorkflowTypeBadge(workflowType: device.workflow)

            // Assigned engineer
            if let engineer = device.assignedEngineer {
                Label(engineer.name, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Sub-location
            if let subLocation = device.subLocation {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(subLocation.code)
                        .font(.caption)
                }
                .foregroundStyle(.blue)
            }

            // Due / overdue
            if device.isOverdue {
                OverdueBadge()
            } else if let dueDate = device.formattedDueDate {
                Label(dueDate, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Compact Device Row

/// Compact row for device list (used in scanner results, etc.)
struct CompactDeviceRow: View {
    let device: DeviceListItem

    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 40)

            // Device info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let orderNumber = device.orderNumber {
                    Text(orderNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status badge
            DeviceStatusBadge(status: device.deviceStatus, size: .small)
        }
        .padding(.vertical, 4)
    }

    private var deviceIcon: String {
        switch device.deviceType?.slug {
        case "smartphone", "phone": return "iphone"
        case "tablet": return "ipad"
        case "laptop": return "laptopcomputer"
        case "watch": return "applewatch"
        default: return "desktopcomputer"
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        Section("Full Device Row") {
            DeviceRow(
                device: DeviceListItem(
                    id: "1",
                    orderId: "order-1",
                    ticketId: "ticket-1",
                    orderNumber: "RM-12345",
                    clientFirstName: "John",
                    clientLastName: "Doe",
                    displayName: "iPhone 14 Pro",
                    serialNumber: "ABC123DEF456",
                    imei: "123456789012345",
                    colour: "Space Black",
                    status: "diagnosing",
                    workflowType: "repair",
                    deviceType: DeviceTypeInfo(id: "1", name: "Smartphone", slug: "smartphone"),
                    assignedEngineer: AssignedEngineerInfo(id: "1", name: "Jane Smith"),
                    locationId: "loc-1",
                    subLocationId: "subloc-1",
                    subLocation: SubLocationInfo(id: "subloc-1", code: "BENCH-A1", description: "Repair Bench", type: "bench", locationId: "loc-1"),
                    receivedAt: "2026-02-01T10:30:00Z",
                    dueDate: "2026-02-05T17:00:00Z",
                    createdAt: "2026-02-01T10:30:00Z",
                    notes: [DeviceNote(body: "Customer mentioned water damage", createdAt: "2026-02-01T11:00:00Z", createdBy: "Jane Smith", deviceId: "1")],
                    source: "order"
                )
            )
        }

        Section("Compact Device Row") {
            CompactDeviceRow(
                device: DeviceListItem(
                    id: "2",
                    orderId: "order-2",
                    ticketId: nil,
                    orderNumber: "RM-12346",
                    clientFirstName: "Jane",
                    clientLastName: "Smith",
                    displayName: "Samsung Galaxy S24",
                    serialNumber: nil,
                    imei: "987654321098765",
                    colour: "Phantom Black",
                    status: "repairing",
                    workflowType: "repair",
                    deviceType: DeviceTypeInfo(id: "1", name: "Smartphone", slug: "smartphone"),
                    assignedEngineer: nil,
                    locationId: nil,
                    subLocationId: nil,
                    subLocation: nil,
                    receivedAt: "2026-02-02T14:00:00Z",
                    dueDate: nil,
                    createdAt: "2026-02-02T14:00:00Z",
                    notes: [],
                    source: "order"
                )
            )
        }
    }
}
