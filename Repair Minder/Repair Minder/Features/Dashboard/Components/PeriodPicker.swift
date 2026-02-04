//
//  PeriodPicker.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

enum DashboardPeriod: String, CaseIterable, Sendable {
    case today = "today"
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        }
    }
}

struct PeriodPicker: View {
    @Binding var selectedPeriod: DashboardPeriod
    let onChange: (DashboardPeriod) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardPeriod.allCases, id: \.self) { period in
                    PeriodChip(
                        title: period.displayName,
                        isSelected: selectedPeriod == period
                    ) {
                        selectedPeriod = period
                        onChange(period)
                    }
                }
            }
        }
    }
}

struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        PeriodPicker(
            selectedPeriod: .constant(.thisMonth),
            onChange: { _ in }
        )
    }
    .padding()
}
