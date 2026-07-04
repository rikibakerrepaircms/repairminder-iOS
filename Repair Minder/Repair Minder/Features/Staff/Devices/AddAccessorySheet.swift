//
//  AddAccessorySheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Sheet for recording a new accessory taken in with a device, presented from
/// `DeviceDetailView`'s accessories section. Posts to
/// `DeviceDetailViewModel.addAccessory`.
struct AddAccessorySheet: View {
    let onAdd: (AddAccessoryRequest) async -> String?

    @Environment(\.dismiss) private var dismiss

    /// Raw wire value (snake_case, sent to the API) paired with a display label.
    private let accessoryTypes: [(value: String, label: String)] = [
        ("charger", "Charger"),
        ("cable", "Cable"),
        ("case", "Case"),
        ("sim_card", "SIM card"),
        ("stylus", "Stylus"),
        ("box", "Box"),
        ("sd_card", "SD card"),
        ("other", "Other"),
    ]

    @State private var accessoryType = "charger"
    @State private var description = ""
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $accessoryType) {
                    ForEach(accessoryTypes, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                TextField("Description (optional)", text: $description)
                    .accessibilityIdentifier("add-accessory-description")
                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Add accessory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        errorText = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            busy = true
                            let err = await onAdd(
                                AddAccessoryRequest(
                                    accessoryType: accessoryType,
                                    description: description.isEmpty ? nil : description
                                )
                            )
                            busy = false
                            if err == nil {
                                dismiss()
                            } else {
                                errorText = err
                            }
                        }
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("add-accessory-confirm")
                }
            }
        }
    }
}
