//
//  OrderDeviceDueDateSheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Sheet for setting a device's due date via `PATCH /api/orders/:orderId/devices/:deviceId`.
/// `OrderDeviceSummary` has no `dueDate` field to prefill from, so the picker
/// simply defaults to today.
struct OrderDeviceDueDateSheet: View {
    let deviceName: String
    /// Called with the chosen date formatted `yyyy-MM-dd` (local time zone).
    /// Returns an error message on failure, or `nil` on success.
    let onSave: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var busy = false
    @State private var errorText: String?

    /// Local (non-UTC) `yyyy-MM-dd` formatter — matches the Worker's plain
    /// snake_case passthrough for `due_date`.
    private static let dueDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Device", value: deviceName)

                DatePicker("Due date", selection: $selectedDate, displayedComponents: .date)
                    .accessibilityIdentifier("device-due-date-picker")

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Edit due date")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { errorText = nil; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            busy = true
                            let dateString = Self.dueDateFormatter.string(from: selectedDate)
                            let err = await onSave(dateString)
                            busy = false
                            if err == nil { dismiss() } else { errorText = err }
                        }
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("device-due-date-save")
                }
            }
            .disabled(busy)
        }
    }
}
