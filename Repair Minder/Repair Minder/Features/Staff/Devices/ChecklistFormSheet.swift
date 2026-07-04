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
    /// Keyed by array index (not `item.id`) so duplicate-named items each get
    /// their own independent status/note — `id` can collide across rows.
    @State private var statuses: [Int: ChecklistResultStatus] = [:]
    @State private var notes: [Int: String] = [:]
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Array(template.items.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                if item.required {
                                    Text("Required")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Picker("Status", selection: statusBinding(for: index)) {
                                ForEach(ChecklistResultStatus.allCases) { status in
                                    Text(status.label).tag(status)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            TextField(
                                "Note (optional)",
                                text: noteBinding(for: index)
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
                } else if hasOutstandingRequiredItems {
                    Text("Complete all required items (\(outstandingRequiredCount) remaining).")
                        .foregroundStyle(.orange)
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
                    .disabled(busy || hasOutstandingRequiredItems)
                    .accessibilityIdentifier("checklist-submit")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Bindings

    private func statusBinding(for index: Int) -> Binding<ChecklistResultStatus> {
        Binding(
            get: { statuses[index] ?? .notTested },
            set: { statuses[index] = $0 }
        )
    }

    private func noteBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { notes[index] ?? "" },
            set: { notes[index] = $0 }
        )
    }

    // MARK: - Required-item validation

    /// Count of required items still sitting at `.notTested`.
    private var outstandingRequiredCount: Int {
        template.items.enumerated().reduce(into: 0) { count, pair in
            let (index, item) = pair
            if item.required && (statuses[index] ?? .notTested) == .notTested {
                count += 1
            }
        }
    }

    private var hasOutstandingRequiredItems: Bool {
        outstandingRequiredCount > 0
    }

    // MARK: - Submit

    private func submit() {
        guard !hasOutstandingRequiredItems else {
            errorText = "Complete all required items (\(outstandingRequiredCount) remaining)."
            return
        }

        let results = template.items.enumerated().map { index, item in
            ChecklistResultItem(
                name: item.name,
                status: (statuses[index] ?? .notTested).rawValue,
                notes: notes[index]?.isEmpty == false ? notes[index] : nil
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
    init(name: String, required: Bool = false) {
        self.id = name
        self.name = name
        self.required = required
    }
}
