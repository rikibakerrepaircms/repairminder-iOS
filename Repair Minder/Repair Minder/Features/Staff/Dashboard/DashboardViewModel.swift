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
    var commissionEstimate: CommissionEstimate?
    var activeWork: [ActiveWorkItem] = []
    var isLoading = false
    var error: String?

    var selectedScope: DashboardScope = AuthManager.shared.currentUser?.role.isAdmin == true ? .company : .user
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

        // Load stats, enquiry stats, commission, and active work in parallel
        async let statsTask: Void = loadStats()
        async let enquiryTask: Void = loadEnquiryStats()
        async let commissionTask: Void = loadCommissionEstimate()
        async let activeWorkTask: Void = loadActiveWork()

        // Await all tasks
        _ = await (statsTask, enquiryTask, commissionTask, activeWorkTask)

        isLoading = false
    }

    /// Refresh dashboard data
    func refresh() async {
        await loadDashboard()
    }

    // MARK: - Private Loading Methods

    private func loadStats() async {
        do {
            #if DEBUG
            print("📊 [Dashboard] Loading stats - scope: \(selectedScope.rawValue), period: \(selectedPeriod.rawValue)")
            #endif
            stats = try await APIClient.shared.request(
                .dashboardStats(scope: selectedScope.rawValue, period: selectedPeriod.rawValue)
            )
            #if DEBUG
            print("📊 [Dashboard] Stats loaded - devices: \(stats?.devices.current.count ?? -1), revenue: \(stats?.revenue.current.total ?? -1)")
            #endif
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("📊 [Dashboard] Failed to load dashboard stats: \(error)")
            #endif
        }
    }

    private func loadEnquiryStats() async {
        do {
            #if DEBUG
            print("📧 [Enquiry] Loading enquiry stats - scope: \(selectedScope.rawValue)")
            #endif
            enquiryStats = try await APIClient.shared.request(
                .enquiryStats(scope: selectedScope.rawValue, includeBreakdown: selectedScope == .company)
            )
            #if DEBUG
            if let stats = enquiryStats {
                print("📧 [Enquiry] Loaded - leads this_month: \(stats.leads.thisMonth.count), first_replies this_month: \(stats.firstReplies.thisMonth.count)")
            }
            #endif
        } catch {
            #if DEBUG
            print("📧 [Enquiry] Failed to load enquiry stats: \(error)")
            #endif
            // Don't set error for enquiry stats - it's supplementary
        }
    }

    private func loadCommissionEstimate() async {
        do {
            let result: CommissionEstimate = try await APIClient.shared.request(
                .commissionEstimate(scope: selectedScope.rawValue, period: selectedPeriod.rawValue)
            )
            commissionEstimate = result
            #if DEBUG
            print("💰 [Commission] Loaded - hasRules: \(result.hasRules), estimated: \(result.estimatedCommission ?? 0), users: \(result.users?.count ?? 0), breakdown: \(result.breakdown?.count ?? 0)")
            #endif
        } catch {
            #if DEBUG
            print("💰 [Commission] Failed to load: \(error)")
            #endif
            // Don't set error — commission is supplementary
        }
    }

    private func loadActiveWork() async {
        do {
            let response: [ActiveWorkItem] = try await APIClient.shared.request(.myActiveWork)
            activeWork = response
        } catch {
            #if DEBUG
            print("Failed to load active work: \(error)")
            #endif
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
