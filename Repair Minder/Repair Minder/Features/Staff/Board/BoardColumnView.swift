//
//  BoardColumnView.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Board Column View

/// A single board column with header (colour dot, title, count badge) and card stack.
/// Highlights blue when a card is being dragged over it.
struct BoardColumnView: View {
    let columnData: BoardColumnData
    let dragState: BoardDragState
    let onDeviceTap: (BoardDeviceItem) -> Void
    var onDragStart: (BoardDeviceItem, String, CGPoint) -> Void

    /// Whether this column is being hovered during drag
    private var isDropTarget: Bool {
        dragState.hoveredColumnId == columnData.id
    }

    var body: some View {
        // Timeline/pinned columns are handled separately by TimelineColumn
        if columnData.column.columnType == "pinned" {
            EmptyView()
        }

        VStack(spacing: 0) {
            // Column header
            columnHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // Cards area
            if columnData.isEmpty && !isDropTarget {
                emptyPlaceholder
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        BoardCardStack(
                            devices: columnData.devices,
                            columnId: columnData.id,
                            dragState: dragState,
                            onDeviceTap: onDeviceTap,
                            onDragStart: onDragStart
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)

                    // Drop target area when empty but hovered
                    if columnData.isEmpty && isDropTarget {
                        dropTargetPlaceholder
                    }
                }
            }
        }
        .background(Color.platformGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDropTarget ? Color.blue : Color.clear,
                    lineWidth: isDropTarget ? 2 : 0
                )
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        dragState.registerColumnFrame(
                            columnId: columnData.id,
                            frame: geo.frame(in: .global)
                        )
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        dragState.registerColumnFrame(
                            columnId: columnData.id,
                            frame: newFrame
                        )
                    }
            }
        )
    }

    // MARK: - Column Header

    private var columnHeader: some View {
        HStack(spacing: 8) {
            // Colour dot
            if let color = columnData.column.color, !color.isEmpty {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 10, height: 10)
            }

            // Title
            Text(columnData.column.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            // Count badge
            Text("\(columnData.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.platformGray5)
                .clipShape(Capsule())
        }
    }

    // MARK: - Empty State

    private var emptyPlaceholder: some View {
        VStack {
            Spacer()
            Text("No devices")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: - Drop Target Placeholder

    private var dropTargetPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.blue.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [6]))
            .frame(height: 60)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
    }
}
