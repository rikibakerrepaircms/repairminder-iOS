//
//  TimelineCardView.swift
//  Repair Minder
//
//  Created on 18/03/2026.
//

import SwiftUI

// MARK: - Timeline Card View

/// Card positioned at a scheduled time in the vertical timeline.
/// Shows engineer colour stripe, time range, device name.
/// Supports expand/collapse (spring animation) and resize from bottom edge.
struct TimelineCardView: View {
    let device: BoardDeviceItem
    let scheduleItem: ScheduleItemModel
    let isExpanded: Bool
    let pixelsPerMinute: CGFloat
    let onTap: () -> Void
    let onViewDetails: () -> Void
    let onDurationChange: (Int) -> Void

    @State private var resizeOffset: CGFloat = 0
    @State private var isResizing = false
    @State private var lastHapticDuration = 0

    private var baseHeight: CGFloat {
        CGFloat(scheduleItem.duration) * pixelsPerMinute
    }

    private var displayHeight: CGFloat {
        let h = isResizing ? baseHeight + resizeOffset : baseHeight
        return max(30, isExpanded ? h + 140 : h)
    }

    private var engineerColor: Color {
        if let id = device.engineerId {
            return EngineerColors.color(for: id)
        }
        return .gray.opacity(0.3)
    }

    private var timeRange: String {
        let start = scheduleItem.startMinutes
        let end = start + scheduleItem.duration
        return "\(formatMinutes(start)) – \(formatMinutes(end))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(spacing: 0) {
                // Left colour stripe (3px)
                engineerColor
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    // Time range
                    Text(timeRange)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    // Device name
                    Text(device.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    // Order number (collapsed only)
                    if !isExpanded, let num = device.orderNumber {
                        Text("#\(num)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

                Spacer(minLength: 0)
            }

            // Expanded content
            if isExpanded {
                CardExpandedContent(
                    device: device,
                    onViewDetails: { onViewDetails() }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)

            // Resize handle at bottom
            Rectangle()
                .fill(Color.clear)
                .frame(height: 8)
                .contentShape(Rectangle())
                .gesture(resizeGesture)
                .overlay(
                    Capsule()
                        .fill(Color.platformGray4)
                        .frame(width: 30, height: 3)
                        .opacity(0.6)
                )
        }
        .frame(height: displayHeight)
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
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
    }

    // MARK: - Resize Gesture

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isResizing = true
                // Snap to 15-minute intervals
                let rawMinutes = Int(value.translation.height / pixelsPerMinute)
                let snapped = (rawMinutes / 15) * 15
                resizeOffset = CGFloat(snapped) * pixelsPerMinute

                // Haptic on snap boundary change
                let newDuration = max(15, scheduleItem.duration + snapped)
                #if os(iOS)
                if newDuration != lastHapticDuration {
                    lastHapticDuration = newDuration
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                #endif
            }
            .onEnded { _ in
                isResizing = false
                let rawDuration = Int((baseHeight + resizeOffset) / pixelsPerMinute)
                let snapped = max(15, (rawDuration / 15) * 15)
                resizeOffset = 0
                lastHapticDuration = 0
                if snapped != scheduleItem.duration {
                    onDurationChange(snapped)
                }
            }
    }

    // MARK: - Helpers

    private func formatMinutes(_ m: Int) -> String {
        let h = m / 60
        let min = m % 60
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h)
        return min == 0 ? "\(displayHour) \(period)" : String(format: "%d:%02d %@", displayHour, min, period)
    }
}
