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
    @State private var isDimming = false

    var body: some View {
        ZStack {
            // Background image with overlay
            GeometryReader { geo in
                Image("login_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            Color.black.opacity(isDimming ? 0.7 : 0.4)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: isDimming)

            VStack(spacing: 0) {
                // App logo — pinned near top, above the mascot's head
                VStack(spacing: 12) {
                    Image("login_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)

                    Text("Which best describes you?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 60)

                Spacer()

                // Role selection buttons — bottom third
                VStack(spacing: 16) {
                    ForEach(AppUserRole.allCases, id: \.self) { role in
                        RoleButton(role: role) {
                            selectRole(role)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .opacity(isDimming ? 0 : 1)
                .animation(.easeOut(duration: 0.3), value: isDimming)

                Spacer()
                    .frame(height: 60)
            }
            .padding()
        }
    }

    private func selectRole(_ role: AppUserRole) {
        isDimming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task {
                await appState.selectRole(role)
            }
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
            .background(Color.platformBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleSelectionView()
}
