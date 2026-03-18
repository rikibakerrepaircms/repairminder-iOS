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
/// Supports expand/collapse (spring animation) and resize from top + bottom edges.
/// Top resize changes start time (end stays fixed), bottom resize changes duration (start stays fixed).
struct TimelineCardView: View {
    let device: BoardDeviceItem
    let scheduleItem: ScheduleItemModel
    let isExpanded: Bool
    let pixelsPerMinute: CGFloat
    let onTap: () -> Void
    let onViewDetails: () -> Void
    let onDurationChange: (Int) -> Void
    let onStartTimeChange: ((Int, Int) -> Void)? // (newStart, newDuration)
    var autoExpand: Bool = false

    @State private var resizeOffset: CGFloat = 0
    @State private var isResizing = false
    @State private var topResizeOffset: CGFloat = 0
    @State private var isResizingTop = false
    @State private var lastHapticDuration = 0
    @State private var resizeSnapTrigger = false

    private var endMinutes: Int { scheduleItem.startMinutes + scheduleItem.duration }

    private var baseHeight: CGFloat {
        CGFloat(scheduleItem.duration) * pixelsPerMinute
    }

    private var displayHeight: CGFloat {
        var h = baseHeight
        if isResizing { h = baseHeight + resizeOffset }
        if isResizingTop { h = baseHeight - topResizeOffset }
        return max(30, isExpanded ? h + 140 : h)
    }

    /// Y offset for top resize (moves the card up/down)
    var topOffset: CGFloat {
        isResizingTop ? topResizeOffset : 0
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
            // Top resize handle
            Rectangle()
                .fill(Color.clear)
                .frame(height: 8)
                .contentShape(Rectangle())
                .gesture(topResizeGesture)
                .overlay(
                    Capsule()
                        .fill(Color.platformGray4)
                        .frame(width: 30, height: 3)
                        .opacity(0.6)
                )

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

            // Bottom resize handle
            Rectangle()
                .fill(Color.clear)
                .frame(height: 8)
                .contentShape(Rectangle())
                .gesture(bottomResizeGesture)
                .overlay(
                    Capsule()
                        .fill(Color.platformGray4)
                        .frame(width: 30, height: 3)
                        .opacity(0.6)
                )
        }
        .frame(height: displayHeight)
        .timelineCardGlass(engineerColor: engineerColor, isExpanded: isExpanded, isResizing: isResizing || isResizingTop)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.4), trigger: resizeSnapTrigger)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
    }

    // MARK: - Bottom Resize Gesture (changes duration, start stays fixed)

    private var bottomResizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isResizing = true
                let rawMinutes = Int(value.translation.height / pixelsPerMinute)
                let snapped = (rawMinutes / 15) * 15
                resizeOffset = CGFloat(snapped) * pixelsPerMinute

                let newDuration = max(15, scheduleItem.duration + snapped)
                if newDuration != lastHapticDuration {
                    lastHapticDuration = newDuration
                    resizeSnapTrigger.toggle()
                }
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

    // MARK: - Top Resize Gesture (changes start time, end stays fixed)

    private var topResizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isResizingTop = true
                let rawMinutes = Int(value.translation.height / pixelsPerMinute)
                let snapped = (rawMinutes / 15) * 15
                // Clamp so duration stays >= 15min
                let maxDelta = scheduleItem.duration - 15
                let clampedSnapped = min(snapped, maxDelta)
                topResizeOffset = CGFloat(clampedSnapped) * pixelsPerMinute

                let newDuration = max(15, scheduleItem.duration - clampedSnapped)
                if newDuration != lastHapticDuration {
                    lastHapticDuration = newDuration
                    resizeSnapTrigger.toggle()
                }
            }
            .onEnded { _ in
                isResizingTop = false
                let rawDelta = Int(topResizeOffset / pixelsPerMinute)
                let snappedDelta = (rawDelta / 15) * 15
                let newStart = max(480, scheduleItem.startMinutes + snappedDelta) // clamp to 8AM
                let newDuration = endMinutes - newStart
                topResizeOffset = 0
                lastHapticDuration = 0
                if newStart != scheduleItem.startMinutes && newDuration >= 15 {
                    onStartTimeChange?(newStart, newDuration)
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
