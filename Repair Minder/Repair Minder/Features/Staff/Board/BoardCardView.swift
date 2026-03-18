//
//  BoardCardView.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - Pulse Animation Modifier

/// Pulsing opacity animation for in-progress indicator dot
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulseAnimation() -> some View {
        modifier(PulseAnimation())
    }
}

// MARK: - Board Card View

/// Card view supporting collapsed (peek header) and expanded states.
/// Long-press initiates drag; tap toggles expand/collapse.
struct BoardCardView: View {
    let device: BoardDeviceItem
    var isExpanded: Bool = false
    var onTap: (() -> Void)?
    var onViewDetails: (() -> Void)?
    var onDragStart: ((CGPoint) -> Void)?

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Engineer colour stripe at top
            if let engineerId = device.engineerId {
                EngineerColors.color(for: engineerId)
                    .frame(height: 4)
            } else {
                Color.gray.opacity(0.3)
                    .frame(height: 4)
            }

            // Header (always visible)
            cardHeader
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            // Expanded content
            if isExpanded {
                CardExpandedContent(
                    device: device,
                    onViewDetails: onViewDetails
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    device.isInProgress ? Color.blue : Color.gray.opacity(0.2),
                    lineWidth: device.isInProgress ? 2 : 0.5
                )
        )
        .shadow(color: .black.opacity(isExpanded ? 0.12 : 0.06), radius: isExpanded ? 4 : 2, x: 0, y: isExpanded ? 2 : 1)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .onTapGesture {
            onTap?()
        }
        .simultaneousGesture(longPressGesture)
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Device name
                Text(device.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                // In-progress indicator
                if device.isInProgress {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .pulseAnimation()
                }
            }

            // Order number
            if let orderNumber = device.orderNumber {
                Text("#\(orderNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Engineer name and due date row
            HStack {
                if let engineerName = device.engineerName {
                    HStack(spacing: 4) {
                        if let engineerId = device.engineerId {
                            Circle()
                                .fill(EngineerColors.color(for: engineerId))
                                .frame(width: 8, height: 8)
                        }
                        Text(engineerName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let dueDate = device.formattedDueDate {
                    Text(dueDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Gestures

    /// Long-press gesture to initiate drag
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .onChanged { _ in
                isPressed = true
            }
            .onEnded { _ in
                isPressed = false
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif
                onDragStart?(.zero)
            }
    }
}

// MARK: - Drag Overlay Card

/// Simplified card shown as drag overlay (follows finger/cursor)
struct BoardDragOverlayCard: View {
    let device: BoardDeviceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Engineer colour stripe
            if let engineerId = device.engineerId {
                EngineerColors.color(for: engineerId)
                    .frame(height: 4)
            } else {
                Color.gray.opacity(0.3)
                    .frame(height: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let orderNumber = device.orderNumber {
                    Text("#\(orderNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 200)
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 2)
        )
        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        .rotationEffect(.degrees(2))
    }
}
