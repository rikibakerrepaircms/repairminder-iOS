//
//  RecreateOrderSheet.swift
//  Repair Minder
//
//  Recreates an order via POST /api/orders/:id/recreate (admin only). This
//  cancels the original order and creates a new one, copying devices/items
//  across. Prefilled from the order's client. Follows the same
//  `(Request) async -> String?` sheet convention as OrderDiscountSheet.
//

import SwiftUI

struct RecreateOrderSheet: View {
    let client: OrderClient?
    let onRecreate: (RecreateOrderRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var busy = false
    @State private var errorText: String?

    init(client: OrderClient?, onRecreate: @escaping (RecreateOrderRequest) async -> String?) {
        self.client = client
        self.onRecreate = onRecreate
        _email = State(initialValue: client?.email ?? "")
        _firstName = State(initialValue: client?.firstName ?? "")
        _lastName = State(initialValue: client?.lastName ?? "")
        _phone = State(initialValue: client?.phone ?? "")
    }

    // MARK: - Validation

    private var isValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        #endif
                        .accessibilityIdentifier("recreate-email")
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                    TextField("Phone", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                } header: {
                    Text("New Order Client")
                } footer: {
                    Text("This cancels the original order and creates a new order with the same devices and items.")
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Recreate Order")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Recreate") {
                        Task { await recreate() }
                    }
                    .disabled(busy || !isValid)
                    .accessibilityIdentifier("recreate-confirm")
                }
            }
            .disabled(busy)
        }
    }

    // MARK: - Recreate

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func recreate() async {
        guard isValid else { return }
        busy = true
        defer { busy = false }

        let request = RecreateOrderRequest(
            clientEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
            clientFirstName: nonEmpty(firstName),
            clientLastName: nonEmpty(lastName),
            clientPhone: nonEmpty(phone),
            locationId: nil,
            assignedUserId: nil
        )

        if let error = await onRecreate(request) {
            errorText = error
        } else {
            errorText = nil
            dismiss()
        }
    }
}
