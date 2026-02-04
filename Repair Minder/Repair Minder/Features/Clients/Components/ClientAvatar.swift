//
//  ClientAvatar.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ClientAvatar: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].first ?? "?")\(parts[1].first ?? "?")"
        }
        return String(name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(avatarColor)
            .clipShape(Circle())
    }
}

#Preview {
    VStack(spacing: 16) {
        ClientAvatar(name: "John Smith", size: 80)
        ClientAvatar(name: "Jane Doe", size: 60)
        ClientAvatar(name: "Bob Wilson", size: 44)
        ClientAvatar(name: "A", size: 44)
        ClientAvatar(name: "test@email.com", size: 44)
    }
    .padding()
}
