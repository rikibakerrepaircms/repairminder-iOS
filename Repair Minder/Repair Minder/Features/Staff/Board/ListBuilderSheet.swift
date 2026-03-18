//
//  ListBuilderSheet.swift
//  Repair Minder
//
//  Created on 18/03/2026.
//

import SwiftUI

// MARK: - List Builder Sheet

/// Settings sheet for managing board columns:
/// - Toggle pinned columns (e.g., "Due Today" timeline)
/// - Reorder, delete, and add regular columns
/// - Tap column to edit (opens ColumnEditorSheet)
struct ListBuilderSheet: View {
    let viewModel: BoardViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var editingColumn: BoardColumnModel?

    private var pinnedColumns: [BoardColumnModel] {
        viewModel.columns.filter { $0.columnType == "pinned" }
    }

    private var regularColumns: [BoardColumnModel] {
        viewModel.columns
            .filter { $0.columnType != "pinned" }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                // Pinned Lists section
                if !pinnedColumns.isEmpty {
                    Section("Pinned Lists") {
                        ForEach(pinnedColumns) { col in
                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.orange)
                                    .font(.body)

                                Text(col.title)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { col.isVisible.value },
                                    set: { newValue in
                                        Task {
                                            _ = try? await BoardService.updateColumn(
                                                id: col.id,
                                                isVisible: newValue
                                            )
                                            await viewModel.reloadColumns()
                                        }
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                }

                // Regular columns section
                Section("Lists") {
                    ForEach(regularColumns) { col in
                        HStack(spacing: 10) {
                            if let hex = col.color, !hex.isEmpty {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 10, height: 10)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 10, height: 10)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(col.title)
                                    .font(.body)

                                if !col.actions.isEmpty {
                                    Text(actionSummary(col.actions))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingColumn = col
                        }
                    }
                    .onMove { from, to in
                        var reordered = regularColumns
                        reordered.move(fromOffsets: from, toOffset: to)
                        Task {
                            try? await BoardService.reorderColumns(
                                columnIds: reordered.map(\.id)
                            )
                            await viewModel.reloadColumns()
                        }
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { regularColumns[$0] }
                            .filter { $0.columnType == "custom" }
                        for col in toDelete {
                            Task {
                                try? await BoardService.deleteColumn(id: col.id)
                                await viewModel.reloadColumns()
                            }
                        }
                    }
                }

                // Add new list
                Section {
                    Button {
                        Task {
                            do {
                                let newCol = try await BoardService.createColumn(
                                    title: "New List",
                                    scope: viewModel.scope,
                                    columnType: "custom",
                                    sortOrder: regularColumns.count
                                )
                                await viewModel.reloadColumns()
                                editingColumn = newCol
                            } catch {
                                #if DEBUG
                                print("Create column error: \(error)")
                                #endif
                            }
                        }
                    } label: {
                        Label("Add List", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(viewModel.scope == "company" ? "Board Lists" : "My Queue Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                #endif
            }
            .sheet(item: $editingColumn) { column in
                ColumnEditorSheet(
                    column: column,
                    onSave: {
                        await viewModel.reloadColumns()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private func actionSummary(_ actions: [BoardColumnAction]) -> String {
        actions.map { action in
            switch action.actionType {
            case "set_status":
                return "→ \(action.actionValue.replacingOccurrences(of: "_", with: " ").capitalized)"
            case "clear_engineer": return "Clear engineer"
            case "set_engineer": return "Assign engineer"
            case "set_sub_location": return "Set location"
            case "clear_sub_location": return "Clear location"
            default: return action.actionType
            }
        }.joined(separator: " · ")
    }
}
