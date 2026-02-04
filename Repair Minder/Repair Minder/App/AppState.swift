//
//  AppState.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI

@MainActor
@Observable
final class AppState {
    private(set) var isLoading: Bool = true

    private let authManager = AuthManager.shared

    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }

    var currentUser: User? {
        authManager.currentUser
    }

    var currentCompany: Company? {
        authManager.currentCompany
    }

    func checkAuthStatus() async {
        isLoading = true
        await authManager.checkAuthStatus()
        isLoading = authManager.isLoading
    }

    func logout() async {
        await authManager.logout()
    }
}
