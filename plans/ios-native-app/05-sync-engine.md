# Stage 05: Sync Engine

## Objective

Implement a robust sync engine that handles bidirectional data synchronization between Core Data and the API, including conflict resolution, background sync, and offline queue management.

---

## Dependencies

**Requires:** [See: Stage 04] complete - Core Data models exist

---

## Complexity

**High** - Complex state management, conflict resolution, background processing

---

## Files to Modify

| File | Changes |
|------|---------|
| `App/AppState.swift` | Add sync status observation |
| `App/Repair_MinderApp.swift` | Initialize sync engine, register background tasks |
| `Info.plist` | Add background fetch capability |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Storage/SyncEngine.swift` | Main sync coordinator |
| `Core/Storage/SyncOperation.swift` | Individual sync operations |
| `Core/Storage/ChangeTracker.swift` | Track local changes |
| `Core/Storage/ConflictResolver.swift` | Handle sync conflicts |
| `Core/Storage/Repositories/OrderRepository.swift` | Order data access |
| `Core/Storage/Repositories/DeviceRepository.swift` | Device data access |
| `Core/Storage/Repositories/ClientRepository.swift` | Client data access |
| `Core/Storage/Repositories/TicketRepository.swift` | Ticket data access |

---

## Implementation Details

### 1. Sync Engine

```swift
// Core/Storage/SyncEngine.swift
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

    enum SyncStatus: Equatable {
        case idle
        case syncing(progress: Double)
        case completed
        case error(String)
        case offline
    }

    private init() {
        setupNetworkObserver()
    }

    // MARK: - Public API

    /// Perform a full sync of all data
    func performFullSync() async {
        guard status != .syncing(progress: 0) else {
            logger.debug("Sync already in progress")
            return
        }

        // Check network
        guard await NetworkMonitor.shared.isConnected else {
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
            updatePendingCount()

            status = .completed
            logger.debug("Full sync completed")

            // Reset to idle after delay
            try? await Task.sleep(for: .seconds(2))
            if status == .completed {
                status = .idle
            }

        } catch let error as APIError where error == .offline {
            status = .offline
            logger.debug("Sync failed: offline")
        } catch {
            status = .error(error.localizedDescription)
            logger.error("Sync failed: \(error.localizedDescription)")
        }
    }

    /// Sync a specific entity type
    func sync(_ entityType: SyncEntityType) async {
        guard await NetworkMonitor.shared.isConnected else {
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
    func queueChange(_ change: LocalChange) {
        let context = coreData.newBackgroundContext()
        context.perform {
            // Mark entity as needing sync
            switch change {
            case .orderUpdated(let id):
                self.markNeedsSync(entity: "CDOrder", id: id, in: context)
            case .deviceUpdated(let id):
                self.markNeedsSync(entity: "CDDevice", id: id, in: context)
            case .ticketMessageCreated(let id):
                self.markNeedsSync(entity: "CDTicketMessage", id: id, in: context)
            }

            try? context.save()

            Task { @MainActor in
                self.updatePendingCount()
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
                self.upsertOrder(order, in: context)
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
                self.upsertDevice(device, in: context)
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
                self.upsertClient(client, in: context)
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
                self.upsertTicket(ticket, in: context)
            }
            try context.save()
        }

        logger.debug("Pulled \(tickets.count) tickets")
    }

    // MARK: - Push Operations

    private func pushOrderUpdate(_ entity: NSManagedObject, context: NSManagedObjectContext) async throws {
        guard let order = entity as? CDOrder,
              let id = order.id else { return }

        struct OrderUpdate: Encodable {
            let status: String?
            let notes: String?
        }

        let update = OrderUpdate(status: order.status, notes: order.notes)

        try await APIClient.shared.requestVoid(.updateOrder(id: id, body: update))

        await context.perform {
            order.needsSync = false
            order.syncedAt = Date()
            try? context.save()
        }

        logger.debug("Pushed order update: \(id)")
    }

    private func pushDeviceUpdate(_ entity: NSManagedObject, context: NSManagedObjectContext) async throws {
        guard let device = entity as? CDDevice,
              let id = device.id else { return }

        struct DeviceUpdate: Encodable {
            let status: String?
            let diagnosis: String?
            let resolution: String?
        }

        let update = DeviceUpdate(
            status: device.status,
            diagnosis: device.diagnosis,
            resolution: device.resolution
        )

        try await APIClient.shared.requestVoid(.updateDevice(id: id, body: update))

        await context.perform {
            device.needsSync = false
            device.syncedAt = Date()
            try? context.save()
        }

        logger.debug("Pushed device update: \(id)")
    }

    private func pushTicketMessage(_ entity: NSManagedObject, context: NSManagedObjectContext) async throws {
        guard let message = entity as? CDTicketMessage,
              let ticketId = message.ticketId else { return }

        struct NewMessage: Encodable {
            let content: String
            let isInternal: Bool

            enum CodingKeys: String, CodingKey {
                case content
                case isInternal = "is_internal"
            }
        }

        let newMessage = NewMessage(
            content: message.content ?? "",
            isInternal: message.isInternal
        )

        try await APIClient.shared.requestVoid(.sendTicketMessage(id: ticketId, body: newMessage))

        await context.perform {
            message.needsSync = false
            message.syncedAt = Date()
            try? context.save()
        }

        logger.debug("Pushed ticket message for ticket: \(ticketId)")
    }

    // MARK: - Upsert Helpers

    private func upsertOrder(_ order: Order, in context: NSManagedObjectContext) {
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

    private func upsertDevice(_ device: Device, in context: NSManagedObjectContext) {
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

    private func upsertClient(_ client: Client, in context: NSManagedObjectContext) {
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

    private func upsertTicket(_ ticket: Ticket, in context: NSManagedObjectContext) {
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

    private func markNeedsSync(entity: String, id: String, in context: NSManagedObjectContext) {
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
}

// MARK: - Types

enum SyncEntityType: String {
    case orders
    case devices
    case clients
    case tickets
}

enum LocalChange {
    case orderUpdated(id: String)
    case deviceUpdated(id: String)
    case ticketMessageCreated(id: String)
}
```

### 2. Repository Pattern - Order Repository

```swift
// Core/Storage/Repositories/OrderRepository.swift
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
        if await NetworkMonitor.shared.isConnected {
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
        if await NetworkMonitor.shared.isConnected {
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
        if await NetworkMonitor.shared.isConnected {
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
```

### 3. Background Task Registration

```swift
// Add to Repair_MinderApp.swift

import BackgroundTasks

@main
struct Repair_MinderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(router)
                .task {
                    await appState.checkAuthStatus()
                }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.mendmyi.repairminder.sync",
            using: nil
        ) { task in
            handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        scheduleNextSync()

        let syncTask = Task {
            await SyncEngine.shared.performFullSync()
        }

        task.expirationHandler = {
            syncTask.cancel()
        }

        Task {
            await syncTask.value
            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleNextSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.mendmyi.repairminder.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background sync: \(error)")
        }
    }
}
```

### 4. Info.plist Additions

```xml
<!-- Add to Info.plist -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.mendmyi.repairminder.sync</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>
```

---

## Database Changes

Add to existing Core Data model:
- Ensure all entities have `needsSync` (Boolean) and `syncedAt` (Date) attributes
- Add `CDSyncMetadata` entity for tracking sync state per entity type

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Full sync completes | Trigger sync | All data pulled, status = completed |
| Offline detected | Disconnect network | status = offline |
| Local change queued | Update order offline | needsSync = true, pendingChangesCount++ |
| Push on reconnect | Reconnect network | Pending changes pushed |
| Upsert skips dirty | Pull while local change pending | Local change preserved |
| Background sync runs | App backgrounded | Sync executes |
| Conflict resolution | Same record changed | Last-write-wins applied |

---

## Acceptance Checklist

- [ ] SyncEngine initializes without errors
- [ ] Full sync pulls all entity types
- [ ] Local changes marked with needsSync
- [ ] pendingChangesCount updates correctly
- [ ] Push operations send data to API
- [ ] Upsert doesn't overwrite pending local changes
- [ ] Network reconnection triggers sync
- [ ] Background task registered
- [ ] Status transitions correctly (idle → syncing → completed)
- [ ] Errors captured and displayed

---

## Deployment

### Build Commands

```bash
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### Verification

1. Launch app, verify initial sync runs
2. Enable airplane mode, make changes
3. Disable airplane mode, verify sync pushes changes
4. Check Console for sync logs

---

## Handoff Notes

**For Stage 06-10:**
- Use `OrderRepository`, etc. for data access in ViewModels
- Observe `SyncEngine.shared.status` for sync indicator
- Call `syncEngine.queueChange()` after local modifications
- `pendingChangesCount` shows badge for offline indicator

**For Stage 11:**
- Background sync already configured
- Push notifications may want to trigger sync
