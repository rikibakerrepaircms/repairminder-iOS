//
//  DeviceDetailViewModel.swift
//  Repair Minder
//
//  Created on 04/02/2026.
//

import SwiftUI

// MARK: - Device Detail View Model

/// View model for device detail screen
@MainActor
@Observable
final class DeviceDetailViewModel {

    // MARK: - State

    var device: DeviceDetail?
    var availableActions: [DeviceAction] = []
    var isLoading = false
    var isUpdating = false
    var error: String?
    var successMessage: String?

    // MARK: - Configuration

    let orderId: String
    let deviceId: String

    init(orderId: String, deviceId: String) {
        self.orderId = orderId
        self.deviceId = deviceId
    }

    // MARK: - Computed Properties

    /// Whether device data is loaded
    var isLoaded: Bool {
        device != nil
    }

    /// Device status
    var status: DeviceStatus {
        device?.deviceStatus ?? .deviceReceived
    }

    /// Device workflow type
    var workflow: DeviceWorkflowType {
        device?.workflow ?? .repair
    }

    /// Actions available from device page context
    var devicePageActions: [DeviceAction] {
        availableActions.filter { $0.isDevicePageAction }
    }

    /// Actions available from order page context
    var orderPageActions: [DeviceAction] {
        availableActions.filter { !$0.isDevicePageAction }
    }

    // MARK: - Data Loading

    /// Load device details
    func loadDevice() async {
        isLoading = true
        error = nil

        do {
            device = try await APIClient.shared.request(
                .orderDevice(orderId: orderId, deviceId: deviceId)
            )
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            print("Failed to load device: \(error)")
        }

        isLoading = false
    }

    /// Refresh device data
    func refresh() async {
        await loadDevice()
    }

    /// Load available actions for the device
    func loadActions() async {
        do {
            let response: DeviceActionsResponse = try await APIClient.shared.request(
                .deviceActions(orderId: orderId, deviceId: deviceId)
            )
            availableActions = response.availableActions
        } catch {
            print("Failed to load actions: \(error)")
            availableActions = []
        }
    }

    // MARK: - Device Updates

    /// Update device fields
    func updateDevice(_ request: DeviceUpdateRequest) async {
        isUpdating = true
        error = nil

        do {
            device = try await APIClient.shared.request(
                .updateOrderDevice(orderId: orderId, deviceId: deviceId),
                body: request
            )
            successMessage = "Device updated"
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            print("Failed to update device: \(error)")
        }

        isUpdating = false
    }

    /// Update device status
    func updateStatus(to newStatus: DeviceStatus, notes: String? = nil, context: StatusUpdateContext = .devicePage) async {
        isUpdating = true
        error = nil

        do {
            let request = DeviceStatusUpdateRequest(status: newStatus, context: context, notes: notes)
            device = try await APIClient.shared.request(
                .updateDeviceStatus(orderId: orderId, deviceId: deviceId),
                body: request
            )
            successMessage = "Status updated to \(newStatus.label)"
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            print("Failed to update status: \(error)")
        }

        isUpdating = false
    }

    /// Execute a device action
    func executeAction(_ action: DeviceAction, notes: String? = nil) async {
        isUpdating = true
        error = nil

        do {
            let request = DeviceActionRequest(
                action: action.toStatus,
                notes: notes,
                context: action.isDevicePageAction ? .devicePage : .orderPage
            )
            device = try await APIClient.shared.request(
                .executeDeviceAction(orderId: orderId, deviceId: deviceId),
                body: request
            )
            successMessage = action.label
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            print("Failed to execute action: \(error)")
        }

        isUpdating = false
    }

    // MARK: - Quick Updates

    /// Update assigned engineer
    func assignEngineer(_ engineerId: String?) async {
        await updateDevice(.assignEngineer(engineerId))
    }

    /// Update device priority
    func setPriority(_ priority: DevicePriority) async {
        await updateDevice(.priority(priority))
    }

    /// Update device sub-location
    func setSubLocation(_ subLocationId: String?) async {
        await updateDevice(.subLocation(subLocationId))
    }

    /// Update diagnosis notes
    func updateDiagnosisNotes(_ notes: String) async {
        await updateDevice(.diagnosisNotes(notes))
    }

    /// Update technician found issues
    func updateTechnicianFoundIssues(_ issues: String) async {
        await updateDevice(.technicianFoundIssues(issues))
    }

    /// Update repair notes
    func updateRepairNotes(_ notes: String) async {
        await updateDevice(.repairNotes(notes))
    }

    // MARK: - Message Handling

    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
    }

    /// Clear error
    func clearError() {
        error = nil
    }
}
