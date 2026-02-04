//
//  EnquiryFilterChips.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct EnquiryFilterChips: View {
    @Binding var selectedFilter: EnquiryFilter
    let counts: [EnquiryFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EnquiryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        count: counts[filter] ?? 0,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let filter: EnquiryFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedFilter: EnquiryFilter = .all

    EnquiryFilterChips(
        selectedFilter: $selectedFilter,
        counts: [
            .all: 25,
            .new: 5,
            .pending: 12,
            .awaitingCustomer: 8
        ]
    )
    .padding()
}
