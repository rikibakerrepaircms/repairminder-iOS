//
//  DeviceInfoCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DeviceInfoCard: View {
    let device: Device
    @State private var showPasscode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Device Info", systemImage: "info.circle")
                .font(.headline)

            VStack(spacing: 0) {
                if let serial = device.serial, !serial.isEmpty {
                    InfoRow(label: "Serial Number", value: serial, icon: "number")
                    Divider()
                }

                if let imei = device.imei, !imei.isEmpty {
                    InfoRow(label: "IMEI", value: imei, icon: "barcode")
                    Divider()
                }

                if let passcode = device.passcode, !passcode.isEmpty {
                    PasscodeRow(
                        passcode: passcode,
                        showPasscode: $showPasscode
                    )
                }

                if device.serial == nil && device.imei == nil && device.passcode == nil {
                    Text("No additional info provided")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}

private struct PasscodeRow: View {
    let passcode: String
    @Binding var showPasscode: Bool

    var body: some View {
        HStack {
            Label("Passcode", systemImage: "lock.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if showPasscode {
                Text(passcode)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            } else {
                Text(String(repeating: "•", count: passcode.count))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Button {
                showPasscode.toggle()
            } label: {
                Image(systemName: showPasscode ? "eye.slash.fill" : "eye.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        DeviceInfoCard(device: Device(
            id: "1",
            orderId: "order1",
            type: "iPhone",
            brand: "Apple",
            model: "iPhone 14 Pro",
            serial: "ABCD1234567890",
            imei: "123456789012345",
            passcode: "1234",
            status: .inRepair,
            issue: nil,
            diagnosis: nil,
            resolution: nil,
            price: nil,
            assignedUserId: nil,
            assignedUserName: nil,
            createdAt: Date(),
            updatedAt: Date()
        ))

        DeviceInfoCard(device: Device(
            id: "2",
            orderId: "order1",
            type: "iPad",
            brand: "Apple",
            model: "iPad Air",
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
    .background(Color(.systemGroupedBackground))
}
