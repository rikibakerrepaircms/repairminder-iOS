//
//  SettingsViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class SettingsViewModel {
    var showLogoutConfirmation = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var currentUser: User? {
        appState.currentUser
    }

    var currentCompany: Company? {
        appState.currentCompany
    }

    func logout() async {
        await appState.logout()
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func openHelpCenter() {
        if let url = URL(string: "https://repairminder.com/help") {
            UIApplication.shared.open(url)
        }
    }

    func openContactSupport() {
        if let url = URL(string: "mailto:support@repairminder.com") {
            UIApplication.shared.open(url)
        }
    }
}
