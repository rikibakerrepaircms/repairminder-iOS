//
//  ChecklistFormSheet.swift
//  Repair Minder
//
//  Created on 04/07/2026.
//

import SwiftUI

/// Sheet presenting an interactive checklist form for a given template.
/// Lets the tech set each item to pass/fail/not_tested/not_applicable
/// (with an optional note) and submits the whole result set on confirm.
struct ChecklistFormSheet: View {
    let template: ChecklistTemplate
    let onSubmit: (CompleteChecklistRequest) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var statuses: [String: ChecklistResultStatus] = [:]
    @State private var notes: [String: String] = [:]
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(template.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.subheadline)

                            Picker("Status", selection: statusBinding(for: item)) {
                                ForEach(ChecklistResultStatus.allCases) { status in
                                    Text(status.label).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            TextField(
                                "Note (optional)",
                                text: noteBinding(for: item)
                            )
                            .font(.footnote)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(template.name)
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Complete Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        errorText = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        submit()
                    }
                    .disabled(busy)
                    .accessibilityIdentifier("checklist-submit")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Bindings

    private func statusBinding(for item: ChecklistTemplateItem) -> Binding<ChecklistResultStatus> {
        Binding(
            get: { statuses[item.id] ?? .notTested },
            set: { statuses[item.id] = $0 }
        )
    }

    private func noteBinding(for item: ChecklistTemplateItem) -> Binding<String> {
        Binding(
            get: { notes[item.id] ?? "" },
            set: { notes[item.id] = $0 }
        )
    }

    // MARK: - Submit

    private func submit() {
        let results = template.items.map { item in
            ChecklistResultItem(
                name: item.name,
                status: (statuses[item.id] ?? .notTested).rawValue,
                notes: notes[item.id]?.isEmpty == false ? notes[item.id] : nil
            )
        }
        let request = CompleteChecklistRequest(
            checklistType: template.checklistType,
            templateId: template.id,
            results: results
        )

        Task {
            busy = true
            let err = await onSubmit(request)
            busy = false
            if err == nil {
                dismiss()
            } else {
                errorText = err
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChecklistFormSheet(
        template: ChecklistTemplate(
            id: "tpl-1",
            name: "Post-Repair Checklist",
            checklistType: "post_repair",
            deviceCategory: nil,
            items: [
                ChecklistTemplateItem(name: "Screen functions correctly"),
                ChecklistTemplateItem(name: "Battery charges normally")
            ],
            isDefault: true
        )
    ) { _ in nil }
}

private extension ChecklistTemplateItem {
    /// Convenience initializer for previews (production decoding always goes through `init(from:)`).
    init(name: String) {
        self.id = name
        self.name = name
    }
}
