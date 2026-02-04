//
//  AppState.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI
import Combine

@MainActor
@Observable
final class AppState {
    private(set) var isLoading: Bool = true
    private(set) var syncStatus: SyncEngine.SyncStatus = .idle
    private(set) var lastSyncDate: Date?
    private(set) var pendingChangesCount: Int = 0

    private let authManager = AuthManager.shared
    private let syncEngine = SyncEngine.shared
    private var observers = Set<AnyCancellable>()

    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }

    var currentUser: User? {
        authManager.currentUser
    }

    var currentCompany: Company? {
        authManager.currentCompany
    }

    var isSyncing: Bool {
        syncStatus.isInProgress
    }

    var isOffline: Bool {
        syncStatus == .offline
    }

    init() {
        setupSyncObservation()
    }

    func checkAuthStatus() async {
        isLoading = true
        await authManager.checkAuthStatus()
        isLoading = authManager.isLoading

        // Trigger initial sync if authenticated
        if isAuthenticated {
            await performSync()
        }
    }

    func logout() async {
        await authManager.logout()
    }

    func performSync() async {
        await syncEngine.performFullSync()
    }

    private func setupSyncObservation() {
        syncEngine.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
            }
            .store(in: &observers)

        syncEngine.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] date in
                self?.lastSyncDate = date
            }
            .store(in: &observers)

        syncEngine.$pendingChangesCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.pendingChangesCount = count
            }
            .store(in: &observers)
    }
}
