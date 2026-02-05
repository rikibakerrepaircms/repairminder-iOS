//
//  DashboardViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Dashboard View Model

/// View model for the staff dashboard
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - Published State

    var stats: DashboardStats?
    var enquiryStats: EnquiryStats?
    var activeWork: [ActiveWorkItem] = []
    var isLoading = false
    var error: String?

    var selectedScope: DashboardScope = .user
    var selectedPeriod: StatPeriod = .thisMonth

    // MARK: - Computed Properties

    /// First comparison from device stats
    var deviceComparison: StatComparison? {
        stats?.devices.comparisons.first
    }

    /// First comparison from revenue stats
    var revenueComparison: StatComparison? {
        stats?.revenue.comparisons.first
    }

    /// First comparison from client stats
    var clientComparison: StatComparison? {
        stats?.clients.comparisons.first
    }

    /// First comparison from new client stats
    var newClientComparison: StatComparison? {
        stats?.newClients.comparisons.first
    }

    /// Whether there is active work in progress
    var hasActiveWork: Bool {
        !activeWork.isEmpty
    }

    // MARK: - Data Loading

    /// Load all dashboard data
    func loadDashboard() async {
        isLoading = true
        error = nil

        // Load stats, enquiry stats, and active work in parallel
        async let statsTask = loadStats()
        async let enquiryTask = loadEnquiryStats()
        async let activeWorkTask = loadActiveWork()

        // Await all tasks
        _ = await (statsTask, enquiryTask, activeWorkTask)

        isLoading = false
    }

    /// Refresh dashboard data
    func refresh() async {
        await loadDashboard()
    }

    // MARK: - Private Loading Methods

    private func loadStats() async {
        do {
            print("📊 [Dashboard] Loading stats - scope: \(selectedScope.rawValue), period: \(selectedPeriod.rawValue)")
            stats = try await APIClient.shared.request(
                .dashboardStats(scope: selectedScope.rawValue, period: selectedPeriod.rawValue)
            )
            print("📊 [Dashboard] Stats loaded - devices: \(stats?.devices.current.count ?? -1), revenue: \(stats?.revenue.current.total ?? -1)")
        } catch {
            self.error = error.localizedDescription
            print("📊 [Dashboard] Failed to load dashboard stats: \(error)")
        }
    }

    private func loadEnquiryStats() async {
        do {
            enquiryStats = try await APIClient.shared.request(
                .enquiryStats(scope: selectedScope.rawValue, includeBreakdown: selectedScope == .company)
            )
        } catch {
            print("Failed to load enquiry stats: \(error)")
            // Don't set error for enquiry stats - it's supplementary
        }
    }

    private func loadActiveWork() async {
        do {
            let response: [ActiveWorkItem] = try await APIClient.shared.request(.myActiveWork)
            activeWork = response
        } catch {
            print("Failed to load active work: \(error)")
            // Don't set error for active work - it's supplementary
        }
    }

    // MARK: - Scope & Period Changes

    /// Change the dashboard scope
    func setScope(_ scope: DashboardScope) async {
        guard scope != selectedScope else { return }
        selectedScope = scope
        await loadDashboard()
    }

    /// Change the time period
    func setPeriod(_ period: StatPeriod) async {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        await loadDashboard()
    }
}
