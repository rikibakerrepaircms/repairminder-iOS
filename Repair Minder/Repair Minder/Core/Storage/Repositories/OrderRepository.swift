//
//  OrderRepository.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData
import Combine

@MainActor
final class OrderRepository: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let coreData = CoreDataStack.shared
    private let syncEngine = SyncEngine.shared

    // MARK: - Fetch

    func fetchOrders(status: OrderStatus? = nil) async {
        isLoading = true
        error = nil

        // First, load from Core Data
        loadFromCache(status: status)

        // Then refresh from API if online
        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.orders)
            loadFromCache(status: status)
        }

        isLoading = false
    }

    func fetchOrder(id: String) async -> Order? {
        // Check cache first
        if let cached = orders.first(where: { $0.id == id }) {
            return cached
        }

        // Load from Core Data
        let request = CDOrder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)

        if let entity = try? coreData.viewContext.fetch(request).first {
            return Order(from: entity)
        }

        // Fetch from API if online
        if NetworkMonitor.shared.isConnected {
            do {
                let order: Order = try await APIClient.shared.request(
                    .order(id: id),
                    responseType: Order.self
                )
                return order
            } catch {
                self.error = error.localizedDescription
            }
        }

        return nil
    }

    func fetchActiveOrders() async {
        isLoading = true
        error = nil

        loadActiveFromCache()

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.orders)
            loadActiveFromCache()
        }

        isLoading = false
    }

    // MARK: - Update

    func updateOrderStatus(id: String, status: OrderStatus) async throws {
        let context = coreData.newBackgroundContext()

        try await context.perform {
            let request = CDOrder.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.status = status.rawValue
            entity.updatedAt = Date()
            entity.needsSync = true

            try context.save()
        }

        // Queue for sync
        syncEngine.queueChange(.orderUpdated(id: id))

        // Refresh local data
        loadFromCache(status: nil)

        // Try to push immediately if online
        if NetworkMonitor.shared.isConnected {
            try? await syncEngine.pushLocalChanges()
        }
    }

    func updateOrderNotes(id: String, notes: String) async throws {
        let context = coreData.newBackgroundContext()

        try await context.perform {
            let request = CDOrder.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.notes = notes
            entity.updatedAt = Date()
            entity.needsSync = true

            try context.save()
        }

        syncEngine.queueChange(.orderUpdated(id: id))
        loadFromCache(status: nil)

        if NetworkMonitor.shared.isConnected {
            try? await syncEngine.pushLocalChanges()
        }
    }

    // MARK: - Private

    private func loadFromCache(status: OrderStatus?) {
        let request = CDOrder.fetchRequest()

        if let status = status {
            request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDOrder.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            orders = entities.map { Order(from: $0) }
        } catch {
            self.error = "Failed to load orders"
        }
    }

    private func loadActiveFromCache() {
        let request = CDOrder.fetchRequest()

        // Active statuses: booked_in, in_progress, awaiting_parts, ready
        request.predicate = NSPredicate(
            format: "status IN %@",
            ["booked_in", "in_progress", "awaiting_parts", "ready"]
        )

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDOrder.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            orders = entities.map { Order(from: $0) }
        } catch {
            self.error = "Failed to load orders"
        }
    }
}

enum RepositoryError: LocalizedError {
    case notFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Item not found"
        case .saveFailed:
            return "Failed to save changes"
        }
    }
}
