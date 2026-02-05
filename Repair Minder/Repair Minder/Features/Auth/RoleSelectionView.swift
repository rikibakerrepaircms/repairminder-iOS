//
//  RoleSelectionView.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

/// Initial screen where users choose between Staff and Customer portals
struct RoleSelectionView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        ZStack {
            // Background image with overlay
            Image("login_background")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App logo
                VStack(spacing: 16) {
                    Image("login_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)

                    Text("Which best describes you?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Role selection buttons
                VStack(spacing: 16) {
                    ForEach(AppUserRole.allCases, id: \.self) { role in
                        RoleButton(role: role) {
                            Task {
                                await appState.selectRole(role)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Role Button

private struct RoleButton: View {
    let role: AppUserRole
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: role.iconName)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(role.displayName)
                        .font(.headline)

                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleSelectionView()
}
