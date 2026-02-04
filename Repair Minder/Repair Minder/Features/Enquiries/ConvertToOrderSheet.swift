//
//  ConvertToOrderSheet.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ConvertToOrderSheet: View {
    let enquiry: Enquiry
    let onConvert: (ConvertOrderData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedServices: Set<String> = []
    @State private var estimatedPrice = ""
    @State private var notes = ""
    @State private var priority: OrderPriority = .normal
    @State private var assignedTechnician: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                // Customer Info (read-only)
                Section("Customer") {
                    LabeledContent("Name", value: enquiry.customerName)
                    LabeledContent("Email", value: enquiry.customerEmail)
                    if let phone = enquiry.customerPhone {
                        LabeledContent("Phone", value: phone)
                    }
                }

                // Device Info (read-only)
                Section("Device") {
                    LabeledContent("Type", value: enquiry.deviceType.displayName)
                    LabeledContent("Brand", value: enquiry.deviceBrand)
                    LabeledContent("Model", value: enquiry.deviceModel)
                    if let imei = enquiry.imei {
                        LabeledContent("IMEI", value: imei)
                    }
                }

                // Issue (read-only)
                Section("Reported Issue") {
                    Text(enquiry.issueDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Services
                Section("Services") {
                    ForEach(ServiceType.allCases, id: \.self) { service in
                        Toggle(isOn: Binding(
                            get: { selectedServices.contains(service.rawValue) },
                            set: { isSelected in
                                if isSelected {
                                    selectedServices.insert(service.rawValue)
                                } else {
                                    selectedServices.remove(service.rawValue)
                                }
                            }
                        )) {
                            Label(service.displayName, systemImage: service.icon)
                        }
                    }
                }

                // Quote
                Section("Initial Quote") {
                    HStack {
                        Text("£")
                        TextField("Estimated Price", text: $estimatedPrice)
                            .keyboardType(.decimalPad)
                    }
                }

                // Priority & Assignment
                Section("Order Details") {
                    Picker("Priority", selection: $priority) {
                        ForEach(OrderPriority.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }

                    // TODO: Add technician picker when staff list is available
                }

                // Notes
                Section("Internal Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Create Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        submitOrder()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private func submitOrder() {
        isSubmitting = true

        let data = ConvertOrderData(
            enquiryId: enquiry.id,
            services: Array(selectedServices),
            estimatedPrice: Decimal(string: estimatedPrice),
            priority: priority,
            assignedTechnician: assignedTechnician,
            notes: notes
        )

        onConvert(data)
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
        imei: "352789102345678",
        issueDescription: "Screen is cracked and touch doesn't work in some areas. Device also has battery issues - drains very quickly.",
        preferredContact: "email",
        status: .pending,
        isRead: true,
        replyCount: 2,
        lastReply: nil,
        createdAt: Date(),
        updatedAt: Date(),
        convertedOrderId: nil
    )

    ConvertToOrderSheet(
        enquiry: sampleEnquiry,
        onConvert: { data in
            print("Converting with data: \(data)")
        }
    )
}
