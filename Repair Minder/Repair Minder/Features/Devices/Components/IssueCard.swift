//
//  IssueCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct IssueCard: View {
    let issue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reported Issue", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(issue)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 20) {
        IssueCard(issue: "Screen is cracked and not responding to touch. Customer reports the phone was dropped from waist height onto concrete.")

        IssueCard(issue: "Battery drains quickly")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
