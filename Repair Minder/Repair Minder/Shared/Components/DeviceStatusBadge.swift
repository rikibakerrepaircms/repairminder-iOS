//
//  DeviceStatusBadge.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

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
            case .large: return .subheadline
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 6
            case .regular: return 8
            case .large: return 12
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 2
            case .regular: return 4
            case .large: return 6
            }
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(size.font)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .received:
            return .blue
        case .bookedIn:
            return .blue
        case .diagnosing:
            return .purple
        case .awaitingApproval:
            return .orange
        case .approved:
            return .teal
        case .inRepair:
            return .indigo
        case .awaitingParts:
            return .yellow
        case .repaired:
            return .mint
        case .qualityCheck:
            return .cyan
        case .ready:
            return .green
        case .repairedReady:
            return .green
        case .collected:
            return .gray
        case .unrepairable:
            return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.15)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(DeviceStatus.allCases, id: \.self) { status in
            HStack {
                DeviceStatusBadge(status: status, size: .small)
                DeviceStatusBadge(status: status, size: .regular)
                DeviceStatusBadge(status: status, size: .large)
            }
        }
    }
    .padding()
}
