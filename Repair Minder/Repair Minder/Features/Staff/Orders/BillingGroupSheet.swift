//
//  BillingGroupSheet.swift
//  Repair Minder
//
//  Sets or clears the order's billing group via
//  PATCH /api/orders/:id/billing-group. Group choices are scoped to the
//  order's client (fetched from GET /api/clients/:id/groups) — the backend
//  enforces that the group must have the client as a member, so no
//  client-side membership check is needed. Follows the same
//  `(Request) async -> String?` sheet convention as OrderDiscountSheet.
//

import SwiftUI

struct BillingGroupSheet: View {
    let order: Order
    let fetchGroups: () async -> [ClientGroupMembership]
    let onSave: (BillingGroupRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var groups: [ClientGroupMembership] = []
    @State private var selectedGroupId: String?
    @State private var isLoadingGroups = false
    @State private var busy = false
    @State private var errorText: String?

    init(
        order: Order,
        fetchGroups: @escaping () async -> [ClientGroupMembership],
        onSave: @escaping (BillingGroupRequest) async -> String?
    ) {
        self.order = order
        self.fetchGroups = fetchGroups
        self.onSave = onSave
        _selectedGroupId = State(initialValue: order.billingGroup?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if isLoadingGroups {
                        HStack {
                            ProgressView()
                            Text("Loading groups\u{2026}")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Group", selection: $selectedGroupId) {
                            Text("None").tag(String?.none)
                            ForEach(groups) { group in
                                Text(group.name).tag(String?.some(group.id))
                            }
                        }
                        .accessibilityIdentifier("billing-group-picker")
                    }
                } header: {
                    Text("Billing Group")
                } footer: {
                    Text("Choosing \"None\" clears the order's billing group.")
                }

                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Billing Group")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(busy || isLoadingGroups)
                    .accessibilityIdentifier("billing-group-save")
                }
            }
            .disabled(busy)
            .task {
                isLoadingGroups = true
                groups = await fetchGroups()
                isLoadingGroups = false
            }
        }
    }

    // MARK: - Save

    private func save() async {
        busy = true
        defer { busy = false }

        let request = BillingGroupRequest(clientGroupId: selectedGroupId)

        if let error = await onSave(request) {
            errorText = error
        } else {
            errorText = nil
            dismiss()
        }
    }
}
