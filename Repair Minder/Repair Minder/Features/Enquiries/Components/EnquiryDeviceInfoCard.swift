//
//  EnquiryDeviceInfoCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryDeviceInfoCard: View {
    let enquiry: Enquiry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Device Information", systemImage: "iphone")
                .font(.headline)

            HStack(spacing: 16) {
                EnquiryInfoItem(label: "Type", value: enquiry.deviceType.displayName, icon: enquiry.deviceType.icon)
                EnquiryInfoItem(label: "Brand", value: enquiry.deviceBrand, icon: "building.2")
                EnquiryInfoItem(label: "Model", value: enquiry.deviceModel, icon: "tag")
            }

            if let imei = enquiry.imei {
                HStack {
                    Text("IMEI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(imei)
                        .font(.caption.monospaced())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EnquiryInfoItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let sampleEnquiry = Enquiry(
        id: "1",
        customerName: "John Smith",
        customerEmail: "john@example.com",
        customerPhone: nil,
        deviceType: .smartphone,
        deviceBrand: "Apple",
        deviceModel: "iPhone 15 Pro",
        imei: "352789102345678",
        issueDescription: "Screen is cracked",
        preferredContact: nil,
        status: .new,
        isRead: false,
        replyCount: 0,
        lastReply: nil,
        createdAt: Date(),
        updatedAt: Date(),
        convertedOrderId: nil
    )

    EnquiryDeviceInfoCard(enquiry: sampleEnquiry)
        .padding()
}
