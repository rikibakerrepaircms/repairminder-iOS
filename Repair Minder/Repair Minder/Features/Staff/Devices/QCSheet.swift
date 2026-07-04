//
//  QCSheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Sheet presenting the QC (quality check) readiness checklist and the
/// pass/fail action for a device currently in the `repaired_qc` status.
struct QCSheet: View {
    let requirements: QCRequirements
    let onSubmit: (QCActionRequest) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var reworkNote = ""
    @State private var busy = false
    @State private var errorText: String?

    /// All non-optional blocking requirements are satisfied.
    private var canPass: Bool {
        requirements.hasConclusion
            && (!requirements.requirePostRepairChecklist || requirements.hasPostTestChecklist)
            && (!requirements.requirePostRepairPhotos || requirements.hasPostRepairPhotos)
    }

    private var canFail: Bool {
        !reworkNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Readiness") {
                    requirementRow(
                        label: "Repair conclusion",
                        satisfied: requirements.hasConclusion,
                        blocking: true
                    )
                    requirementRow(
                        label: "Post-repair checklist",
                        satisfied: requirements.hasPostTestChecklist,
                        blocking: requirements.requirePostRepairChecklist
                    )
                    requirementRow(
                        label: "Post-repair photos",
                        satisfied: requirements.hasPostRepairPhotos,
                        blocking: requirements.requirePostRepairPhotos
                    )
                }

                Section {
                    Button("Pass") {
                        submit(action: "pass", reworkNote: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!canPass || busy)
                    .accessibilityIdentifier("qc-pass")
                }

                Section("Fail — rework required") {
                    TextField("Rework note", text: $reworkNote, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("qc-rework-note")

                    Button("Fail QC", role: .destructive) {
                        submit(action: "fail", reworkNote: reworkNote)
                    }
                    .tint(.red)
                    .disabled(!canFail || busy)
                    .accessibilityIdentifier("qc-fail")
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Quality Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        errorText = nil
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Requirement Row

    @ViewBuilder
    private func requirementRow(label: String, satisfied: Bool, blocking: Bool) -> some View {
        HStack {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(satisfied ? .green : (blocking ? .red : .secondary))
            Text(label)
            Spacer()
            if blocking && !satisfied {
                Text("Required")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Submit

    private func submit(action: String, reworkNote: String?) {
        let request = QCActionRequest(
            action: action,
            reworkNote: reworkNote,
            collectionLocationId: nil
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
    QCSheet(
        requirements: QCRequirements(
            hasPostTestChecklist: true,
            hasConclusion: true,
            hasPostRepairPhotos: false,
            requirePostRepairPhotos: false,
            requirePostRepairChecklist: true
        )
    ) { _ in nil }
}
