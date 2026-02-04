//
//  EnquiryHeaderCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryHeaderCard: View {
    let enquiry: Enquiry?

    var body: some View {
        if let enquiry = enquiry {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    CustomerInitialsAvatar(name: enquiry.customerName, size: 60, isNew: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(enquiry.customerName)
                            .font(.title3)
                            .fontWeight(.bold)

                        // Contact buttons
                        HStack(spacing: 12) {
                            if let phone = enquiry.customerPhone {
                                ContactPill(icon: "phone.fill", value: phone, action: .call)
                            }
                            ContactPill(icon: "envelope.fill", value: enquiry.customerEmail, action: .email)
                        }
                    }

                    Spacer()

                    EnquiryStatusPill(status: enquiry.status)
                }

                // Received time
                HStack {
                    Image(systemName: "clock")
                    Text("Received \(enquiry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Spacer()
                    Text(enquiry.createdAt.relativeFormatted())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    let sampleEnquiry = Enquiry(
        id: "1",
        customerName: "John Smith",
        customerEmail: "john@example.com",
        customerPhone: "07123456789",
        deviceType: .smartphone,
        deviceBrand: "Apple",
        deviceModel: "iPhone 15 Pro",
        imei: nil,
        issueDescription: "Screen is cracked",
        preferredContact: "email",
        status: .pending,
        isRead: true,
        replyCount: 0,
        lastReply: nil,
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date(),
        convertedOrderId: nil
    )

    EnquiryHeaderCard(enquiry: sampleEnquiry)
        .padding()
}
