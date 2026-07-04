//
//  DeviceDespatchSheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Device-level "Despatch" sheet — collects a carrier and optional tracking
/// number, then forwards the result to `DeviceDetailViewModel.despatchDevice`.
/// Mirrors `DespatchOrderSheet`'s structure but offers the full 9-carrier list
/// (the order-level sheet is missing "Evri").
struct DeviceDespatchSheet: View {
    let onDespatch: (DespatchOrderRequest) async -> String?

    @Environment(\.dismiss) private var dismiss
    private let carriers = ["Royal Mail", "DPD", "DHL", "UPS", "FedEx", "Evri", "Hermes", "Yodel", "Other"]
    @State private var carrier = "Royal Mail"
    @State private var tracking = ""
    @State private var notify = true
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Carrier", selection: $carrier) {
                    ForEach(carriers, id: \.self) { Text($0).tag($0) }
                }
                TextField("Tracking number (optional)", text: $tracking)
                    .accessibilityIdentifier("device-despatch-tracking")
                Toggle("Email customer", isOn: $notify)
                if let errorText {
                    Text(errorText).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Despatch device")
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
                    Button("Despatch") {
                        Task {
                            busy = true
                            let err = await onDespatch(
                                DespatchOrderRequest(
                                    carrier: carrier,
                                    trackingNumber: tracking.isEmpty ? nil : tracking,
                                    sendNotification: notify
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
                    .accessibilityIdentifier("device-despatch-confirm")
                }
            }
        }
    }
}
