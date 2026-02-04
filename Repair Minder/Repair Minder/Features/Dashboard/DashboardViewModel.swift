//
//  DashboardViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine
import os.log

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var stats: DashboardStats?
    private(set) var recentOrders: [Order] = []
    private(set) var myQueue: [Device] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?
    var selectedPeriod: DashboardPeriod = .thisMonth

    private let syncEngine = SyncEngine.shared
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "Dashboard")
    private var cancellables = Set<AnyCancellable>()

    var syncStatus: SyncEngine.SyncStatus {
        syncEngine.status
    }

    var pendingChangesCount: Int {
        syncEngine.pendingChangesCount
    }

    init() {
        observeSyncStatus()
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        do {
            // Fetch stats from API
            stats = try await APIClient.shared.request(
                .dashboardStats(scope: "user", period: selectedPeriod.rawValue),
                responseType: DashboardStats.self
            )

            // Fetch recent orders
            let ordersResponse: [Order] = try await APIClient.shared.request(
                .orders(page: 1, limit: 5),
                responseType: [Order].self
            )
            recentOrders = ordersResponse

            // Fetch my queue
            let queueResponse: [Device] = try await APIClient.shared.request(
                .myQueue(page: 1, limit: 10),
                responseType: [Device].self
            )
            myQueue = queueResponse

            logger.debug("Dashboard loaded successfully")
        } catch {
            self.error = error.localizedDescription
            logger.error("Dashboard load failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func refresh() async {
        await loadDashboard()
    }

    func changePeriod(to period: DashboardPeriod) {
        selectedPeriod = period
        Task {
            await loadDashboard()
        }
    }

    private func observeSyncStatus() {
        syncEngine.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Trigger view update when sync status changes
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        syncEngine.$pendingChangesCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // Need to provide ObjectWillChangePublisher for @Observable
    let objectWillChange = ObservableObjectPublisher()
}
