//
//  BoardCardView.swift
//  Repair Minder
//
//  Created on 17/03/2026.
//

import SwiftUI

// MARK: - iOS 26 Glass Effect Helpers (Shared across Board views)

/// Conditionally wraps content in GlassEffectContainer on iOS 26+.
struct ConditionalGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    /// Card-level glass: interactive tinted glass on iOS 26+, flat background with shadow on older.
    @ViewBuilder
    func boardCardGlass(engineerColor: Color, isExpanded: Bool, isPressed: Bool, isInProgress: Bool) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                        .opacity(isInProgress ? 1 : 0)
                )
                .glassEffect(
                    .regular.interactive().tint(engineerColor.opacity(0.3)),
                    in: .rect(cornerRadius: 8)
                )
        } else {
            self
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isInProgress ? Color.blue : Color.gray.opacity(0.2),
                            lineWidth: isInProgress ? 2 : 0.5
                        )
                )
                .shadow(color: .black.opacity(isExpanded ? 0.12 : 0.06), radius: isExpanded ? 4 : 2, x: 0, y: isExpanded ? 2 : 1)
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.2), value: isPressed)
        }
    }

    /// Column container glass: tinted glass on iOS 26+, grouped background with optional border on older.
    @ViewBuilder
    func boardColumnGlass(isDropTarget: Bool, columnColor: Color?) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(
                isDropTarget
                    ? .regular.tint(.blue.opacity(0.3))
                    : .regular.tint((columnColor ?? .gray).opacity(0.1)),
                in: .rect(cornerRadius: 12)
            )
        } else {
            self
                .background(Color.platformGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isDropTarget ? Color.blue : Color.clear,
                            lineWidth: isDropTarget ? 2 : 0
                        )
                )
        }
    }

    /// Timeline container glass: plain glass on iOS 26+, grouped background on older.
    @ViewBuilder
    func timelineContainerGlass() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            self
                .background(Color.platformGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Timeline card glass: tinted glass on iOS 26+, flat background with shadow on older.
    @ViewBuilder
    func timelineCardGlass(engineerColor: Color, isExpanded: Bool, isResizing: Bool) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                        .opacity(isResizing ? 1 : 0)
                )
                .glassEffect(.regular.tint(engineerColor.opacity(0.2)), in: .rect(cornerRadius: 8))
        } else {
            self
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isResizing ? Color.blue : Color.gray.opacity(0.2),
                            lineWidth: isResizing ? 2 : 0.5
                        )
                )
                .shadow(color: .black.opacity(isExpanded ? 0.12 : 0.06), radius: isExpanded ? 6 : 2)
        }
    }

    /// Drag overlay card glass: blue-tinted glass on iOS 26+, blue border on older.
    @ViewBuilder
    func dragOverlayGlass() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self
                .glassEffect(.regular.tint(.blue.opacity(0.3)), in: .rect(cornerRadius: 8))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        } else {
            self
                .background(Color.platformBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    /// Column header glass: subtle tint on iOS 26+, no extra styling on older.
    @ViewBuilder
    func columnHeaderGlass(columnColor: Color?) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint((columnColor ?? .gray).opacity(0.15)))
        } else {
            self
        }
    }

    /// Legend chip glass: tinted pill on iOS 26+, no extra styling on older.
    @ViewBuilder
    func legendChipGlass(color: Color) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(color.opacity(0.2)))
        } else {
            self
        }
    }

    /// Badge glass (capsule): tinted glass on iOS 26+, flat background on older.
    @ViewBuilder
    func badgeGlass(tint: Color, fallbackBackground: Color) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.2)), in: .capsule)
        } else {
            self.background(fallbackBackground).clipShape(Capsule())
        }
    }

    /// Section glass (rounded rect): tinted glass on iOS 26+, flat background on older.
    @ViewBuilder
    func sectionGlass(tint: Color, fallbackBackground: Color, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.1)), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(fallbackBackground).clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
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
    @State private var dragStartTrigger = false

    private var engineerColor: Color {
        if let id = device.engineerId {
            return EngineerColors.color(for: id)
        }
        return .gray
    }

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
        .boardCardGlass(
            engineerColor: engineerColor,
            isExpanded: isExpanded,
            isPressed: isPressed,
            isInProgress: device.isInProgress
        )
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.6), trigger: dragStartTrigger)
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

                // In-progress indicator (phaseAnimator replaces PulseAnimation)
                if device.isInProgress {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .phaseAnimator([1.0, 0.4]) { content, phase in
                            content.opacity(phase)
                        } animation: { _ in
                            .easeInOut(duration: 1.0)
                        }
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
                dragStartTrigger.toggle()
                onDragStart?(.zero)
            }
    }
}

// MARK: - Drag Overlay Card

/// Simplified card shown as drag overlay (follows finger/cursor)
/// Swing angle is driven by `BoardDragState.swingAngle` for physics-based tilt.
struct BoardDragOverlayCard: View {
    let device: BoardDeviceItem
    var swingAngle: Double = 0

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
        .dragOverlayGlass()
        .rotationEffect(.degrees(swingAngle))
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: swingAngle)
    }
}
