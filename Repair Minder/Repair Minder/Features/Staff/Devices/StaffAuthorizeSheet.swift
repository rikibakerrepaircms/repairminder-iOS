//
//  StaffAuthorizeSheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Sheet presenting the staff-authorize action (approve/reject) for a device
/// currently `awaiting_authorisation`.
struct StaffAuthorizeSheet: View {
    let onSubmit: (StaffAuthorizeRequest) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var action: AuthorizeAction = .approve
    @State private var method: AuthorizeMethod = .inStore
    @State private var reasonOrNotes = ""
    @State private var busy = false
    @State private var errorText: String?

    enum AuthorizeAction: String, CaseIterable, Identifiable {
        case approve
        case reject

        var id: String { rawValue }
        var label: String {
            switch self {
            case .approve: return "Approve"
            case .reject: return "Reject"
            }
        }
    }

    enum AuthorizeMethod: String, CaseIterable, Identifiable {
        case inStore = "in_store"
        case phone
        case staffOverride = "staff_override"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .inStore: return "In store"
            case .phone: return "Phone"
            case .staffOverride: return "Staff override"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Decision") {
                    Picker("Action", selection: $action) {
                        ForEach(AuthorizeAction.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("staff-authorize-action")

                    Picker("Method", selection: $method) {
                        ForEach(AuthorizeMethod.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .accessibilityIdentifier("staff-authorize-method")
                }

                Section(action == .reject ? "Reason" : "Notes (optional)") {
                    TextField(
                        action == .reject ? "Reason for rejection" : "Notes",
                        text: $reasonOrNotes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .accessibilityIdentifier("staff-authorize-notes")
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Staff Authorize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        errorText = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action == .reject ? "Reject" : "Approve") {
                        submit()
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("staff-authorize-confirm")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Submit

    private func submit() {
        let trimmed = reasonOrNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = StaffAuthorizeRequest(
            action: action.rawValue,
            method: method.rawValue,
            notes: action == .approve && !trimmed.isEmpty ? trimmed : nil,
            authorizationReason: action == .reject && !trimmed.isEmpty ? trimmed : nil
        )

        Task {
            busy = true
            let err = await onSubmit(request)
            busy = false
            if err == nil {
                errorText = nil
                dismiss()
            } else {
                errorText = err
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StaffAuthorizeSheet { _ in nil }
}
