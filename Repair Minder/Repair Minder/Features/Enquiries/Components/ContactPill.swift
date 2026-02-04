//
//  ContactPill.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI
import UIKit

struct ContactPill: View {
    let icon: String
    let value: String

    enum Action {
        case call
        case email
    }
    let action: Action

    var body: some View {
        Button {
            switch action {
            case .call:
                if let url = URL(string: "tel:\(value.replacingOccurrences(of: " ", with: ""))") {
                    openURL(url)
                }
            case .email:
                if let url = URL(string: "mailto:\(value)") {
                    openURL(url)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(displayValue)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var displayValue: String {
        switch action {
        case .call:
            return value
        case .email:
            // Truncate long emails
            if value.count > 25 {
                return String(value.prefix(22)) + "..."
            }
            return value
        }
    }

    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

#Preview {
    VStack(spacing: 12) {
        ContactPill(icon: "phone.fill", value: "07123456789", action: .call)
        ContactPill(icon: "envelope.fill", value: "john@example.com", action: .email)
        ContactPill(icon: "envelope.fill", value: "verylongemail@verylongdomain.com", action: .email)
    }
    .padding()
}
