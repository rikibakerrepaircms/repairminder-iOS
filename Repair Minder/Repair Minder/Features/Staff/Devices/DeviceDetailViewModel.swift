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
        availableActions.filter { $0.isDevicePageAction ?? true }
    }

    /// Actions available from order page context
    var orderPageActions: [DeviceAction] {
        availableActions.filter { ($0.isDevicePageAction ?? true) == false }
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
            #if DEBUG
            print("Failed to load device: \(error)")
            #endif
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
            #if DEBUG
            print("Failed to load actions: \(error)")
            #endif
            availableActions = []
        }
    }

    // MARK: - Device Updates

    /// Update device fields
    func updateDevice(_ request: DeviceUpdateRequest) async {
        isUpdating = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .updateOrderDevice(orderId: orderId, deviceId: deviceId),
                body: request
            )
            successMessage = "Device updated"
            await loadDevice()
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to update device: \(error)")
            #endif
        }

        isUpdating = false
    }

    /// Update device status
    func updateStatus(to newStatus: DeviceStatus, notes: String? = nil, context: StatusUpdateContext = .devicePage) async {
        isUpdating = true
        error = nil

        do {
            let request = DeviceStatusUpdateRequest(status: newStatus, context: context, notes: notes)
            try await APIClient.shared.requestVoid(
                .updateDeviceStatus(orderId: orderId, deviceId: deviceId),
                body: request
            )
            successMessage = "Status updated to \(newStatus.label)"
            await loadDevice()
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to update status: \(error)")
            #endif
        }

        isUpdating = false
    }

    /// Execute a device action
    /// - Parameters:
    ///   - action: The action to execute
    ///   - notes: Optional free-text notes (sent as `notes` in body when present)
    ///   - inputs: Values collected for `action.requiresInput` keys, keyed by the
    ///             exact Worker field name (e.g. `["tracking_number": "TRK123"]`)
    func executeAction(_ action: DeviceAction, notes: String? = nil, inputs: [String: String] = [:]) async {
        isUpdating = true
        error = nil

        do {
            let request = DeviceActionRequest(
                toStatus: action.toStatus,
                notes: notes,
                context: (action.isDevicePageAction ?? true) ? .devicePage : .orderPage,
                inputs: inputs
            )
            try await APIClient.shared.requestVoid(
                .executeDeviceAction(orderId: orderId, deviceId: deviceId),
                body: request
            )
            successMessage = action.label
            await loadDevice()
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to execute action: \(error)")
            #endif
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

    // MARK: - Accessories

    /// Mark an accessory as returned
    func markAccessoryReturned(accessoryId: String) async {
        isUpdating = true
        error = nil
        do {
            try await APIClient.shared.requestVoid(
                .returnDeviceAccessory(orderId: orderId, deviceId: deviceId, accessoryId: accessoryId)
            )
            await loadDevice()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to mark accessory returned: \(error)")
            #endif
        }
        isUpdating = false
    }

    // MARK: - Parts

    /// Allocates an in-stock inventory asset onto this device as a used part.
    /// Reuses the Inventory feature's allocate endpoint (`POST /api/assets/:id/allocate`)
    /// with `device_id` set to this device — the same contract `DeployToOrderWizard`
    /// uses with `order_id` for orders.
    /// Returns nil on success (device is refreshed), or a human-readable error message.
    func allocatePart(assetId: String) async -> String? {
        isUpdating = true
        defer { isUpdating = false }
        do {
            _ = try await InventoryService().allocateAsset(
                id: assetId,
                body: AllocateRequest(deviceId: deviceId, deploy: false)
            )
            await loadDevice()
            return nil
        } catch {
            #if DEBUG
            print("Failed to allocate part: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    // MARK: - Cancel Work

    /// Cancel in-progress work on this device
    func cancelWork(reason: String?) async {
        isUpdating = true
        error = nil
        do {
            try await APIClient.shared.requestVoid(
                .cancelDeviceWork(deviceId: deviceId),
                body: CancelWorkRequest(reassignTo: nil, cancelReason: reason)
            )
            await loadDevice()
            await loadActions()
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to cancel work: \(error)")
            #endif
        }
        isUpdating = false
    }

    // MARK: - Buyback

    /// Add this device into the buyback pipeline (creates/links a buyback record).
    /// Returns nil on success (device is refreshed), or a human-readable error
    /// message on failure (e.g. wrong status, incomplete client details).
    func addToBuyback() async -> String? {
        isUpdating = true
        defer { isUpdating = false }
        do {
            _ = try await BuybackService().addDeviceToBuyback(deviceId: deviceId)
            await loadDevice()
            return nil
        } catch {
            #if DEBUG
            print("Failed to add device to buyback: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    // MARK: - Checklists

    /// Fetch checklist templates of a given type (intake|pre_repair|post_repair|outgoing).
    func fetchChecklistTemplates(type: String) async -> [ChecklistTemplate] {
        do {
            return try await APIClient.shared.request(
                .deviceChecklistTemplates(orderId: orderId, deviceId: deviceId, checklistType: type)
            )
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to fetch checklist templates: \(error)")
            #endif
            return []
        }
    }

    /// Submit a completed checklist result set. Returns nil on success,
    /// or a human-readable error message on failure.
    func completeChecklist(_ request: CompleteChecklistRequest) async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: CreatedChecklistResponse = try await APIClient.shared.request(
                .completeDeviceChecklist(orderId: orderId, deviceId: deviceId),
                body: request
            )
            await loadDevice()
            await loadActions()
            return nil
        } catch {
            #if DEBUG
            print("Failed to complete checklist: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    // MARK: - Quality Check

    /// Fetch QC readiness requirements for this device.
    func fetchQCRequirements() async -> QCRequirements? {
        do {
            return try await APIClient.shared.request(.deviceQCRequirements(deviceId: deviceId))
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("Failed to fetch QC requirements: \(error)")
            #endif
            return nil
        }
    }

    /// Submit a QC pass/fail decision. Returns nil on success,
    /// or a human-readable error message on failure.
    func submitQC(_ request: QCActionRequest) async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: QCActionResponse = try await APIClient.shared.request(
                .deviceQC(deviceId: deviceId),
                body: request
            )
            await loadDevice()
            await loadActions()
            return nil
        } catch {
            #if DEBUG
            print("Failed to submit QC: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    // MARK: - Staff Authorize

    /// Approve or reject a device that's awaiting staff authorization. Returns
    /// nil on success (device is refreshed), or a human-readable error message
    /// on failure (e.g. missing bank details on a buyback approve).
    func staffAuthorize(_ request: StaffAuthorizeRequest) async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: StaffAuthorizeResponse = try await APIClient.shared.request(
                .staffAuthorizeDevice(deviceId: deviceId),
                body: request
            )
            await loadDevice()
            await loadActions()
            return nil
        } catch {
            #if DEBUG
            print("Failed to staff-authorize device: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    // MARK: - Collect / Despatch / Ready for Collection

    /// Collect this device (with signature or typed name). Returns nil on
    /// success (device is refreshed), or a human-readable error message on
    /// failure (e.g. wrong status, missing signature/typed name).
    func collectDevice(_ req: DeviceCollectRequest) async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: DeviceCollectResponse = try await APIClient.shared.request(
                .collectDevice(deviceId: deviceId),
                body: req
            )
            await loadDevice()
            await loadActions()
            return nil
        } catch {
            #if DEBUG
            print("Failed to collect device: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    /// Despatch this device to the customer (carrier + optional tracking).
    /// Returns nil on success (device is refreshed), or a human-readable
    /// error message on failure.
    func despatchDevice(_ req: DespatchOrderRequest) async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: DeviceDespatchResponse = try await APIClient.shared.request(
                .despatchDevice(deviceId: deviceId),
                body: req
            )
            await loadDevice()
            await loadActions()
            return nil
        } catch {
            #if DEBUG
            print("Failed to despatch device: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    /// Mark this device ready for collection. Returns nil on success (device
    /// is refreshed), or a human-readable error message on failure.
    func markReadyForCollection() async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: DeviceReadyResponse = try await APIClient.shared.request(
                .deviceReadyForCollection(deviceId: deviceId),
                body: DeviceReadyRequest(collectionLocationId: nil)
            )
            await loadDevice()
            await loadActions()
            return nil
        } catch {
            #if DEBUG
            print("Failed to mark device ready for collection: \(error)")
            #endif
            return error.localizedDescription
        }
    }

    /// Add an accessory record for this device. Returns nil on success
    /// (device is refreshed), or a human-readable error message on failure.
    func addAccessory(_ req: AddAccessoryRequest) async -> String? {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let _: AddAccessoryResponse = try await APIClient.shared.request(
                .addDeviceAccessory(orderId: orderId, deviceId: deviceId),
                body: req
            )
            await loadDevice()
            return nil
        } catch {
            #if DEBUG
            print("Failed to add accessory: \(error)")
            #endif
            return error.localizedDescription
        }
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
