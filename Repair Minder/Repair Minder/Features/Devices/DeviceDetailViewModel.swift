//
//  DeviceDetailViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class DeviceDetailViewModel: ObservableObject {
    @Published var device: Device?
    @Published var isLoading: Bool = false
    @Published var isUpdating: Bool = false
    @Published var isSavingDiagnosis: Bool = false
    @Published var isSavingPrice: Bool = false
    @Published var error: String?

    // Form state
    @Published var diagnosis: String = ""
    @Published var resolution: String = ""
    @Published var editedPrice: String = ""
    @Published var isEditingPrice: Bool = false

    private let deviceId: String
    private let syncEngine = SyncEngine.shared
    private let repository = DeviceRepository()

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    func loadDevice() async {
        isLoading = true
        error = nil

        do {
            device = try await APIClient.shared.request(
                .device(id: deviceId),
                responseType: Device.self
            )

            // Initialize form state
            diagnosis = device?.diagnosis ?? ""
            resolution = device?.resolution ?? ""
            if let price = device?.price {
                editedPrice = "\(price)"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func updateStatus(_ newStatus: DeviceStatus) async {
        guard let device = device else { return }

        isUpdating = true

        struct StatusUpdate: Encodable {
            let status: String
        }

        do {
            try await APIClient.shared.requestVoid(
                .updateDevice(id: device.id, body: StatusUpdate(status: newStatus.rawValue))
            )

            // Update local device with new status
            self.device = Device(
                id: device.id,
                orderId: device.orderId,
                type: device.type,
                brand: device.brand,
                model: device.model,
                serial: device.serial,
                imei: device.imei,
                passcode: device.passcode,
                status: newStatus,
                issue: device.issue,
                diagnosis: device.diagnosis,
                resolution: device.resolution,
                price: device.price,
                assignedUserId: device.assignedUserId,
                assignedUserName: device.assignedUserName,
                createdAt: device.createdAt,
                updatedAt: Date()
            )

            syncEngine.queueChange(.deviceUpdated(id: device.id))
        } catch {
            self.error = error.localizedDescription
        }

        isUpdating = false
    }

    func saveDiagnosis() async {
        guard let device = device else { return }

        isSavingDiagnosis = true

        struct DiagnosisUpdate: Encodable {
            let diagnosis: String?
            let resolution: String?
        }

        do {
            try await APIClient.shared.requestVoid(
                .updateDevice(
                    id: device.id,
                    body: DiagnosisUpdate(
                        diagnosis: diagnosis.isEmpty ? nil : diagnosis,
                        resolution: resolution.isEmpty ? nil : resolution
                    )
                )
            )

            // Update local device
            self.device = Device(
                id: device.id,
                orderId: device.orderId,
                type: device.type,
                brand: device.brand,
                model: device.model,
                serial: device.serial,
                imei: device.imei,
                passcode: device.passcode,
                status: device.status,
                issue: device.issue,
                diagnosis: diagnosis.isEmpty ? nil : diagnosis,
                resolution: resolution.isEmpty ? nil : resolution,
                price: device.price,
                assignedUserId: device.assignedUserId,
                assignedUserName: device.assignedUserName,
                createdAt: device.createdAt,
                updatedAt: Date()
            )

            // Also update via repository for offline support
            try? await repository.updateDeviceDiagnosis(id: device.id, diagnosis: diagnosis)
            try? await repository.updateDeviceResolution(id: device.id, resolution: resolution)
        } catch {
            self.error = error.localizedDescription
        }

        isSavingDiagnosis = false
    }

    func savePrice() async {
        guard let device = device else { return }
        guard let newPrice = Decimal(string: editedPrice) else {
            error = "Invalid price format"
            return
        }

        isSavingPrice = true

        struct PriceUpdate: Encodable {
            let price: String
        }

        do {
            try await APIClient.shared.requestVoid(
                .updateDevice(id: device.id, body: PriceUpdate(price: "\(newPrice)"))
            )

            // Update local device
            self.device = Device(
                id: device.id,
                orderId: device.orderId,
                type: device.type,
                brand: device.brand,
                model: device.model,
                serial: device.serial,
                imei: device.imei,
                passcode: device.passcode,
                status: device.status,
                issue: device.issue,
                diagnosis: device.diagnosis,
                resolution: device.resolution,
                price: newPrice,
                assignedUserId: device.assignedUserId,
                assignedUserName: device.assignedUserName,
                createdAt: device.createdAt,
                updatedAt: Date()
            )

            syncEngine.queueChange(.deviceUpdated(id: device.id))
            isEditingPrice = false
        } catch {
            self.error = error.localizedDescription
        }

        isSavingPrice = false
    }
}
