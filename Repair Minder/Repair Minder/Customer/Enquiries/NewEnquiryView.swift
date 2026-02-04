//
//  NewEnquiryView.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct NewEnquiryView: View {
    @State private var viewModel = NewEnquiryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedShop: Shop?
    @State private var deviceType = ""
    @State private var deviceBrand = ""
    @State private var deviceModel = ""
    @State private var issueDescription = ""
    @State private var preferredContact: ContactMethod = .email
    @State private var showShopPicker = false

    enum ContactMethod: String, CaseIterable {
        case email, phone, whatsapp

        var displayName: String {
            switch self {
            case .email: return "Email"
            case .phone: return "Phone Call"
            case .whatsapp: return "WhatsApp"
            }
        }

        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .phone: return "phone.fill"
            case .whatsapp: return "message.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Shop selection
                Section {
                    Button {
                        showShopPicker = true
                    } label: {
                        HStack {
                            if let shop = selectedShop {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shop.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)

                                    if shop.orderCount > 0 {
                                        Text("Used \(shop.orderCount) times")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("Select a repair shop")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Repair Shop")
                } footer: {
                    Text("Choose from shops you've used before")
                }

                // Device info
                Section("Device Information") {
                    Picker("Device Type", selection: $deviceType) {
                        Text("Select type").tag("")
                        Text("Smartphone").tag("smartphone")
                        Text("Tablet").tag("tablet")
                        Text("Laptop").tag("laptop")
                        Text("Desktop").tag("desktop")
                        Text("Game Console").tag("console")
                        Text("Smartwatch").tag("watch")
                        Text("Other").tag("other")
                    }

                    TextField("Brand (e.g., Apple, Samsung)", text: $deviceBrand)
                        .textContentType(.organizationName)
                        .autocorrectionDisabled()

                    TextField("Model (e.g., iPhone 15 Pro)", text: $deviceModel)
                        .autocorrectionDisabled()
                }

                // Issue description
                Section {
                    TextEditor(text: $issueDescription)
                        .frame(minHeight: 100)
                } header: {
                    Text("What's wrong?")
                } footer: {
                    Text("Describe the issue in detail. Include when it started, any error messages, and what you've already tried.")
                }

                // Contact preference
                Section("Preferred Contact Method") {
                    ForEach(ContactMethod.allCases, id: \.self) { method in
                        Button {
                            preferredContact = method
                        } label: {
                            HStack {
                                Image(systemName: method.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(.tint)

                                Text(method.displayName)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if preferredContact == method {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                // Error display
                if let error = viewModel.error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .foregroundStyle(.red)
                        .font(.subheadline)
                    }
                }
            }
            .navigationTitle("New Enquiry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await submitEnquiry()
                        }
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showShopPicker) {
                ShopPickerView(selectedShop: $selectedShop)
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView("Submitting...")
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var isFormValid: Bool {
        selectedShop != nil &&
        !deviceType.isEmpty &&
        !deviceBrand.trimmingCharacters(in: .whitespaces).isEmpty &&
        !issueDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitEnquiry() async {
        guard let shop = selectedShop else { return }

        let success = await viewModel.submitEnquiry(
            shopId: shop.id,
            deviceType: deviceType,
            deviceBrand: deviceBrand,
            deviceModel: deviceModel,
            issue: issueDescription,
            contactMethod: preferredContact.rawValue
        )

        if success {
            dismiss()
        }
    }
}

#Preview {
    NewEnquiryView()
}
