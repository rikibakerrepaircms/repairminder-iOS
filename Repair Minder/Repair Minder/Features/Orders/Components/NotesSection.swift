//
//  NotesSection.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct NotesSection: View {
    let notes: [Order.OrderNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(notes.indices, id: \.self) { index in
                    let note = notes[index]
                    if let body = note.body, !body.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(body)
                                .font(.subheadline)

                            HStack {
                                if let createdBy = note.createdBy {
                                    Text(createdBy)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let deviceName = note.deviceName {
                                    Text("• \(deviceName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NotesSection(notes: [
        Order.OrderNote(body: "Customer mentioned they dropped the phone in water. Check for water damage.", createdAt: "2026-02-04 10:00:00", createdBy: "John Smith", deviceId: nil, deviceName: "iPhone 14 Pro")
    ])
    .padding()
    .background(Color(.systemGroupedBackground))
}
