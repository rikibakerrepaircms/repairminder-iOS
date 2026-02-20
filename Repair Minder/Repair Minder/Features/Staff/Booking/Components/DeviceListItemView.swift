//
//  DeviceListItemView.swift
//  Repair Minder
//

import SwiftUI

struct DeviceListItemView: View {
    let device: BookingDeviceEntry
    let defaultWorkflowType: BookingDeviceEntry.WorkflowType
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(workflowColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: workflowIcon)
                        .foregroundStyle(workflowColor)
                }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if device.workflowType != defaultWorkflowType {
                        Text(device.workflowType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(workflowColor.opacity(0.1))
                            .foregroundStyle(workflowColor)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    if !device.serialNumber.isEmpty {
                        Label(device.serialNumber, systemImage: "barcode")
                    }
                    if !device.colour.isEmpty {
                        Label(device.colour, systemImage: "paintpalette")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !device.customerReportedIssues.isEmpty {
                    Text(device.customerReportedIssues)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !device.accessories.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bag")
                        Text("\(device.accessories.count) accessor\(device.accessories.count == 1 ? "y" : "ies")")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding(8)
                }
            }
        }
        .padding()
        .background(Color.platformGray6)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var workflowColor: Color {
        device.workflowType == .buyback ? .green : .blue
    }

    private var workflowIcon: String {
        device.workflowType == .buyback ? "arrow.triangle.2.circlepath" : "wrench.and.screwdriver"
    }
}

#Preview {
    VStack {
        DeviceListItemView(
            device: BookingDeviceEntry(
                id: UUID(),
                brandId: nil,
                modelId: nil,
                customBrand: nil,
                customModel: nil,
                displayName: "iPhone 14 Pro Max",
                serialNumber: "ABC123",
                imei: "",
                colour: "Black",
                storageCapacity: "256GB",
                passcode: "1234",
                passcodeType: .pin,
                findMyStatus: .disabled,
                conditionGrade: .b,
                customerReportedIssues: "Screen cracked, battery drains quickly",
                deviceTypeId: nil,
                workflowType: .repair,
                accessories: []
            ),
            defaultWorkflowType: .repair,
            onEdit: {},
            onRemove: {}
        )
    }
    .padding()
}
