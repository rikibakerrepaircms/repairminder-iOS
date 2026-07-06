//
//  CustomerMarketingPreferencesView.swift
//  Repair Minder
//
//  Created on 06/07/2026.
//

import SwiftUI

/// Customer-facing marketing/giveaway email consent screen.
/// Consumes GET/PUT /api/customer/marketing/preferences via `CustomerMarketingService`.
@MainActor
struct CustomerMarketingPreferencesView: View {
    @State private var prefs: CustomerMarketingPreferences?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var applyingServerState = false
    @State private var errorMessage: String?
    @State private var consent = false

    var body: some View {
        Form {
            Section(footer: Text("This controls marketing and giveaway emails only. You will always get emails about your repairs, orders and enquiries.")) {
                Toggle("Marketing and giveaway emails", isOn: $consent)
                    .disabled(isLoading || isSaving)
                    .onChange(of: consent) { _, newValue in
                        guard !applyingServerState else { return }
                        Task { await save(newValue) }
                    }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Email Preferences")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    // MARK: - Networking

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let p = try await CustomerMarketingService.shared.fetchPreferences()
            apply(p)
        } catch {
            errorMessage = "Could not load your preferences."
        }
        isLoading = false
    }

    private func save(_ newValue: Bool) async {
        isSaving = true
        errorMessage = nil
        do {
            let p = try await CustomerMarketingService.shared.updatePreferences(consent: newValue)
            apply(p)
        } catch {
            errorMessage = "Could not save that change."
            if let p = prefs { apply(p) }
        }
        isSaving = false
    }

    private func apply(_ p: CustomerMarketingPreferences) {
        applyingServerState = true
        prefs = p
        consent = p.marketingConsent
        applyingServerState = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomerMarketingPreferencesView()
    }
}
