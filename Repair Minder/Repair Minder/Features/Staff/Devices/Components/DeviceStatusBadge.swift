//
//  DeviceStatusBadge.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Status Badge

/// Badge displaying device status with appropriate color
struct DeviceStatusBadge: View {
    let status: DeviceStatus
    var size: BadgeSize = .regular

    enum BadgeSize {
        case small
        case regular
        case large

        var font: Font {
            switch self {
            case .small: return .caption2
            case .regular: return .caption
            case .large: return .footnote
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .regular: return 4
            case .large: return 5
            }
        }
    }

    var body: some View {
        Text(status.label)
            .font(size.font.weight(.medium))
            .foregroundStyle(status.color)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(status.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Workflow Type Badge

/// Badge displaying device workflow type
struct WorkflowTypeBadge: View {
    let workflowType: DeviceWorkflowType

    var body: some View {
        Label(workflowType.displayName, systemImage: workflowType.icon)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.platformGray5)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Priority Badge

/// Badge displaying device priority
struct PriorityBadge: View {
    let priority: DevicePriority

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
            Text(priority.displayName)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(priorityColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priorityColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var priorityColor: Color {
        switch priority {
        case .normal: return .secondary
        case .urgent: return .orange
        case .express: return .red
        }
    }
}

// MARK: - Overdue Badge

/// Badge indicating device is overdue
struct OverdueBadge: View {
    var body: some View {
        Label("Overdue", systemImage: "clock.badge.exclamationmark")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Status badges
        VStack(alignment: .leading, spacing: 8) {
            Text("Status Badges").font(.headline)
            HStack {
                DeviceStatusBadge(status: .deviceReceived, size: .small)
                DeviceStatusBadge(status: .diagnosing)
                DeviceStatusBadge(status: .repairing, size: .large)
            }
            HStack {
                DeviceStatusBadge(status: .repairedReady)
                DeviceStatusBadge(status: .collected)
            }
            HStack {
                DeviceStatusBadge(status: .awaitingAuthorisation)
                DeviceStatusBadge(status: .rejected)
            }
        }

        Divider()

        // Workflow badges
        VStack(alignment: .leading, spacing: 8) {
            Text("Workflow Badges").font(.headline)
            HStack {
                WorkflowTypeBadge(workflowType: .repair)
                WorkflowTypeBadge(workflowType: .buyback)
            }
        }

        Divider()

        // Priority badges
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority Badges").font(.headline)
            HStack {
                PriorityBadge(priority: .normal)
                PriorityBadge(priority: .urgent)
                PriorityBadge(priority: .express)
            }
        }

        Divider()

        // Overdue badge
        VStack(alignment: .leading, spacing: 8) {
            Text("Overdue Badge").font(.headline)
            OverdueBadge()
        }
    }
    .padding()
}
