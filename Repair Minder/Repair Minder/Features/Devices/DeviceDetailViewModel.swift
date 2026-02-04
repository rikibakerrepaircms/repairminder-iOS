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
    @Published var isLoading: Bool = true
    @Published var isUpdating: Bool = false
    @Published var error: String?

    private let deviceId: String

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
                ticketId: device.ticketId,
                orderNumber: device.orderNumber,
                clientFirstName: device.clientFirstName,
                clientLastName: device.clientLastName,
                displayName: device.displayName,
                serialNumber: device.serialNumber,
                imei: device.imei,
                colour: device.colour,
                status: newStatus,
                workflowType: device.workflowType,
                deviceType: device.deviceType,
                assignedEngineer: device.assignedEngineer,
                locationId: device.locationId,
                subLocationId: device.subLocationId,
                subLocation: device.subLocation,
                receivedAt: device.receivedAt,
                dueDate: device.dueDate,
                createdAt: device.createdAt,
                notes: device.notes,
                source: device.source
            )
        } catch {
            self.error = error.localizedDescription
        }

        isUpdating = false
    }
}
