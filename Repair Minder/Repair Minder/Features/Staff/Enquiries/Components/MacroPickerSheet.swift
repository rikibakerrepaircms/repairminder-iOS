//
//  MacroPickerSheet.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Sheet for selecting and executing a macro
struct MacroPickerSheet: View {
    let macros: [Macro]
    let onSelect: (Macro) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var selectedMacro: Macro?
    @State private var showingPreview = false

    // MARK: - Computed Properties

    private var categories: [String] {
        Array(Set(macros.compactMap { $0.category })).sorted()
    }

    private var filteredMacros: [Macro] {
        var result = macros

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { macro in
                macro.name.localizedCaseInsensitiveContains(searchText) ||
                (macro.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    private var groupedMacros: [String: [Macro]] {
        Dictionary(grouping: filteredMacros) { $0.category ?? "General" }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                if !categories.isEmpty {
                    categoryPicker
                }

                // Macro list
                List {
                    ForEach(groupedMacros.keys.sorted(), id: \.self) { category in
                        Section(category.capitalized) {
                            ForEach(groupedMacros[category] ?? []) { macro in
                                MacroRow(macro: macro) {
                                    selectedMacro = macro
                                    showingPreview = true
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $searchText, prompt: "Search macros")
            .navigationTitle("Select Macro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedMacro) { macro in
                MacroPreviewSheet(macro: macro) {
                    onSelect(macro)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MacroCategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(categories, id: \.self) { category in
                    MacroCategoryChip(
                        title: category.capitalized,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.platformGroupedBackground)
    }
}

// MARK: - Macro Category Chip

private struct MacroCategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Macro Row

private struct MacroRow: View {
    let macro: Macro
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(macro.name)
                        .font(.headline)

                    Spacer()

                    if macro.hasFollowUps {
                        Label("\(macro.stageCount ?? 0)", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let description = macro.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    // Action type
                    Label(
                        macro.isEmailMacro ? "Email" : "Note",
                        systemImage: macro.isEmailMacro ? "envelope" : "note.text"
                    )
                    .font(.caption)
                    .foregroundColor(.blue)

                    // Reply behavior
                    if let behavior = macro.replyBehavior, behavior != "continue" {
                        Label(
                            behavior == "cancel" ? "Cancels on reply" : "Pauses on reply",
                            systemImage: behavior == "cancel" ? "xmark.circle" : "pause.circle"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Macro Preview Sheet

private struct MacroPreviewSheet: View {
    let macro: Macro
    let onExecute: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    if let description = macro.description, !description.isEmpty {
                        Text(description)
                            .foregroundColor(.secondary)
                    }

                    // Initial action
                    GroupBox("Initial Action") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: macro.isEmailMacro ? "envelope" : "note.text")
                                    .foregroundColor(.blue)
                                Text(macro.isEmailMacro ? "Send Email" : "Add Note")
                                    .font(.subheadline.weight(.medium))
                            }

                            if let subject = macro.initialSubject, macro.isEmailMacro {
                                Text("Subject: \(subject)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(macro.initialContent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(5)
                        }
                    }

                    // Follow-up stages
                    if let stages = macro.stages, !stages.isEmpty {
                        GroupBox("Follow-up Stages") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(stages) { stage in
                                    StageRow(stage: stage)
                                }
                            }
                        }
                    }

                    // Reply behavior
                    if macro.replyBehavior != nil {
                        GroupBox("When Customer Replies") {
                            Text(macro.replyBehaviorDescription)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(macro.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Execute") {
                        onExecute()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Stage Row

private struct StageRow: View {
    let stage: MacroStage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Stage \(stage.stageNumber)")
                    .font(.caption.weight(.semibold))

                Text("•")
                    .foregroundColor(.secondary)

                Text(stage.delayDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(stage.actionSummary)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    MacroPickerSheet(
        macros: [
            Macro(
                id: "1",
                name: "Quote Follow-up",
                category: "quotes",
                description: "Send after providing a quote to the customer",
                initialActionType: "email",
                initialSubject: "Following up on your quote",
                initialContent: "Hi {{client_name}}, just following up on the quote we sent...",
                replyBehavior: "cancel",
                pauseExpiryDays: 5,
                isActive: 1,
                sortOrder: 0,
                stageCount: 2,
                stages: [
                    MacroStage(
                        id: "s1",
                        stageNumber: 1,
                        delayMinutes: 1440,
                        delayDisplay: "1 day",
                        actionType: "email",
                        subject: "Still interested?",
                        content: "Hi, wanted to check if you're still interested...",
                        sendEmail: 1,
                        addNote: 0,
                        changeStatus: 0,
                        newStatus: nil,
                        noteContent: nil,
                        isActive: 1
                    )
                ],
                createdAt: nil
            )
        ],
        onSelect: { _ in }
    )
}
