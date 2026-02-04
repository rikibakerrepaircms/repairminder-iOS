//
//  OrderDetailViewModel.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import Combine

@MainActor
final class OrderDetailViewModel: ObservableObject {
    @Published var order: Order?
    @Published var devices: [Device] = []
    @Published var isLoading: Bool = false
    @Published var isUpdating: Bool = false
    @Published var error: String?

    private let orderId: String
    private let syncEngine = SyncEngine.shared

    init(orderId: String) {
        self.orderId = orderId
    }

    func loadOrder() async {
        isLoading = true
        error = nil

        do {
            order = try await APIClient.shared.request(
                .order(id: orderId),
                responseType: Order.self
            )

            devices = try await APIClient.shared.request(
                .devices(orderId: orderId),
                responseType: [Device].self
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func updateStatus(_ newStatus: OrderStatus) async {
        guard let order = order else { return }

        isUpdating = true

        struct StatusUpdate: Encodable {
            let status: String
        }

        do {
            try await APIClient.shared.requestVoid(
                .updateOrder(id: order.id, body: StatusUpdate(status: newStatus.rawValue))
            )

            // Update local order with new status
            self.order = Order(
                id: order.id,
                orderNumber: order.orderNumber,
                status: newStatus,
                total: order.total,
                deposit: order.deposit,
                balance: order.balance,
                notes: order.notes,
                clientId: order.clientId,
                clientName: order.clientName,
                clientEmail: order.clientEmail,
                clientPhone: order.clientPhone,
                locationId: order.locationId,
                locationName: order.locationName,
                assignedUserId: order.assignedUserId,
                assignedUserName: order.assignedUserName,
                deviceCount: order.deviceCount,
                createdAt: order.createdAt,
                updatedAt: Date()
            )

            syncEngine.queueChange(.orderUpdated(id: order.id))
        } catch {
            self.error = error.localizedDescription
        }

        isUpdating = false
    }
}
