//
//  DiagnosisForm.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct DiagnosisForm: View {
    @Binding var diagnosis: String
    @Binding var resolution: String
    let isSaving: Bool
    let onSave: () -> Void

    @State private var isEditing = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case diagnosis
        case resolution
    }

    private var hasChanges: Bool {
        !diagnosis.isEmpty || !resolution.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Diagnosis & Resolution", systemImage: "stethoscope")
                    .font(.headline)

                Spacer()

                if isEditing && hasChanges {
                    Button {
                        focusedField = nil
                        onSave()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isSaving)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Diagnosis")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $diagnosis)
                        .font(.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused($focusedField, equals: .diagnosis)
                        .onChange(of: diagnosis) { _, _ in
                            isEditing = true
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $resolution)
                        .font(.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .focused($focusedField, equals: .resolution)
                        .onChange(of: resolution) { _, _ in
                            isEditing = true
                        }
                }
            }

            if !isEditing && diagnosis.isEmpty && resolution.isEmpty {
                Text("Tap to add diagnosis and resolution notes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if !isEditing {
                isEditing = true
                focusedField = .diagnosis
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var diagnosis = ""
        @State private var resolution = ""

        var body: some View {
            VStack(spacing: 20) {
                DiagnosisForm(
                    diagnosis: $diagnosis,
                    resolution: $resolution,
                    isSaving: false,
                    onSave: {}
                )

                DiagnosisForm(
                    diagnosis: .constant("The display connector was damaged from impact. Internal inspection shows no liquid damage."),
                    resolution: .constant("Replaced display assembly. Tested all functions - working normally."),
                    isSaving: false,
                    onSave: {}
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}
