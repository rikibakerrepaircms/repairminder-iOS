//
//  DeviceQueueRow.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Queue Row

/// Row component for displaying a device in the work queue
struct DeviceQueueRow: View {
    let device: DeviceQueueItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                statusIndicator

                // Main content
                VStack(alignment: .leading, spacing: 4) {
                    // Device name and order number
                    HStack {
                        Text(device.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let orderNumber = device.orderNumber {
                            Text("#\(String(orderNumber))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Status badge and metadata
                    HStack(spacing: 8) {
                        DeviceStatusBadge(status: device.deviceStatus)

                        if device.isOverdue {
                            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        if let dueDate = device.formattedDueDate {
                            Text(dueDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Sub-location or notes preview
                    if let subLocation = device.subLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(subLocation.code)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    } else if let notePreview = device.notePreview {
                        Text(notePreview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Checklist progress or chevron
                VStack(alignment: .trailing, spacing: 4) {
                    if device.checklistProgress > 0 && device.checklistProgress < 100 {
                        CircularProgress(progress: Double(device.checklistProgress) / 100.0)
                            .frame(width: 24, height: 24)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(device.deviceStatus.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Circular Progress

/// Small circular progress indicator
struct CircularProgress: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Active Work Row

/// Row for displaying active work (diagnosis/repair in progress)
struct ActiveWorkRow: View {
    let item: ActiveWorkItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Work type icon
                Image(systemName: item.activeWorkType.icon)
                    .font(.title3)
                    .foregroundStyle(item.isLongRunning ? .orange : .blue)
                    .frame(width: 32)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(item.activeWorkType.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)

                        Text("#\(String(item.orderNumber))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.duration)
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(item.isLongRunning ? .orange : .primary)

                    if item.isLongRunning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Queue Category Filter

/// Horizontal filter chips for queue categories
struct QueueCategoryFilter: View {
    @Binding var selectedCategory: QueueCategory
    let categoryCounts: QueueFilters.CategoryCounts

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QueueCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        count: count(for: category),
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func count(for category: QueueCategory) -> Int {
        switch category {
        case .all: return categoryCounts.total
        case .repair: return categoryCounts.repair ?? 0
        case .buyback: return categoryCounts.buyback ?? 0
        case .unassigned: return categoryCounts.unassigned ?? 0
        }
    }
}

/// Individual category filter chip
struct CategoryChip: View {
    let category: QueueCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.displayName)
                    .font(.subheadline.weight(.medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color(.tertiarySystemFill))
                        .cornerRadius(8)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    List {
        DeviceQueueRow(
            device: DeviceQueueItem(
                id: "1",
                orderId: "order-1",
                ticketId: "ticket-1",
                orderNumber: 100001234,
                displayName: "iPhone 15 Pro Max",
                serialNumber: "ABC123",
                imei: nil,
                colour: "Black",
                status: "diagnosing",
                workflowType: "repair",
                deviceType: DeviceTypeInfo(id: "1", name: "Repair", slug: "repair"),
                assignedEngineer: AssignedEngineerInfo(id: "1", name: "John Smith"),
                locationId: nil,
                subLocationId: nil,
                subLocation: SubLocationInfo(id: "1", code: "A1-B2", description: "Shelf A1, Bin B2", type: "shelf", locationId: "loc1"),
                createdAt: "2026-02-04T10:00:00Z",
                dueDate: "2026-02-05T17:00:00Z",
                receivedAt: "2026-02-04T10:00:00Z",
                scheduled: nil,
                canCompleteReport: false,
                canCompleteRepair: false,
                preTestPhotosCount: 3,
                notes: [DeviceNote(body: "Customer reported screen flickering", createdAt: "2026-02-04T10:00:00Z", createdBy: "Staff", deviceId: nil)],
                checklist: nil,
                source: "order"
            )
        ) {
            print("Tapped")
        }
    }
}
