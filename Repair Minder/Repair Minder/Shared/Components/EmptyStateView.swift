//
//  EmptyStateView.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "doc.text",
        title: "No Orders",
        message: "You don't have any orders yet",
        actionTitle: "Create Order"
    ) {
        print("Create tapped")
    }
}

#Preview("No Action") {
    EmptyStateView(
        icon: "magnifyingglass",
        title: "No Results",
        message: "Try adjusting your search criteria"
    )
}
