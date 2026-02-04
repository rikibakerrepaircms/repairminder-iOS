//
//  OrderTimeline.swift
//  Repair Minder Customer
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct OrderTimeline: View {
    let events: [TimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Timeline")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 12)

            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                TimelineRow(
                    event: event,
                    isLast: index == events.count - 1
                )
            }
        }
        .padding(.vertical)
    }
}

struct TimelineRow: View {
    let event: TimelineEvent
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(circleColor)
                    .frame(width: 14, height: 14)
                    .overlay {
                        if event.isCurrent {
                            Circle()
                                .stroke(circleColor, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        }
                    }

                if !isLast {
                    Rectangle()
                        .fill(event.isCompleted ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 40)
                }
            }

            // Event content
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(event.isCurrent ? .semibold : .medium)
                    .foregroundStyle(event.isCompleted || event.isCurrent ? .primary : .secondary)

                if let description = event.description, event.isCurrent {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let date = event.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer()
        }
        .padding(.horizontal)
    }

    private var circleColor: Color {
        if event.isCurrent {
            return .blue
        } else if event.isCompleted {
            return .green
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    OrderTimeline(events: [
        TimelineEvent(id: "1", title: "Received", date: Date().addingTimeInterval(-86400), isCompleted: true),
        TimelineEvent(id: "2", title: "Being Diagnosed", date: Date().addingTimeInterval(-43200), isCompleted: true),
        TimelineEvent(id: "3", title: "Being Repaired", date: Date(), isCompleted: false, isCurrent: true),
        TimelineEvent(id: "4", title: "Final Checks", isCompleted: false),
        TimelineEvent(id: "5", title: "Ready for Collection", isCompleted: false)
    ])
}
