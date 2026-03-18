//
//  BoardCardStack.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Board Card Stack

/// Apple Wallet-style stacked cards with expand/collapse.
/// Only one card can be expanded at a time. Tapping a collapsed card expands it;
/// tapping the expanded card or tapping outside collapses it.
struct BoardCardStack: View {
    let devices: [BoardDeviceItem]
    let columnId: String
    let dragState: BoardDragState
    var onDeviceTap: (BoardDeviceItem) -> Void
    var onDragStart: (BoardDeviceItem, String, CGPoint) -> Void

    /// Peek height for collapsed cards (only header visible)
    private let peekHeight: CGFloat = 28

    @State private var expandedDeviceId: String?

    var body: some View {
        ConditionalGlassContainer(spacing: 4) {
        VStack(spacing: 0) {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                let isExpanded = expandedDeviceId == device.id
                let isDragged = dragState.draggedDevice?.id == device.id

                if !isDragged {
                    BoardCardView(
                        device: device,
                        isExpanded: isExpanded,
                        onTap: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if isExpanded {
                                    expandedDeviceId = nil
                                } else {
                                    expandedDeviceId = device.id
                                }
                            }
                        },
                        onViewDetails: {
                            onDeviceTap(device)
                        },
                        onDragStart: { location in
                            // Collapse before drag
                            withAnimation(.spring(response: 0.2)) {
                                expandedDeviceId = nil
                            }
                            onDragStart(device, columnId, location)
                        }
                    )
                    .zIndex(isExpanded ? 100 : Double(index))
                    .transition(.opacity)
                }
            }
        }
        } // ConditionalGlassContainer
    }

    /// Collapse any expanded card (called externally, e.g., on background tap)
    func collapseAll() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            expandedDeviceId = nil
        }
    }
}
