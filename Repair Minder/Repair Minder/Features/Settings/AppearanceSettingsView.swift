//
//  AppearanceSettingsView.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance: Appearance = .system

    var body: some View {
        List {
            Section {
                ForEach(Appearance.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appearance = option
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.title3)
                                .foregroundStyle(option == appearance ? Color.accentColor : Color.secondary)
                                .frame(width: 28)

                            Text(option.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if appearance == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(appearance == option ? .isSelected : [])
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("System follows your device's appearance setting. Changes apply immediately.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
