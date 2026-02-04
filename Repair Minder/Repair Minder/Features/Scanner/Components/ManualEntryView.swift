//
//  ManualEntryView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var isTextFieldFocused: Bool

    let onSubmit: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isTextFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            submitIfValid()
                        }
                } footer: {
                    Text("Enter the QR code value, order number, or device serial number")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .foregroundStyle(.secondary)
                            Text("QR Code")
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .foregroundStyle(.secondary)
                            Text("Order Number (e.g., 12345)")
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "barcode")
                                .foregroundStyle(.secondary)
                            Text("Serial/Barcode")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.footnote)
                } header: {
                    Text("Supported Formats")
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Search") {
                        submitIfValid()
                    }
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }

    private func submitIfValid() {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        guard !trimmedCode.isEmpty else { return }
        onSubmit(trimmedCode)
        dismiss()
    }
}

#Preview {
    ManualEntryView { code in
        print("Submitted: \(code)")
    }
}
