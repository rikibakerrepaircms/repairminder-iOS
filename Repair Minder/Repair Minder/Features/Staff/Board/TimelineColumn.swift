//
//  TimelineColumn.swift
//  Repair Minder
//
//  Created on 18/03/2026.
//

import SwiftUI

// MARK: - Timeline Column

/// Vertical timeline pinned column with time scale, hour gridlines,
/// current-time indicator, and positioned cards.
/// Work hours default to 8:00 AM – 5:00 PM; pixelsPerMinute = 2.5.
struct TimelineColumn: View {
    let devices: [BoardDeviceItem]
    let scheduleItems: [ScheduleItemModel]
    let onDeviceTap: (BoardDeviceItem) -> Void
    let onDurationChange: (String, Int) -> Void // (itemId, newDuration)

    @State private var expandedDeviceId: String?

    // Timeline constants
    private let workStartMinutes = 480  // 8:00 AM
    private let workEndMinutes = 1020   // 5:00 PM
    private let pixelsPerMinute: CGFloat = 2.5

    private var totalMinutes: Int { workEndMinutes - workStartMinutes }
    private var totalHeight: CGFloat { CGFloat(totalMinutes) * pixelsPerMinute }

    private func minutesToY(_ minutes: Int) -> CGFloat {
        CGFloat(minutes - workStartMinutes) * pixelsPerMinute
    }

    /// Schedule items matched with their devices, sorted by start time
    private var scheduledPairs: [(item: ScheduleItemModel, device: BoardDeviceItem)] {
        scheduleItems.compactMap { item in
            guard let device = devices.first(where: { $0.id == item.deviceId }) else { return nil }
            return (item: item, device: device)
        }
        .sorted { $0.item.startMinutes < $1.item.startMinutes }
    }

    /// Hour markers for gridlines
    private var hourMarkers: [Int] {
        let startHour = (workStartMinutes / 60) * 60
        let endHour = ((workEndMinutes + 59) / 60) * 60
        return Array(stride(from: startHour, through: endHour, by: 60))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            columnHeader

            Divider()

            // Timeline scroll area
            if scheduledPairs.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Hour gridlines
                        ForEach(hourMarkers, id: \.self) { minutes in
                            gridLine(at: minutes)
                        }

                        // Current time indicator
                        VerticalTimeIndicator(
                            workStartMinutes: workStartMinutes,
                            workEndMinutes: workEndMinutes,
                            pixelsPerMinute: pixelsPerMinute
                        )

                        // Scheduled cards
                        ForEach(scheduledPairs, id: \.item.id) { pair in
                            let cardY = minutesToY(pair.item.startMinutes)
                            let isExpanded = expandedDeviceId == pair.device.id

                            TimelineCardView(
                                device: pair.device,
                                scheduleItem: pair.item,
                                isExpanded: isExpanded,
                                pixelsPerMinute: pixelsPerMinute,
                                onTap: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        expandedDeviceId = expandedDeviceId == pair.device.id ? nil : pair.device.id
                                    }
                                },
                                onViewDetails: { onDeviceTap(pair.device) },
                                onDurationChange: { newDuration in
                                    onDurationChange(pair.item.id, newDuration)
                                }
                            )
                            .padding(.leading, 36)
                            .padding(.trailing, 4)
                            .offset(y: cardY)
                            .zIndex(isExpanded ? 10 : 1)
                        }
                    }
                    .frame(height: totalHeight + 16, alignment: .topLeading)
                    .padding(.top, 8)
                }
            }
        }
        .timelineContainerGlass()
    }

    // MARK: - Header

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .foregroundStyle(.orange)
                .font(.caption)

            Text("Due Today")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text("\(scheduledPairs.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.platformGray5)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Grid Line

    private func gridLine(at minutes: Int) -> some View {
        let y = minutesToY(minutes)
        return HStack(spacing: 4) {
            Text(formatHour(minutes))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)

            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 0.5)
        }
        .offset(y: y)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No devices scheduled today")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: - Helpers

    private func formatHour(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h)
        return m == 0 ? "\(displayHour) \(period)" : String(format: "%d:%02d %@", displayHour, m, period)
    }
}
