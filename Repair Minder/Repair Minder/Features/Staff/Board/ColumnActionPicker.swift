//
//  ColumnActionPicker.swift
//  Repair Minder
//
//  Created on 18/03/2026.
//

import SwiftUI

// MARK: - Column Action Picker

/// Action type + value picker for column configuration.
/// Allows adding set_status, set_engineer, clear_engineer, etc. actions.
struct ColumnActionPicker: View {
    let columnId: String
    let onActionCreated: (BoardColumnAction) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var actionType = "set_status"
    @State private var actionValue = ""
    @State private var isSaving = false

    private let actionTypes: [(value: String, label: String)] = [
        ("set_status", "Set Status"),
        ("set_engineer", "Assign Engineer"),
        ("clear_engineer", "Clear Engineer"),
        ("set_sub_location", "Set Sub-Location"),
        ("clear_sub_location", "Clear Sub-Location"),
    ]

    private let statusOptions = [
        "device_received", "diagnosing", "repairing", "awaiting_parts",
        "awaiting_customer", "quality_check", "repaired_ready",
        "collected", "shipped",
    ]

    private var needsValue: Bool {
        actionType == "set_status" || actionType == "set_engineer" || actionType == "set_sub_location"
    }

    private var canSave: Bool {
        !needsValue || !actionValue.isEmpty
    }

    var body: some View {
        Form {
            Section("Action Type") {
                Picker("Type", selection: $actionType) {
                    ForEach(actionTypes, id: \.value) { type in
                        Text(type.label).tag(type.value)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: actionType) { _, _ in
                    actionValue = ""
                }
            }

            if needsValue {
                Section("Value") {
                    if actionType == "set_status" {
                        Picker("Status", selection: $actionValue) {
                            Text("Select a status…").tag("")
                            ForEach(statusOptions, id: \.self) { status in
                                Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .tag(status)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } else {
                        TextField("Enter ID or value", text: $actionValue)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
            }

            Section {
                Button {
                    saveAction()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Add Action")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canSave || isSaving)
            }
        }
        .navigationTitle("Add Action")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveAction() {
        isSaving = true
        let value = needsValue ? actionValue : ""
        Task {
            do {
                let action = try await BoardService.createAction(
                    columnId: columnId,
                    actionType: actionType,
                    actionValue: value
                )
                onActionCreated(action)
                dismiss()
            } catch {
                #if DEBUG
                print("Create action error: \(error)")
                #endif
            }
            isSaving = false
        }
    }
}

// MARK: - Column Editor Sheet

/// Editor sheet for a single board column: title, colour, and actions.
struct ColumnEditorSheet: View {
    let column: BoardColumnModel
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedColor: String
    @State private var actions: [BoardColumnAction]
    @State private var isSaving = false

    private let presetColors = [
        "#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6",
        "#EC4899", "#14B8A6", "#F97316", "#6366F1", "#06B6D4",
    ]

    init(column: BoardColumnModel, onSave: @escaping () async -> Void) {
        self.column = column
        self.onSave = onSave
        _title = State(initialValue: column.title)
        _selectedColor = State(initialValue: column.color ?? "")
        _actions = State(initialValue: column.actions)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Column Title", text: $title)
                }

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(presetColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                                        .padding(-2)
                                )
                                .onTapGesture {
                                    selectedColor = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Actions") {
                    if actions.isEmpty {
                        Text("No actions configured")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(actions) { action in
                        HStack {
                            Image(systemName: iconForAction(action.actionType))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(labelForAction(action))
                                .font(.body)
                            Spacer()
                        }
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { actions[$0] }
                        for action in toDelete {
                            Task {
                                try? await BoardService.deleteAction(
                                    columnId: column.id,
                                    actionId: action.id
                                )
                            }
                        }
                        actions.remove(atOffsets: offsets)
                    }

                    NavigationLink("Add Action") {
                        ColumnActionPicker(columnId: column.id) { newAction in
                            actions.append(newAction)
                        }
                    }
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                _ = try await BoardService.updateColumn(
                    id: column.id,
                    title: title,
                    color: selectedColor.isEmpty ? nil : selectedColor
                )
                await onSave()
                dismiss()
            } catch {
                #if DEBUG
                print("Update column error: \(error)")
                #endif
            }
            isSaving = false
        }
    }

    private func labelForAction(_ action: BoardColumnAction) -> String {
        switch action.actionType {
        case "set_status":
            return "Set status → \((action.actionValue ?? "").replacingOccurrences(of: "_", with: " ").capitalized)"
        case "set_engineer": return "Assign engineer"
        case "clear_engineer": return "Clear engineer"
        case "set_sub_location": return "Set sub-location"
        case "clear_sub_location": return "Clear sub-location"
        default: return "\(action.actionType): \(action.actionValue ?? "")"
        }
    }

    private func iconForAction(_ type: String) -> String {
        switch type {
        case "set_status": return "arrow.right.circle"
        case "set_engineer": return "person.badge.plus"
        case "clear_engineer": return "person.badge.minus"
        case "set_sub_location": return "mappin.circle"
        case "clear_sub_location": return "mappin.slash"
        default: return "gearshape"
        }
    }
}
