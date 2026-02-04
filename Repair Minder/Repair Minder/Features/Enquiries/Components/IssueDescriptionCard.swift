//
//  IssueDescriptionCard.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct IssueDescriptionCard: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Issue Description", systemImage: "exclamationmark.bubble")
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    IssueDescriptionCard(
        description: "The screen is completely cracked and there are some display issues. The touch doesn't respond in the bottom half of the screen. I dropped it yesterday and it's been like this since. I need this fixed urgently as it's my work phone."
    )
    .padding()
}
