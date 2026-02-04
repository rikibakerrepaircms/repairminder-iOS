//
//  WorkflowSelectionSheet.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct WorkflowSelectionSheet: View {
    let workflows: [Workflow]
    let onSelect: (Workflow) -> Void
    let isExecuting: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredWorkflows: [Workflow] {
        if searchText.isEmpty {
            return workflows
        }
        return workflows.filter { workflow in
            workflow.name.localizedCaseInsensitiveContains(searchText) ||
            (workflow.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredWorkflows.isEmpty {
                    ContentUnavailableView(
                        "No Workflows",
                        systemImage: "arrow.triangle.branch",
                        description: Text(searchText.isEmpty
                            ? "No workflows are available"
                            : "No workflows match your search")
                    )
                } else {
                    ForEach(filteredWorkflows) { workflow in
                        Button {
                            onSelect(workflow)
                        } label: {
                            WorkflowRow(workflow: workflow)
                        }
                        .disabled(isExecuting)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search workflows...")
            .navigationTitle("Select Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isExecuting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Executing workflow...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct WorkflowRow: View {
    let workflow: Workflow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.orange)
                Text(workflow.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if let description = workflow.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Show stages info if available
            if let stageCount = workflow.stageCount, stageCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(stageCount) follow-up stage\(stageCount == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }

            // Show first few stages if available
            if let stages = workflow.stages, !stages.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(stages.prefix(2)) { stage in
                        Text("• \(stage.delayDescription)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if stages.count > 2 {
                        Text("... and \(stages.count - 2) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkflowSelectionSheet(
        workflows: [],
        onSelect: { _ in },
        isExecuting: false
    )
}
