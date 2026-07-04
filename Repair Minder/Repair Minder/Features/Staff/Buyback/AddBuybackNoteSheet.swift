//
//  AddBuybackNoteSheet.swift
//  Repair Minder
//
//  Add a free-text note to a buyback device. Phase 3 — buyback lifecycle.
//

import SwiftUI

/// Adds a note via POST /api/buyback/:id/notes.
struct AddBuybackNoteSheet: View {
    let onAdd: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var noteBody: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var trimmedBody: String {
        noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Note", text: $noteBody, axis: .vertical)
                        .lineLimit(4...10)
                        .accessibilityIdentifier("buyback-note-body")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    addButton
                }
            }
            .disabled(isSaving)
        }
    }

    private var addButton: some View {
        Button("Add") {
            Task { await add() }
        }
        .accessibilityIdentifier("buyback-note-add")
        .disabled(isSaving || trimmedBody.isEmpty)
    }

    private func add() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        if let error = await onAdd(trimmedBody) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
