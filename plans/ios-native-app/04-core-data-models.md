# Stage 04: Core Data Models

## Objective

Create the Core Data schema and Swift models for offline storage, enabling the app to function without network connectivity.

---

## Dependencies

**Requires:** [See: Stage 03] complete - User/Company models exist

---

## Complexity

**High** - Database schema design, relationships, migrations

---

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder.xcodeproj` | Add Core Data model file reference |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Resources/RepairMinder.xcdatamodeld` | Core Data model definition |
| `Core/Storage/CoreDataStack.swift` | Core Data stack management |
| `Core/Storage/PersistenceController.swift` | Convenience wrapper |
| `Core/Models/Order.swift` | Order model (API + Core Data) |
| `Core/Models/Device.swift` | Device model |
| `Core/Models/Client.swift` | Client model |
| `Core/Models/Ticket.swift` | Ticket/Enquiry model |
| `Core/Models/TicketMessage.swift` | Ticket message model |
| `Core/Models/DashboardStats.swift` | Dashboard statistics |
| `Core/Models/SyncMetadata.swift` | Sync tracking |
| `Core/Storage/Entities/` | Core Data NSManagedObject subclasses |

---

## Implementation Details

### 1. Core Data Model Schema

Create `RepairMinder.xcdatamodeld` with the following entities:

#### Entity: CDOrder
| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | String | No | Primary key |
| orderNumber | Integer 32 | No | Display order number |
| status | String | No | Order status |
| total | Decimal | Yes | Order total |
| deposit | Decimal | Yes | Deposit amount |
| balance | Decimal | Yes | Remaining balance |
| notes | String | Yes | Order notes |
| clientId | String | No | Foreign key |
| locationId | String | Yes | Location ID |
| assignedUserId | String | Yes | Assigned technician |
| createdAt | Date | No | Creation timestamp |
| updatedAt | Date | No | Last update |
| syncedAt | Date | Yes | Last sync time |
| needsSync | Boolean | No | Default: false |

**Relationships:**
- devices: To-Many → CDDevice (inverse: order)
- client: To-One → CDClient (inverse: orders)

#### Entity: CDDevice
| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | String | No | Primary key |
| orderId | String | No | Foreign key |
| type | String | No | Device type (iPhone, etc) |
| brand | String | Yes | Device brand |
| model | String | Yes | Device model |
| serial | String | Yes | Serial number |
| imei | String | Yes | IMEI number |
| passcode | String | Yes | Device passcode |
| status | String | No | Device status |
| issue | String | Yes | Problem description |
| diagnosis | String | Yes | Technician diagnosis |
| resolution | String | Yes | Resolution notes |
| price | Decimal | Yes | Repair price |
| assignedUserId | String | Yes | Assigned technician |
| createdAt | Date | No | |
| updatedAt | Date | No | |
| syncedAt | Date | Yes | |
| needsSync | Boolean | No | |

**Relationships:**
- order: To-One → CDOrder (inverse: devices)

#### Entity: CDClient
| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | String | No | Primary key |
| email | String | No | Client email |
| firstName | String | Yes | |
| lastName | String | Yes | |
| phone | String | Yes | |
| company | String | Yes | Client's company |
| address | String | Yes | |
| city | String | Yes | |
| postcode | String | Yes | |
| notes | String | Yes | |
| orderCount | Integer 32 | No | Cached count |
| totalSpent | Decimal | No | Cached total |
| createdAt | Date | No | |
| updatedAt | Date | No | |
| syncedAt | Date | Yes | |

**Relationships:**
- orders: To-Many → CDOrder (inverse: client)

#### Entity: CDTicket
| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | String | No | Primary key |
| ticketNumber | Integer 32 | No | |
| subject | String | No | |
| status | String | No | open/pending/closed |
| priority | String | Yes | |
| clientId | String | Yes | |
| clientEmail | String | No | |
| clientName | String | Yes | |
| assignedUserId | String | Yes | |
| orderId | String | Yes | Linked order |
| createdAt | Date | No | |
| updatedAt | Date | No | |
| lastMessageAt | Date | Yes | |
| syncedAt | Date | Yes | |

**Relationships:**
- messages: To-Many → CDTicketMessage (inverse: ticket)

#### Entity: CDTicketMessage
| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| id | String | No | Primary key |
| ticketId | String | No | Foreign key |
| content | String | No | Message content |
| senderType | String | No | staff/client |
| senderName | String | Yes | |
| senderId | String | Yes | |
| isInternal | Boolean | No | Internal note? |
| createdAt | Date | No | |
| syncedAt | Date | Yes | |
| needsSync | Boolean | No | |

**Relationships:**
- ticket: To-One → CDTicket (inverse: messages)

#### Entity: CDSyncMetadata
| Attribute | Type | Optional | Notes |
|-----------|------|----------|-------|
| entityName | String | No | Entity being tracked |
| lastSyncedAt | Date | Yes | Last successful sync |
| lastSyncCursor | String | Yes | Pagination cursor |
| syncStatus | String | No | idle/syncing/error |
| errorMessage | String | Yes | Last error |

### 2. Core Data Stack

```swift
// Core/Storage/CoreDataStack.swift
import CoreData
import os.log

final class CoreDataStack {
    static let shared = CoreDataStack()

    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "CoreData")

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RepairMinder")

        // Configure for background sync
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                self?.logger.error("Core Data error: \(error), \(error.userInfo)")
                fatalError("Core Data load failed: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logger.error("Save failed: \(error.localizedDescription)")
            }
        }
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
}
```

### 3. Persistence Controller (SwiftUI Preview Support)

```swift
// Core/Storage/PersistenceController.swift
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "RepairMinder")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // Preview helper with sample data
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        // Add sample data for previews
        for i in 1...5 {
            let order = CDOrder(context: context)
            order.id = UUID().uuidString
            order.orderNumber = Int32(1000 + i)
            order.status = ["booked_in", "in_progress", "ready"][i % 3]
            order.total = NSDecimalNumber(value: Double.random(in: 50...500))
            order.createdAt = Date().addingTimeInterval(-Double(i * 86400))
            order.updatedAt = Date()
            order.needsSync = false
        }

        try? context.save()
        return controller
    }()
}
```

### 4. Order Model

```swift
// Core/Models/Order.swift
import Foundation
import CoreData

struct Order: Identifiable, Equatable {
    let id: String
    let orderNumber: Int
    let status: OrderStatus
    let total: Decimal?
    let deposit: Decimal?
    let balance: Decimal?
    let notes: String?
    let clientId: String
    let clientName: String?
    let clientEmail: String?
    let clientPhone: String?
    let locationId: String?
    let locationName: String?
    let assignedUserId: String?
    let assignedUserName: String?
    let deviceCount: Int
    let createdAt: Date
    let updatedAt: Date

    // Computed properties
    var displayRef: String {
        "#\(orderNumber)"
    }

    var isPaid: Bool {
        (balance ?? 0) <= 0
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case bookedIn = "booked_in"
    case inProgress = "in_progress"
    case awaitingParts = "awaiting_parts"
    case ready = "ready"
    case collected = "collected"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .bookedIn: return "Booked In"
        case .inProgress: return "In Progress"
        case .awaitingParts: return "Awaiting Parts"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .bookedIn: return "blue"
        case .inProgress: return "orange"
        case .awaitingParts: return "yellow"
        case .ready: return "green"
        case .collected: return "gray"
        case .cancelled: return "red"
        }
    }

    var isActive: Bool {
        switch self {
        case .bookedIn, .inProgress, .awaitingParts, .ready:
            return true
        case .collected, .cancelled:
            return false
        }
    }
}

// MARK: - Codable
extension Order: Codable {
    enum CodingKeys: String, CodingKey {
        case id, status, total, deposit, balance, notes
        case orderNumber = "order_number"
        case clientId = "client_id"
        case clientName = "client_name"
        case clientEmail = "client_email"
        case clientPhone = "client_phone"
        case locationId = "location_id"
        case locationName = "location_name"
        case assignedUserId = "assigned_user_id"
        case assignedUserName = "assigned_user_name"
        case deviceCount = "device_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Core Data Conversion
extension Order {
    init(from entity: CDOrder) {
        self.id = entity.id ?? ""
        self.orderNumber = Int(entity.orderNumber)
        self.status = OrderStatus(rawValue: entity.status ?? "") ?? .bookedIn
        self.total = entity.total as Decimal?
        self.deposit = entity.deposit as Decimal?
        self.balance = entity.balance as Decimal?
        self.notes = entity.notes
        self.clientId = entity.clientId ?? ""
        self.clientName = entity.client?.fullName
        self.clientEmail = entity.client?.email
        self.clientPhone = entity.client?.phone
        self.locationId = entity.locationId
        self.locationName = nil // Would need join
        self.assignedUserId = entity.assignedUserId
        self.assignedUserName = nil // Would need join
        self.deviceCount = entity.devices?.count ?? 0
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }

    func toEntity(in context: NSManagedObjectContext) -> CDOrder {
        let entity = CDOrder(context: context)
        entity.id = id
        entity.orderNumber = Int32(orderNumber)
        entity.status = status.rawValue
        entity.total = total as NSDecimalNumber?
        entity.deposit = deposit as NSDecimalNumber?
        entity.balance = balance as NSDecimalNumber?
        entity.notes = notes
        entity.clientId = clientId
        entity.locationId = locationId
        entity.assignedUserId = assignedUserId
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.syncedAt = Date()
        entity.needsSync = false
        return entity
    }
}
```

### 5. Device Model

```swift
// Core/Models/Device.swift
import Foundation
import CoreData

struct Device: Identifiable, Equatable {
    let id: String
    let orderId: String
    let type: String
    let brand: String?
    let model: String?
    let serial: String?
    let imei: String?
    let passcode: String?
    let status: DeviceStatus
    let issue: String?
    let diagnosis: String?
    let resolution: String?
    let price: Decimal?
    let assignedUserId: String?
    let assignedUserName: String?
    let createdAt: Date
    let updatedAt: Date

    var displayName: String {
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        }
        return type
    }
}

enum DeviceStatus: String, Codable, CaseIterable {
    case bookedIn = "booked_in"
    case diagnosing = "diagnosing"
    case awaitingApproval = "awaiting_approval"
    case approved = "approved"
    case inRepair = "in_repair"
    case awaitingParts = "awaiting_parts"
    case repaired = "repaired"
    case qualityCheck = "quality_check"
    case ready = "ready"
    case collected = "collected"
    case unrepairable = "unrepairable"

    var displayName: String {
        switch self {
        case .bookedIn: return "Booked In"
        case .diagnosing: return "Diagnosing"
        case .awaitingApproval: return "Awaiting Approval"
        case .approved: return "Approved"
        case .inRepair: return "In Repair"
        case .awaitingParts: return "Awaiting Parts"
        case .repaired: return "Repaired"
        case .qualityCheck: return "Quality Check"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .unrepairable: return "Unrepairable"
        }
    }

    var isActive: Bool {
        switch self {
        case .collected, .unrepairable:
            return false
        default:
            return true
        }
    }
}

// MARK: - Codable
extension Device: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, brand, model, serial, imei, passcode, status
        case issue, diagnosis, resolution, price
        case orderId = "order_id"
        case assignedUserId = "assigned_user_id"
        case assignedUserName = "assigned_user_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Core Data Conversion
extension Device {
    init(from entity: CDDevice) {
        self.id = entity.id ?? ""
        self.orderId = entity.orderId ?? ""
        self.type = entity.type ?? ""
        self.brand = entity.brand
        self.model = entity.model
        self.serial = entity.serial
        self.imei = entity.imei
        self.passcode = entity.passcode
        self.status = DeviceStatus(rawValue: entity.status ?? "") ?? .bookedIn
        self.issue = entity.issue
        self.diagnosis = entity.diagnosis
        self.resolution = entity.resolution
        self.price = entity.price as Decimal?
        self.assignedUserId = entity.assignedUserId
        self.assignedUserName = nil
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
}
```

### 6. Client Model

```swift
// Core/Models/Client.swift
import Foundation
import CoreData

struct Client: Identifiable, Equatable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let company: String?
    let address: String?
    let city: String?
    let postcode: String?
    let notes: String?
    let orderCount: Int
    let totalSpent: Decimal
    let createdAt: Date
    let updatedAt: Date

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    var displayName: String {
        if !fullName.isEmpty {
            return fullName
        }
        return email
    }

    var initials: String {
        if let first = firstName?.first, let last = lastName?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }
}

// MARK: - Codable
extension Client: Codable {
    enum CodingKeys: String, CodingKey {
        case id, email, phone, company, address, city, postcode, notes
        case firstName = "first_name"
        case lastName = "last_name"
        case orderCount = "order_count"
        case totalSpent = "total_spent"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Core Data Conversion
extension Client {
    init(from entity: CDClient) {
        self.id = entity.id ?? ""
        self.email = entity.email ?? ""
        self.firstName = entity.firstName
        self.lastName = entity.lastName
        self.phone = entity.phone
        self.company = entity.company
        self.address = entity.address
        self.city = entity.city
        self.postcode = entity.postcode
        self.notes = entity.notes
        self.orderCount = Int(entity.orderCount)
        self.totalSpent = entity.totalSpent as Decimal? ?? 0
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }
}

// CDClient extension
extension CDClient {
    var fullName: String? {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}
```

### 7. Dashboard Stats Model

```swift
// Core/Models/DashboardStats.swift
import Foundation

struct DashboardStats: Codable {
    let period: String
    let devices: DeviceStats
    let revenue: RevenueStats
    let clients: ClientStats
    let newClients: ClientStats
    let returningClients: ClientStats

    struct DeviceStats: Codable {
        let current: CurrentCount
        let comparisons: [Comparison]

        struct CurrentCount: Codable {
            let count: Int
        }

        struct Comparison: Codable {
            let period: String
            let count: Int
            let change: Int
            let changePercent: Double

            enum CodingKeys: String, CodingKey {
                case period, count, change
                case changePercent = "change_percent"
            }
        }
    }

    struct RevenueStats: Codable {
        let current: CurrentTotal
        let comparisons: [Comparison]

        struct CurrentTotal: Codable {
            let total: Double
        }

        struct Comparison: Codable {
            let period: String
            let total: Double
            let change: Double
            let changePercent: Double

            enum CodingKeys: String, CodingKey {
                case period, total, change
                case changePercent = "change_percent"
            }
        }
    }

    struct ClientStats: Codable {
        let current: CurrentCount
        let comparisons: [Comparison]

        struct CurrentCount: Codable {
            let count: Int
        }

        struct Comparison: Codable {
            let period: String
            let count: Int
            let change: Int
            let changePercent: Double

            enum CodingKeys: String, CodingKey {
                case period, count, change
                case changePercent = "change_percent"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case period, devices, revenue, clients
        case newClients = "new_clients"
        case returningClients = "returning_clients"
    }
}
```

### 8. Ticket Model

```swift
// Core/Models/Ticket.swift
import Foundation

struct Ticket: Identifiable, Equatable {
    let id: String
    let ticketNumber: Int
    let subject: String
    let status: TicketStatus
    let priority: String?
    let clientId: String?
    let clientEmail: String
    let clientName: String?
    let assignedUserId: String?
    let assignedUserName: String?
    let orderId: String?
    let orderRef: String?
    let messageCount: Int
    let lastMessageAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var displayRef: String {
        "#\(ticketNumber)"
    }
}

enum TicketStatus: String, Codable {
    case open
    case pending
    case closed

    var displayName: String {
        rawValue.capitalized
    }
}

extension Ticket: Codable {
    enum CodingKeys: String, CodingKey {
        case id, subject, status, priority
        case ticketNumber = "ticket_number"
        case clientId = "client_id"
        case clientEmail = "client_email"
        case clientName = "client_name"
        case assignedUserId = "assigned_user_id"
        case assignedUserName = "assigned_user_name"
        case orderId = "order_id"
        case orderRef = "order_ref"
        case messageCount = "message_count"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

---

## Database Changes

**Create Core Data model file:** `RepairMinder.xcdatamodeld`

Entities as defined above with proper relationships and indices on:
- `CDOrder.orderNumber`
- `CDOrder.status`
- `CDOrder.clientId`
- `CDDevice.orderId`
- `CDDevice.status`
- `CDClient.email`
- `CDTicket.ticketNumber`
- `CDTicket.status`

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Core Data loads | Launch app | No crash, container ready |
| Save order | Create CDOrder | Entity persisted |
| Fetch orders | Query all orders | Array returned |
| Order ↔ Model | Convert back/forth | Data preserved |
| Relationships | Add device to order | Relationship works |
| Preview data | Use preview controller | Sample data available |
| Background save | Save on background | No main thread issues |

---

## Acceptance Checklist

- [ ] Core Data model compiles
- [ ] All entities have required attributes
- [ ] Relationships configured correctly
- [ ] Indices added for common queries
- [ ] Swift models match API response shapes
- [ ] Core Data ↔ Swift model conversion works
- [ ] Preview controller provides sample data
- [ ] Background context creation works
- [ ] Save context works without errors

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

1. Build succeeds with Core Data model
2. App launches without Core Data errors
3. Check Console for any Core Data warnings

---

## Handoff Notes

**For Stage 05:**
- `CoreDataStack.shared` provides access to contexts
- `performBackgroundTask` for sync operations
- `needsSync` flag tracks pending uploads
- `syncedAt` tracks when data was last synced

**For Stage 06-10:**
- Use Swift models (`Order`, `Device`, etc.) in ViewModels
- Core Data entities are internal implementation detail
- Repository pattern will abstract data access
