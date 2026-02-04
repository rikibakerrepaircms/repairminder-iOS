//
//  ContactActionsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ContactActionsView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 16) {
            if let phone = client.phone, !phone.isEmpty,
               let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                ContactButton(icon: "phone.fill", title: "Call", url: url)
            }

            if let url = URL(string: "mailto:\(client.email)") {
                ContactButton(icon: "envelope.fill", title: "Email", url: url)
            }

            if let phone = client.phone, !phone.isEmpty,
               let url = URL(string: "sms:\(phone.replacingOccurrences(of: " ", with: ""))") {
                ContactButton(icon: "message.fill", title: "Message", url: url)
            }
        }
    }
}

struct ContactButton: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContactActionsView(client: .sample)
        .padding()
        .background(Color(.systemGroupedBackground))
}
