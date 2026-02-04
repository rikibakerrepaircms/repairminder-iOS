//
//  UserProfileHeader.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct UserProfileHeader: View {
    let user: User
    let company: Company?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(user.initials)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.gradient)
                .clipShape(Circle())
                .accessibilityHidden(true)

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(user.role.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(roleColor.gradient)
                        .clipShape(Capsule())

                    if let company = company {
                        Text(company.name)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.displayName), \(user.role.displayName)")
    }

    private var roleColor: Color {
        switch user.role {
        case .masterAdmin:
            return .purple
        case .admin:
            return .blue
        case .seniorEngineer:
            return .orange
        case .engineer:
            return .green
        case .office:
            return .teal
        case .custom:
            return .gray
        }
    }
}

#Preview {
    List {
        UserProfileHeader(
            user: User.preview,
            company: Company.preview
        )
    }
}

// MARK: - Preview Helpers

extension User {
    static var preview: User {
        try! JSONDecoder().decode(User.self, from: """
        {
            "id": "preview-user",
            "email": "john@example.com",
            "username": "johndoe",
            "firstName": "John",
            "lastName": "Doe",
            "companyId": "preview-company",
            "role": "admin",
            "isActive": 1,
            "verified": 1,
            "twoFactorEnabled": 0,
            "magicLinkEnabled": 1
        }
        """.data(using: .utf8)!)
    }
}

extension Company {
    static var preview: Company {
        try! JSONDecoder().decode(Company.self, from: """
        {
            "id": "preview-company",
            "name": "Acme Repairs",
            "domain": "acme.com",
            "isActive": 1,
            "currencyCode": "GBP",
            "depositsEnabled": 1
        }
        """.data(using: .utf8)!)
    }
}
