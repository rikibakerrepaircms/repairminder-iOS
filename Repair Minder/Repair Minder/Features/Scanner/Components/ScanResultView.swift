//
//  ScanResultView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ScanResultView: View {
    let result: ScannerViewModel.ScanResult
    let onNavigate: (ScannerViewModel.ScanResult) -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success/Result Icon
            resultIcon

            // Result Content
            resultContent

            // Action Buttons
            VStack(spacing: 12) {
                if canNavigate {
                    Button {
                        onNavigate(result)
                    } label: {
                        Label(navigateButtonTitle, systemImage: navigateButtonIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    onRescan()
                } label: {
                    Label("Scan Another", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var resultIcon: some View {
        switch result {
        case .device, .order:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
        case .unknown:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch result {
        case .device(let device):
            DeviceResultContent(device: device)
        case .order(let order):
            OrderResultContent(order: order)
        case .unknown(let code):
            UnknownResultContent(code: code)
        }
    }

    private var canNavigate: Bool {
        switch result {
        case .device, .order:
            return true
        case .unknown:
            return false
        }
    }

    private var navigateButtonTitle: String {
        switch result {
        case .device:
            return "View Device"
        case .order:
            return "View Order"
        case .unknown:
            return ""
        }
    }

    private var navigateButtonIcon: String {
        switch result {
        case .device:
            return "iphone"
        case .order:
            return "doc.text"
        case .unknown:
            return ""
        }
    }
}

// MARK: - Device Result Content
private struct DeviceResultContent: View {
    let device: Device

    var body: some View {
        VStack(spacing: 16) {
            Text("Device Found")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(device.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                DeviceStatusBadge(status: device.status, size: .large)
            }

            if let serial = device.serial, !serial.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "barcode")
                        .foregroundStyle(.secondary)
                    Text(serial)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let issue = device.issue, !issue.isEmpty {
                Text(issue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Order Result Content
private struct OrderResultContent: View {
    let order: Order

    var body: some View {
        VStack(spacing: 16) {
            Text("Order Found")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(order.displayRef)
                    .font(.title)
                    .fontWeight(.bold)

                OrderStatusBadge(status: order.status, size: .large)
            }

            if let clientName = order.clientName, !clientName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person")
                        .foregroundStyle(.secondary)
                    Text(clientName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                if order.deviceCount > 0 {
                    Label("\(order.deviceCount) device\(order.deviceCount == 1 ? "" : "s")",
                          systemImage: "iphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let total = order.total {
                    Label(total.formatted(.currency(code: "GBP")),
                          systemImage: "sterlingsign.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Unknown Result Content
private struct UnknownResultContent: View {
    let code: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Code Scanned")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(code)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("No matching device or order found in the system.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview("Device Found") {
    ScanResultView(
        result: .device(Device(
            id: "1",
            orderId: "1",
            type: "Phone",
            brand: "Apple",
            model: "iPhone 15 Pro",
            serial: "F2LTJG9PNQ",
            imei: nil,
            passcode: nil,
            status: .inRepair,
            issue: "Cracked screen and battery replacement",
            diagnosis: nil,
            resolution: nil,
            price: Decimal(150),
            assignedUserId: nil,
            assignedUserName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )),
        onNavigate: { _ in },
        onRescan: {}
    )
}

#Preview("Order Found") {
    ScanResultView(
        result: .order(Order(
            id: "1",
            orderNumber: 12345,
            status: .inProgress,
            total: Decimal(299.99),
            deposit: Decimal(50),
            balance: Decimal(249.99),
            notes: nil,
            clientId: "1",
            clientName: "John Doe",
            clientEmail: "john@example.com",
            clientPhone: nil,
            locationId: nil,
            locationName: nil,
            assignedUserId: nil,
            assignedUserName: nil,
            deviceCount: 2,
            createdAt: Date(),
            updatedAt: Date()
        )),
        onNavigate: { _ in },
        onRescan: {}
    )
}

#Preview("Unknown Code") {
    ScanResultView(
        result: .unknown("ABC123XYZ"),
        onNavigate: { _ in },
        onRescan: {}
    )
}
