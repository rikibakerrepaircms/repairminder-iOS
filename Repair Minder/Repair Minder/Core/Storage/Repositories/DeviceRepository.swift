//
//  DeviceRepository.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData
import Combine

@MainActor
final class DeviceRepository: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?

    private let coreData = CoreDataStack.shared
    private let syncEngine = SyncEngine.shared

    // MARK: - Fetch

    func fetchDevices(status: DeviceStatus? = nil) async {
        isLoading = true
        error = nil

        loadFromCache(status: status)

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.devices)
            loadFromCache(status: status)
        }

        isLoading = false
    }

    func fetchDevices(forOrderId orderId: String) async {
        isLoading = true
        error = nil

        loadFromCache(orderId: orderId)

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.devices)
            loadFromCache(orderId: orderId)
        }

        isLoading = false
    }

    func fetchDevice(id: String) async -> Device? {
        if let cached = devices.first(where: { $0.id == id }) {
            return cached
        }

        let request = CDDevice.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)

        if let entity = try? coreData.viewContext.fetch(request).first {
            return Device(from: entity)
        }

        if NetworkMonitor.shared.isConnected {
            do {
                let device: Device = try await APIClient.shared.request(
                    .device(id: id),
                    responseType: Device.self
                )
                return device
            } catch {
                self.error = error.localizedDescription
            }
        }

        return nil
    }

    func fetchMyQueue() async {
        isLoading = true
        error = nil

        // Load assigned devices from cache
        loadMyQueueFromCache()

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.devices)
            loadMyQueueFromCache()
        }

        isLoading = false
    }

    func fetchActiveDevices() async {
        isLoading = true
        error = nil

        loadActiveFromCache()

        if NetworkMonitor.shared.isConnected {
            await syncEngine.sync(.devices)
            loadActiveFromCache()
        }

        isLoading = false
    }

    // MARK: - Update

    func updateDeviceStatus(id: String, status: DeviceStatus) async throws {
        let context = coreData.newBackgroundContext()

        try await context.perform {
            let request = CDDevice.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.status = status.rawValue
            entity.updatedAt = Date()
            entity.needsSync = true

            try context.save()
        }

        syncEngine.queueChange(.deviceUpdated(id: id))
        loadFromCache(status: nil)

        if NetworkMonitor.shared.isConnected {
            try? await syncEngine.pushLocalChanges()
        }
    }

    func updateDeviceDiagnosis(id: String, diagnosis: String) async throws {
        let context = coreData.newBackgroundContext()

        try await context.perform {
            let request = CDDevice.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.diagnosis = diagnosis
            entity.updatedAt = Date()
            entity.needsSync = true

            try context.save()
        }

        syncEngine.queueChange(.deviceUpdated(id: id))
        loadFromCache(status: nil)

        if NetworkMonitor.shared.isConnected {
            try? await syncEngine.pushLocalChanges()
        }
    }

    func updateDeviceResolution(id: String, resolution: String) async throws {
        let context = coreData.newBackgroundContext()

        try await context.perform {
            let request = CDDevice.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.resolution = resolution
            entity.updatedAt = Date()
            entity.needsSync = true

            try context.save()
        }

        syncEngine.queueChange(.deviceUpdated(id: id))
        loadFromCache(status: nil)

        if NetworkMonitor.shared.isConnected {
            try? await syncEngine.pushLocalChanges()
        }
    }

    func updateDevicePrice(id: String, price: Decimal) async throws {
        let context = coreData.newBackgroundContext()

        try await context.perform {
            let request = CDDevice.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.price = price as NSDecimalNumber
            entity.updatedAt = Date()
            entity.needsSync = true

            try context.save()
        }

        syncEngine.queueChange(.deviceUpdated(id: id))
        loadFromCache(status: nil)

        if NetworkMonitor.shared.isConnected {
            try? await syncEngine.pushLocalChanges()
        }
    }

    // MARK: - Private

    private func loadFromCache(status: DeviceStatus?) {
        let request = CDDevice.fetchRequest()

        if let status = status {
            request.predicate = NSPredicate(format: "status == %@", status.rawValue)
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDDevice.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            devices = entities.map { Device(from: $0) }
        } catch {
            self.error = "Failed to load devices"
        }
    }

    private func loadFromCache(orderId: String) {
        let request = CDDevice.fetchRequest()
        request.predicate = NSPredicate(format: "orderId == %@", orderId)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDDevice.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            devices = entities.map { Device(from: $0) }
        } catch {
            self.error = "Failed to load devices"
        }
    }

    private func loadMyQueueFromCache() {
        // For now, load all devices with active statuses
        // In the future, this would filter by assignedUserId
        loadActiveFromCache()
    }

    private func loadActiveFromCache() {
        let request = CDDevice.fetchRequest()

        // Active statuses
        request.predicate = NSPredicate(
            format: "status IN %@",
            ["booked_in", "diagnosing", "awaiting_approval", "approved", "in_repair", "awaiting_parts", "repaired", "quality_check", "ready"]
        )

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDDevice.createdAt, ascending: false)
        ]

        do {
            let entities = try coreData.viewContext.fetch(request)
            devices = entities.map { Device(from: $0) }
        } catch {
            self.error = "Failed to load devices"
        }
    }
}
