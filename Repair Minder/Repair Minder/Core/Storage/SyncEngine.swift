//
//  SyncEngine.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import Foundation
import CoreData
import Combine
import os.log
import BackgroundTasks

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var pendingChangesCount: Int = 0

    private let coreData = CoreDataStack.shared
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "Sync")

    private var syncTask: Task<Void, Never>?
    private var observers = Set<AnyCancellable>()

    enum SyncStatus: Equatable, Sendable {
        case idle
        case syncing(progress: Double)
        case completed
        case error(String)
        case offline

        var isInProgress: Bool {
            if case .syncing = self { return true }
            return false
        }
    }

    private init() {
        setupNetworkObserver()
        loadLastSyncDate()
    }

    // MARK: - Public API

    /// Perform a full sync of all data
    func performFullSync() async {
        guard !status.isInProgress else {
            logger.debug("Sync already in progress")
            return
        }

        // Check network
        guard NetworkMonitor.shared.isConnected else {
            status = .offline
            return
        }

        status = .syncing(progress: 0)
        logger.debug("Starting full sync")

        do {
            // 1. Push local changes first
            status = .syncing(progress: 0.1)
            try await pushLocalChanges()

            // 2. Pull remote data
            status = .syncing(progress: 0.3)
            try await pullOrders()

            status = .syncing(progress: 0.5)
            try await pullDevices()

            status = .syncing(progress: 0.7)
            try await pullClients()

            status = .syncing(progress: 0.9)
            try await pullTickets()

            // 3. Update metadata
            lastSyncDate = Date()
            saveLastSyncDate()
            updatePendingCount()

            status = .completed
            logger.debug("Full sync completed")

            // Reset to idle after delay
            try? await Task.sleep(for: .seconds(2))
            if status == .completed {
                status = .idle
            }

        } catch APIError.offline {
            status = .offline
            logger.debug("Sync failed: offline")
        } catch {
            status = .error(error.localizedDescription)
            logger.error("Sync failed: \(error.localizedDescription)")
        }
    }

    /// Sync a specific entity type
    func sync(_ entityType: SyncEntityType) async {
        guard NetworkMonitor.shared.isConnected else {
            status = .offline
            return
        }

        do {
            switch entityType {
            case .orders:
                try await pullOrders()
            case .devices:
                try await pullDevices()
            case .clients:
                try await pullClients()
            case .tickets:
                try await pullTickets()
            }
        } catch {
            logger.error("Failed to sync \(entityType.rawValue): \(error.localizedDescription)")
        }
    }

    /// Queue a local change for sync
    nonisolated func queueChange(_ change: LocalChange) {
        let coreData = CoreDataStack.shared
        let context = coreData.newBackgroundContext()
        context.perform {
            // Mark entity as needing sync
            switch change {
            case .orderUpdated(let id):
                Self.markNeedsSync(entity: "CDOrder", id: id, in: context)
            case .deviceUpdated(let id):
                Self.markNeedsSync(entity: "CDDevice", id: id, in: context)
            case .ticketMessageCreated(let id):
                Self.markNeedsSync(entity: "CDTicketMessage", id: id, in: context)
            }

            try? context.save()

            Task { @MainActor in
                SyncEngine.shared.updatePendingCount()
            }
        }
    }

    /// Push pending local changes
    func pushLocalChanges() async throws {
        let context = coreData.newBackgroundContext()

        // Push order updates
        let pendingOrders = try await fetchPendingSync(entity: "CDOrder", in: context)
        for order in pendingOrders {
            try await pushOrderUpdate(order, context: context)
        }

        // Push device updates
        let pendingDevices = try await fetchPendingSync(entity: "CDDevice", in: context)
        for device in pendingDevices {
            try await pushDeviceUpdate(device, context: context)
        }

        // Push new messages
        let pendingMessages = try await fetchPendingSync(entity: "CDTicketMessage", in: context)
        for message in pendingMessages {
            try await pushTicketMessage(message, context: context)
        }

        updatePendingCount()
    }

    // MARK: - Pull Operations

    private func pullOrders() async throws {
        logger.debug("Pulling orders")

        let orders: [Order] = try await APIClient.shared.request(
            .orders(page: 1, limit: 100),
            responseType: [Order].self
        )

        let context = coreData.newBackgroundContext()
        try await context.perform {
            for order in orders {
                Self.upsertOrder(order, in: context)
            }
            try context.save()
        }

        logger.debug("Pulled \(orders.count) orders")
    }

    private func pullDevices() async throws {
        logger.debug("Pulling devices")

        let devices: [Device] = try await APIClient.shared.request(
            .devices(page: 1, limit: 100),
            responseType: [Device].self
        )

        let context = coreData.newBackgroundContext()
        try await context.perform {
            for device in devices {
                Self.upsertDevice(device, in: context)
            }
            try context.save()
        }

        logger.debug("Pulled \(devices.count) devices")
    }

    private func pullClients() async throws {
        logger.debug("Pulling clients")

        let clients: [Client] = try await APIClient.shared.request(
            .clients(page: 1, limit: 100),
            responseType: [Client].self
        )

        let context = coreData.newBackgroundContext()
        try await context.perform {
            for client in clients {
                Self.upsertClient(client, in: context)
            }
            try context.save()
        }

        logger.debug("Pulled \(clients.count) clients")
    }

    private func pullTickets() async throws {
        logger.debug("Pulling tickets")

        let tickets: [Ticket] = try await APIClient.shared.request(
            .tickets(page: 1, limit: 100),
            responseType: [Ticket].self
        )

        let context = coreData.newBackgroundContext()
        try await context.perform {
            for ticket in tickets {
                Self.upsertTicket(ticket, in: context)
            }
            try context.save()
        }

        logger.debug("Pulled \(tickets.count) tickets")
    }

    // MARK: - Push Operations

    private func pushOrderUpdate(_ entity: NSManagedObject, context: NSManagedObjectContext) async throws {
        // Capture the object ID which is Sendable
        let objectID = entity.objectID

        // Extract values on context's queue
        let (id, statusValue, notesValue) = await context.perform {
            let order = context.object(with: objectID) as? CDOrder
            return (order?.id, order?.status, order?.notes)
        }

        guard let id = id else { return }

        struct OrderUpdate: Encodable {
            let status: String?
            let notes: String?
        }

        let update = OrderUpdate(status: statusValue, notes: notesValue)

        try await APIClient.shared.requestVoid(.updateOrder(id: id, body: update))

        await context.perform {
            if let order = context.object(with: objectID) as? CDOrder {
                order.needsSync = false
                order.syncedAt = Date()
                try? context.save()
            }
        }

        logger.debug("Pushed order update: \(id)")
    }

    private func pushDeviceUpdate(_ entity: NSManagedObject, context: NSManagedObjectContext) async throws {
        // Capture the object ID which is Sendable
        let objectID = entity.objectID

        // Extract values on context's queue
        let (id, statusValue, diagnosisValue, resolutionValue) = await context.perform {
            let device = context.object(with: objectID) as? CDDevice
            return (device?.id, device?.status, device?.diagnosis, device?.resolution)
        }

        guard let id = id else { return }

        struct DeviceUpdate: Encodable {
            let status: String?
            let diagnosis: String?
            let resolution: String?
        }

        let update = DeviceUpdate(
            status: statusValue,
            diagnosis: diagnosisValue,
            resolution: resolutionValue
        )

        try await APIClient.shared.requestVoid(.updateDevice(id: id, body: update))

        await context.perform {
            if let device = context.object(with: objectID) as? CDDevice {
                device.needsSync = false
                device.syncedAt = Date()
                try? context.save()
            }
        }

        logger.debug("Pushed device update: \(id)")
    }

    private func pushTicketMessage(_ entity: NSManagedObject, context: NSManagedObjectContext) async throws {
        // Capture the object ID which is Sendable
        let objectID = entity.objectID

        // Extract values on context's queue
        let (ticketId, contentValue, isInternalValue) = await context.perform {
            let message = context.object(with: objectID) as? CDTicketMessage
            return (message?.ticketId, message?.content ?? "", message?.isInternal ?? false)
        }

        guard let ticketId = ticketId else { return }

        struct NewMessage: Encodable {
            let content: String
            let isInternal: Bool

            enum CodingKeys: String, CodingKey {
                case content
                case isInternal = "is_internal"
            }
        }

        let newMessage = NewMessage(
            content: contentValue,
            isInternal: isInternalValue
        )

        try await APIClient.shared.requestVoid(.sendTicketMessage(id: ticketId, body: newMessage))

        await context.perform {
            if let message = context.object(with: objectID) as? CDTicketMessage {
                message.needsSync = false
                message.syncedAt = Date()
                try? context.save()
            }
        }

        logger.debug("Pushed ticket message for ticket: \(ticketId)")
    }

    // MARK: - Upsert Helpers (nonisolated static methods)

    nonisolated private static func upsertOrder(_ order: Order, in context: NSManagedObjectContext) {
        let request = CDOrder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", order.id)

        let existing = try? context.fetch(request).first

        let entity = existing ?? CDOrder(context: context)

        // Only update if not pending local sync
        if entity.needsSync { return }

        entity.id = order.id
        entity.orderNumber = Int32(order.orderNumber)
        entity.status = order.status.rawValue
        entity.total = order.total as NSDecimalNumber?
        entity.deposit = order.deposit as NSDecimalNumber?
        entity.balance = order.balance as NSDecimalNumber?
        entity.notes = order.notes
        entity.clientId = order.clientId
        entity.locationId = order.locationId
        entity.assignedUserId = order.assignedUserId
        entity.createdAt = order.createdAt
        entity.updatedAt = order.updatedAt
        entity.syncedAt = Date()
    }

    nonisolated private static func upsertDevice(_ device: Device, in context: NSManagedObjectContext) {
        let request = CDDevice.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", device.id)

        let existing = try? context.fetch(request).first

        let entity = existing ?? CDDevice(context: context)

        if entity.needsSync { return }

        entity.id = device.id
        entity.orderId = device.orderId
        entity.type = device.type
        entity.brand = device.brand
        entity.model = device.model
        entity.serial = device.serial
        entity.imei = device.imei
        entity.passcode = device.passcode
        entity.status = device.status.rawValue
        entity.issue = device.issue
        entity.diagnosis = device.diagnosis
        entity.resolution = device.resolution
        entity.price = device.price as NSDecimalNumber?
        entity.assignedUserId = device.assignedUserId
        entity.createdAt = device.createdAt
        entity.updatedAt = device.updatedAt
        entity.syncedAt = Date()
    }

    nonisolated private static func upsertClient(_ client: Client, in context: NSManagedObjectContext) {
        let request = CDClient.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", client.id)

        let existing = try? context.fetch(request).first

        let entity = existing ?? CDClient(context: context)

        entity.id = client.id
        entity.email = client.email
        entity.firstName = client.firstName
        entity.lastName = client.lastName
        entity.phone = client.phone
        entity.company = client.company
        entity.address = client.address
        entity.city = client.city
        entity.postcode = client.postcode
        entity.notes = client.notes
        entity.orderCount = Int32(client.orderCount)
        entity.totalSpent = client.totalSpent as NSDecimalNumber
        entity.createdAt = client.createdAt
        entity.updatedAt = client.updatedAt
        entity.syncedAt = Date()
    }

    nonisolated private static func upsertTicket(_ ticket: Ticket, in context: NSManagedObjectContext) {
        let request = CDTicket.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", ticket.id)

        let existing = try? context.fetch(request).first

        let entity = existing ?? CDTicket(context: context)

        entity.id = ticket.id
        entity.ticketNumber = Int32(ticket.ticketNumber)
        entity.subject = ticket.subject
        entity.status = ticket.status.rawValue
        entity.priority = ticket.priority
        entity.clientId = ticket.clientId
        entity.clientEmail = ticket.clientEmail
        entity.clientName = ticket.clientName
        entity.assignedUserId = ticket.assignedUserId
        entity.orderId = ticket.orderId
        entity.lastMessageAt = ticket.lastMessageAt
        entity.createdAt = ticket.createdAt
        entity.updatedAt = ticket.updatedAt
        entity.syncedAt = Date()
    }

    // MARK: - Helpers

    nonisolated private static func markNeedsSync(entity: String, id: String, in context: NSManagedObjectContext) {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id)

        if let object = try? context.fetch(request).first {
            object.setValue(true, forKey: "needsSync")
        }
    }

    private func fetchPendingSync(entity: String, in context: NSManagedObjectContext) async throws -> [NSManagedObject] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "needsSync == YES")
            return try context.fetch(request)
        }
    }

    private func updatePendingCount() {
        let context = coreData.viewContext

        var count = 0

        let entities = ["CDOrder", "CDDevice", "CDTicketMessage"]
        for entity in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            request.predicate = NSPredicate(format: "needsSync == YES")
            count += (try? context.count(for: request)) ?? 0
        }

        pendingChangesCount = count
    }

    private func setupNetworkObserver() {
        NetworkMonitor.shared.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task {
                        await self?.performFullSync()
                    }
                } else {
                    self?.status = .offline
                }
            }
            .store(in: &observers)
    }

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    private func saveLastSyncDate() {
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }

    // MARK: - Background Sync

    nonisolated static let backgroundTaskIdentifier = "com.mendmyi.repairminder.sync"

    nonisolated func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Log error silently - can't use logger here as it's nonisolated
            print("Could not schedule background sync: \(error.localizedDescription)")
        }
    }
}

// MARK: - Types

enum SyncEntityType: String, Sendable {
    case orders
    case devices
    case clients
    case tickets
}

enum LocalChange: Sendable {
    case orderUpdated(id: String)
    case deviceUpdated(id: String)
    case ticketMessageCreated(id: String)
}
