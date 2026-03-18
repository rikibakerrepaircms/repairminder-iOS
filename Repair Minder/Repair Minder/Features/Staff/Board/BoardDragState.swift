//
//  BoardDragState.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Board Drag State

/// Observable state shared across the board during a drag-and-drop operation.
/// Uses a custom gesture-based approach (not Transferable) for more animation control.
///
/// **iOS 26 Native Drag Decision:** Evaluated `.dragContainer()` + `.draggable(containerItemID:)`.
/// Keeping custom `DragGesture` for wallet-style 1:1 finger tracking; native drag uses a system
/// lift preview which doesn't match the board's direct-manipulation UX. The custom approach gives
/// us full control over the overlay position, column hit detection, and animation timing.
@MainActor
@Observable
final class BoardDragState {

    /// The device currently being dragged (nil when not dragging)
    var draggedDevice: BoardDeviceItem?

    /// The column ID the device is being dragged from
    var sourceColumnId: String?

    /// Current drag translation relative to the start point
    var dragOffset: CGSize = .zero

    /// The start location of the drag in global coordinates
    var dragStartLocation: CGPoint = .zero

    /// Whether a drag is currently active
    var isDragging: Bool {
        draggedDevice != nil
    }

    /// The column ID currently being hovered over (for highlight)
    var hoveredColumnId: String?

    /// Column frames in global coordinate space (populated by geometry readers)
    var columnFrames: [String: CGRect] = [:]

    // MARK: - Methods

    /// Begin a drag operation
    func startDrag(device: BoardDeviceItem, fromColumnId: String, startLocation: CGPoint) {
        draggedDevice = device
        sourceColumnId = fromColumnId
        dragStartLocation = startLocation
        dragOffset = .zero
        hoveredColumnId = nil
    }

    /// Update drag position and determine which column is being hovered
    func updateDrag(translation: CGSize, currentLocation: CGPoint) {
        dragOffset = translation

        // Determine which column the drag is over
        hoveredColumnId = nil
        for (columnId, frame) in columnFrames {
            if frame.contains(currentLocation) && columnId != sourceColumnId {
                hoveredColumnId = columnId
                break
            }
        }
    }

    /// End the drag and return the target column ID (if dropped on a valid column)
    func endDrag() -> String? {
        let targetColumnId = hoveredColumnId
        reset()
        return targetColumnId
    }

    /// Cancel the drag without executing any action
    func cancelDrag() {
        reset()
    }

    /// Register a column's frame for drop detection
    func registerColumnFrame(columnId: String, frame: CGRect) {
        columnFrames[columnId] = frame
    }

    // MARK: - Private

    private func reset() {
        draggedDevice = nil
        sourceColumnId = nil
        dragOffset = .zero
        dragStartLocation = .zero
        hoveredColumnId = nil
    }
}
