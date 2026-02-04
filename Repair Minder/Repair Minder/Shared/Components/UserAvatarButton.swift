//
//  UserAvatarButton.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct UserAvatarButton: View {
    let user: User?
    @State private var showProfile = false

    var body: some View {
        Button {
            showProfile = true
        } label: {
            if let user = user {
                Text(user.initials)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle")
                    .font(.title2)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheetView(user: user)
        }
    }
}

struct ProfileSheetView: View {
    let user: User?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                if let user = user {
                    Section {
                        HStack {
                            Text(user.initials)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        LabeledContent("Role", value: user.role.displayName)
                        if let company = appState.currentCompany {
                            LabeledContent("Company", value: company.name)
                        }
                    }

                    Section {
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await appState.logout()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserAvatarButton(user: nil)
        .environment(AppState())
}
