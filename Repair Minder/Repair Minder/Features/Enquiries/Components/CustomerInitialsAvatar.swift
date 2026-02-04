//
//  CustomerInitialsAvatar.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct CustomerInitialsAvatar: View {
    let name: String
    let size: CGFloat
    let isNew: Bool

    init(name: String, size: CGFloat = 44, isNew: Bool = false) {
        self.name = name
        self.size = size
        self.isNew = isNew
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].first ?? "?")\(parts[1].first ?? "?")".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var avatarGradient: LinearGradient {
        let colors: [(Color, Color)] = [
            (.blue, .purple),
            (.green, .teal),
            (.orange, .red),
            (.pink, .purple),
            (.teal, .blue),
            (.indigo, .purple),
            (.mint, .green),
            (.cyan, .blue)
        ]
        let index = abs(name.hashValue) % colors.count
        return LinearGradient(
            colors: [colors[index].0, colors[index].1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(avatarGradient)
                .clipShape(Circle())

            if isNew {
                Circle()
                    .fill(.blue)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: size / 3, y: -size / 3)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomerInitialsAvatar(name: "John Smith", size: 60, isNew: true)
        CustomerInitialsAvatar(name: "Alice Johnson", size: 44)
        CustomerInitialsAvatar(name: "Bob", size: 40)
        CustomerInitialsAvatar(name: "Charlie Brown", size: 50, isNew: true)
    }
    .padding()
}
