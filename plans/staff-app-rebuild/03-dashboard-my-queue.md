# Stage 03: Dashboard & My Queue

## Objective

Implement the Staff dashboard with stats and "My Queue" showing devices assigned to the current user.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Dashboard stats response** - Read `/Volumes/Riki Repos/repairminder/worker/dashboard_handlers.js` and verify:
   - `getStats()` function return shape
   - Which fields are included for `scope=user` vs `scope=company`
   - Comparison period structure

2. **My Queue response** - Read `/Volumes/Riki Repos/repairminder/worker/device_handlers.js` and verify:
   - `getMyQueue()` function return shape
   - Filter options returned in response
   - Nested objects (device_type, assigned_engineer, sub_location)

3. **Device statuses** - Read `/Volumes/Riki Repos/repairminder/worker/src/device-workflows.js` for current status definitions

```bash
# Quick verification commands
grep -n "getStats\|getMyQueue" /Volumes/Riki\ Repos/repairminder/worker/dashboard_handlers.js
grep -n "REPAIR_DEVICE_STATUSES\|BUYBACK_DEVICE_STATUSES" /Volumes/Riki\ Repos/repairminder/worker/src/device-workflows.js
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## API Endpoints

### 1. GET /api/dashboard/stats

Main dashboard statistics endpoint.

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scope` | string | `user` | `user` or `company` (company requires admin/analyst role) |
| `period` | string | `this_month` | `today`, `yesterday`, `this_week`, `this_month`, `last_month`, `custom` |
| `start_date` | string | - | For custom period (ISO date) |
| `end_date` | string | - | For custom period (ISO date) |
| `compare_periods` | int | `1` | Number of comparison periods (1-18) |
| `user_id` | string | - | Admin only: view another user's stats |

**Response:**

```json
{
  "success": true,
  "data": {
    "period": "this_month",
    "devices": {
      "current": { "count": 45 },
      "comparisons": [
        {
          "period": "Last Month",
          "count": 38,
          "change": 7,
          "change_percent": 18.4
        }
      ]
    },
    "revenue": {
      "current": { "total": 12500.00 },
      "comparisons": [
        {
          "period": "Last Month",
          "total": 10200.00,
          "change": 2300.00,
          "change_percent": 22.5
        }
      ]
    },
    "clients": {
      "current": { "count": 32 },
      "comparisons": [...]
    },
    "new_clients": {
      "current": { "count": 12 },
      "comparisons": [...]
    },
    "returning_clients": {
      "current": { "count": 20 },
      "comparisons": [...]
    },
    "refunds": {
      "current": { "total": 150.00, "count": 2 },
      "comparisons": [...]
    },
    "attribution": {
      "booked_in": { "count": 28, "revenue": 8500.00 },
      "repaired": { "count": 35, "revenue": 11200.00 }
    },
    "company_comparison": {
      "user_avg_lifecycle_hours": 24.5,
      "company_avg_lifecycle_hours": 32.1
    },
    "awaiting_collection": {
      "outstanding_balance": 1250.00,
      "order_count": 5,
      "device_count": 8,
      "avg_wait_hours": 12.5
    },
    "unpaid_collected": {
      "total": 500.00,
      "count": 2,
      "order_ids": ["abc123", "def456"]
    },
    "payment_mismatch": {
      "count": 1,
      "order_ids": ["xyz789"],
      "total_discrepancy": 25.50
    },
    "revenue_breakdown": {
      "repair": 8500.00,
      "accessories": 1200.00,
      "device_sale": 2500.00,
      "buyback_sales": 800.00,
      "buyback_purchases": 400.00,
      "other": 100.00,
      "total": 13100.00
    }
  }
}
```

**Notes:**
- `attribution` only included for `scope=user`
- `awaiting_collection`, `unpaid_collected`, `payment_mismatch`, `revenue_breakdown` only for `scope=company`

---

### 2. GET /api/dashboard/enquiry-stats

Enquiry/ticket statistics.

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `scope` | string | `user` | `user` or `company` |
| `include_breakdown` | bool | `false` | Include per-user breakdown (company scope) |
| `user_id` | string | - | Admin only: view specific user's stats |

**Response:**

```json
{
  "success": true,
  "data": {
    "leads": {
      "today": { "count": 5, "change": 2, "change_percent": 66.7 },
      "yesterday": { "count": 3, "change": -1, "change_percent": -25.0 },
      "this_week": { "count": 25, "change": 8, "change_percent": 47.1 },
      "this_month": { "count": 85, "change": 12, "change_percent": 16.4 }
    },
    "first_replies": {
      "today": { "count": 4, "avg_minutes": 15.5 },
      "yesterday": { "count": 6, "avg_minutes": 22.3 },
      "this_week": { "count": 28, "avg_minutes": 18.2 },
      "this_month": { "count": 95, "avg_minutes": 20.1 }
    },
    "all_replies": {
      "today": { "count": 12 },
      "yesterday": { "count": 18 },
      "this_week": { "count": 85 },
      "this_month": { "count": 320 }
    },
    "internal_notes": {
      "today": { "count": 8 },
      "yesterday": { "count": 15 },
      "this_week": { "count": 62 },
      "this_month": { "count": 245 }
    },
    "company_avg_response_minutes": 25.5,
    "user_avg_response_minutes": 18.2,
    "by_user": [
      {
        "user_id": "abc123",
        "name": "John Doe",
        "leads": 15,
        "first_replies": 12,
        "avg_response_minutes": 16.8
      }
    ]
  }
}
```

---

### 3. GET /api/devices/my-queue

Devices assigned to current user (active work queue).

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | int | `1` | Page number |
| `limit` | int | `20` | Items per page (max 100) |
| `search` | string | - | Search serial, IMEI, brand, model |
| `category` | string | - | `repair`, `buyback`, or `unassigned` |

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "device-uuid",
      "order_id": "order-uuid",
      "ticket_id": "ticket-uuid",
      "order_number": "RM-12345",
      "display_name": "iPhone 14 Pro",
      "serial_number": "ABC123",
      "imei": "123456789012345",
      "colour": "Space Black",
      "status": "diagnosing",
      "workflow_type": "repair",
      "device_type": {
        "id": "type-uuid",
        "name": "Smartphone",
        "slug": "repair"
      },
      "assigned_engineer": {
        "id": "user-uuid",
        "name": "John Doe"
      },
      "location_id": "loc-uuid",
      "sub_location_id": "subloc-uuid",
      "sub_location": {
        "id": "subloc-uuid",
        "code": "BENCH-A1",
        "description": "Repair Bench A1",
        "type": "bench",
        "location_id": "loc-uuid"
      },
      "created_at": "2026-02-01T10:30:00Z",
      "due_date": "2026-02-05T17:00:00Z",
      "received_at": "2026-02-01T10:30:00Z",
      "scheduled": {
        "id": "schedule-uuid",
        "date": "2026-02-03",
        "startMinutes": 540,
        "duration": 60
      },
      "can_complete_report": true,
      "can_complete_repair": false,
      "pre_test_photos_count": 3,
      "notes": [
        {
          "body": "Customer mentioned water damage",
          "created_at": "2026-02-01T11:00:00Z",
          "created_by": "Jane Smith",
          "device_id": "device-uuid"
        }
      ],
      "checklist": {
        "items": [
          { "label": "Pre-repair photos", "completed": true },
          { "label": "Diagnosis notes", "completed": false }
        ],
        "percentComplete": 50,
        "nextActionLabel": "Add diagnosis notes"
      },
      "source": "order"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "total_pages": 3
  },
  "filters": {
    "device_types": [
      { "id": "type-uuid", "name": "Smartphone", "slug": "repair" }
    ],
    "statuses": ["device_received", "diagnosing", "ready_to_quote", ...],
    "category_counts": {
      "repair": 35,
      "buyback": 8,
      "unassigned": 2
    },
    "engineers": [
      { "id": "user-uuid", "name": "John Doe" }
    ],
    "locations": [
      { "id": "loc-uuid", "name": "Main Store" }
    ]
  }
}
```

**Notes:**
- `source` is either `"order"` (from order_devices) or `"buyback"` (from buyback_inventory)
- Excludes completed statuses: `collected`, `despatched`, `awaiting_parts`, `repaired_ready`, `added_to_buyback`
- Also excludes orders with status `awaiting_collection` or `collected_despatched`

---

### 4. GET /api/devices/my-active-work

Devices where current user has started but not completed diagnosis or repair.

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "device-uuid",
      "order_id": "order-uuid",
      "order_number": "RM-12345",
      "status": "diagnosing",
      "display_name": "iPhone 14 Pro",
      "work_type": "diagnosis",
      "started_at": "2026-02-01T14:30:00Z"
    }
  ]
}
```

**Notes:**
- Only returns devices where:
  - `status = 'diagnosing'` AND `diagnosis_started_by = current_user`, OR
  - `status = 'repairing'` AND `repair_started_by = current_user`

---

## Swift Models

### DashboardStats.swift

```swift
struct DashboardStats: Codable {
    let period: String
    let devices: StatMetric
    let revenue: RevenueMetric
    let clients: StatMetric
    let newClients: StatMetric
    let returningClients: StatMetric
    let refunds: RefundMetric
    let attribution: Attribution?
    let companyComparison: LifecycleComparison
    let awaitingCollection: AwaitingCollectionMetric?
    let unpaidCollected: UnpaidCollectedMetric?
    let paymentMismatch: PaymentMismatchMetric?
    let revenueBreakdown: RevenueBreakdown?

    enum CodingKeys: String, CodingKey {
        case period, devices, revenue, clients, refunds, attribution
        case newClients = "new_clients"
        case returningClients = "returning_clients"
        case companyComparison = "company_comparison"
        case awaitingCollection = "awaiting_collection"
        case unpaidCollected = "unpaid_collected"
        case paymentMismatch = "payment_mismatch"
        case revenueBreakdown = "revenue_breakdown"
    }
}

struct StatMetric: Codable {
    let current: CountValue
    let comparisons: [Comparison]
}

struct CountValue: Codable {
    let count: Int
}

struct RevenueMetric: Codable {
    let current: TotalValue
    let comparisons: [RevenueComparison]
}

struct TotalValue: Codable {
    let total: Double
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

struct RevenueComparison: Codable {
    let period: String
    let total: Double
    let change: Double
    let changePercent: Double

    enum CodingKeys: String, CodingKey {
        case period, total, change
        case changePercent = "change_percent"
    }
}

struct RefundMetric: Codable {
    let current: RefundValue
    let comparisons: [RefundComparison]
}

struct RefundValue: Codable {
    let total: Double
    let count: Int
}

struct RefundComparison: Codable {
    let period: String
    let total: Double
    let count: Int
    let change: Double
    let changePercent: Double

    enum CodingKeys: String, CodingKey {
        case period, total, count, change
        case changePercent = "change_percent"
    }
}

struct Attribution: Codable {
    let bookedIn: AttributionValue
    let repaired: AttributionValue

    enum CodingKeys: String, CodingKey {
        case bookedIn = "booked_in"
        case repaired
    }
}

struct AttributionValue: Codable {
    let count: Int
    let revenue: Double
}

struct LifecycleComparison: Codable {
    let userAvgLifecycleHours: Double?
    let companyAvgLifecycleHours: Double?

    enum CodingKeys: String, CodingKey {
        case userAvgLifecycleHours = "user_avg_lifecycle_hours"
        case companyAvgLifecycleHours = "company_avg_lifecycle_hours"
    }
}

struct AwaitingCollectionMetric: Codable {
    let outstandingBalance: Double
    let orderCount: Int
    let deviceCount: Int
    let avgWaitHours: Double

    enum CodingKeys: String, CodingKey {
        case outstandingBalance = "outstanding_balance"
        case orderCount = "order_count"
        case deviceCount = "device_count"
        case avgWaitHours = "avg_wait_hours"
    }
}

struct UnpaidCollectedMetric: Codable {
    let total: Double
    let count: Int
    let orderIds: [String]

    enum CodingKeys: String, CodingKey {
        case total, count
        case orderIds = "order_ids"
    }
}

struct PaymentMismatchMetric: Codable {
    let count: Int
    let orderIds: [String]
    let totalDiscrepancy: Double

    enum CodingKeys: String, CodingKey {
        case count
        case orderIds = "order_ids"
        case totalDiscrepancy = "total_discrepancy"
    }
}

struct RevenueBreakdown: Codable {
    let repair: Double
    let accessories: Double
    let deviceSale: Double
    let buybackSales: Double
    let buybackPurchases: Double
    let other: Double
    let total: Double

    enum CodingKeys: String, CodingKey {
        case repair, accessories, other, total
        case deviceSale = "device_sale"
        case buybackSales = "buyback_sales"
        case buybackPurchases = "buyback_purchases"
    }
}
```

### EnquiryStats.swift

```swift
struct EnquiryStats: Codable {
    let leads: [String: LeadPeriod]
    let firstReplies: [String: ReplyPeriod]
    let allReplies: [String: CountPeriod]
    let internalNotes: [String: CountPeriod]
    let companyAvgResponseMinutes: Double?
    let userAvgResponseMinutes: Double?
    let byUser: [UserEnquiryStat]?

    enum CodingKeys: String, CodingKey {
        case leads
        case firstReplies = "first_replies"
        case allReplies = "all_replies"
        case internalNotes = "internal_notes"
        case companyAvgResponseMinutes = "company_avg_response_minutes"
        case userAvgResponseMinutes = "user_avg_response_minutes"
        case byUser = "by_user"
    }
}

struct LeadPeriod: Codable {
    let count: Int
    let change: Int
    let changePercent: Double

    enum CodingKeys: String, CodingKey {
        case count, change
        case changePercent = "change_percent"
    }
}

struct ReplyPeriod: Codable {
    let count: Int
    let avgMinutes: Double?

    enum CodingKeys: String, CodingKey {
        case count
        case avgMinutes = "avg_minutes"
    }
}

struct CountPeriod: Codable {
    let count: Int
}

struct UserEnquiryStat: Codable, Identifiable {
    let userId: String
    let name: String
    let leads: Int
    let firstReplies: Int
    let avgResponseMinutes: Double?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, leads
        case firstReplies = "first_replies"
        case avgResponseMinutes = "avg_response_minutes"
    }
}
```

### DeviceQueueItem.swift

```swift
struct DeviceQueueItem: Codable, Identifiable {
    let id: String
    let orderId: String?
    let ticketId: String?
    let orderNumber: String?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let status: DeviceStatus
    let workflowType: WorkflowType
    let deviceType: DeviceTypeInfo?
    let assignedEngineer: EngineerInfo?
    let locationId: String?
    let subLocationId: String?
    let subLocation: SubLocationInfo?
    let createdAt: Date
    let dueDate: Date?
    let receivedAt: Date?
    let scheduled: ScheduleInfo?
    let canCompleteReport: Bool
    let canCompleteRepair: Bool
    let preTestPhotosCount: Int
    let notes: [DeviceNote]
    let checklist: DeviceChecklist
    let source: DeviceSource

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case ticketId = "ticket_id"
        case orderNumber = "order_number"
        case displayName = "display_name"
        case serialNumber = "serial_number"
        case imei, colour, status
        case workflowType = "workflow_type"
        case deviceType = "device_type"
        case assignedEngineer = "assigned_engineer"
        case locationId = "location_id"
        case subLocationId = "sub_location_id"
        case subLocation = "sub_location"
        case createdAt = "created_at"
        case dueDate = "due_date"
        case receivedAt = "received_at"
        case scheduled
        case canCompleteReport = "can_complete_report"
        case canCompleteRepair = "can_complete_repair"
        case preTestPhotosCount = "pre_test_photos_count"
        case notes, checklist, source
    }
}

struct DeviceTypeInfo: Codable {
    let id: String
    let name: String
    let slug: String
}

struct EngineerInfo: Codable {
    let id: String
    let name: String
}

struct SubLocationInfo: Codable {
    let id: String
    let code: String
    let description: String?
    let type: String?
    let locationId: String?

    enum CodingKeys: String, CodingKey {
        case id, code, description, type
        case locationId = "location_id"
    }
}

struct ScheduleInfo: Codable {
    let id: String
    let date: String
    let startMinutes: Int
    let duration: Int
}

struct DeviceNote: Codable {
    let body: String
    let createdAt: Date
    let createdBy: String?
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case body
        case createdAt = "created_at"
        case createdBy = "created_by"
        case deviceId = "device_id"
    }
}

struct DeviceChecklist: Codable {
    let items: [ChecklistItem]
    let percentComplete: Int
    let nextActionLabel: String?
}

struct ChecklistItem: Codable {
    let label: String
    let completed: Bool
}

enum DeviceSource: String, Codable {
    case order
    case buyback
}

enum WorkflowType: String, Codable {
    case repair
    case buyback
}
```

### DeviceStatus.swift

> **🔄 DYNAMIC CONFIGURATION PENDING:** Device status definitions (labels, colors) should eventually be fetched from a `/api/config` endpoint rather than hardcoded. For now, use these as initial values but design the code to support dynamic updates. See the backend source at `src/device-workflows.js` for the authoritative definitions.

```swift
enum DeviceStatus: String, Codable, CaseIterable {
    // Shared statuses
    case deviceReceived = "device_received"
    case diagnosing = "diagnosing"
    case readyToQuote = "ready_to_quote"
    case awaitingAuthorisation = "awaiting_authorisation"
    case rejected = "rejected"
    case companyRejected = "company_rejected"
    case rejectionQc = "rejection_qc"
    case rejectionReady = "rejection_ready"
    case collected = "collected"
    case despatched = "despatched"

    // Repair-only statuses
    case authorisedSourceParts = "authorised_source_parts"
    case authorisedAwaitingParts = "authorised_awaiting_parts"
    case readyToRepair = "ready_to_repair"
    case repairing = "repairing"
    case awaitingRevisedQuote = "awaiting_revised_quote"
    case repairedQc = "repaired_qc"
    case repairedReady = "repaired_ready"

    // Buyback-only statuses
    case readyToPay = "ready_to_pay"
    case paymentMade = "payment_made"
    case addedToBuyback = "added_to_buyback"

    var displayLabel: String {
        switch self {
        case .deviceReceived: return "Received"
        case .diagnosing: return "Being Assessed"
        case .readyToQuote: return "Quote Ready"
        case .awaitingAuthorisation: return "Awaiting Your Approval"
        case .authorisedSourceParts: return "Approved - Sourcing Parts"
        case .authorisedAwaitingParts: return "Approved - Awaiting Parts"
        case .readyToRepair: return "Repair Scheduled"
        case .repairing: return "Being Repaired"
        case .awaitingRevisedQuote: return "Awaiting Revised Quote"
        case .repairedQc: return "Quality Check"
        case .repairedReady: return "Ready for Collection"
        case .readyToPay: return "Payment Processing"
        case .paymentMade: return "Payment Complete"
        case .addedToBuyback: return "Added to Buyback"
        case .rejected: return "Quote Declined"
        case .companyRejected: return "Assessment Failed"
        case .rejectionQc: return "Preparing Return"
        case .rejectionReady: return "Ready for Collection"
        case .collected: return "Collected"
        case .despatched: return "Despatched"
        }
    }

    var color: String {
        switch self {
        case .deviceReceived: return "gray"
        case .diagnosing: return "purple"
        case .readyToQuote: return "indigo"
        case .awaitingAuthorisation: return "yellow"
        case .authorisedSourceParts, .authorisedAwaitingParts: return "orange"
        case .readyToRepair: return "cyan"
        case .repairing: return "teal"
        case .awaitingRevisedQuote: return "amber"
        case .repairedQc: return "pink"
        case .repairedReady: return "green"
        case .readyToPay: return "blue"
        case .paymentMade: return "emerald"
        case .addedToBuyback: return "violet"
        case .rejected: return "red"
        case .companyRejected: return "orange"
        case .rejectionQc: return "pink"
        case .rejectionReady: return "green"
        case .collected, .despatched: return "emerald"
        }
    }

    var isTerminal: Bool {
        [.collected, .despatched, .addedToBuyback].contains(self)
    }

    var isServiceComplete: Bool {
        [.repairedReady, .paymentMade, .addedToBuyback, .rejected,
         .companyRejected, .rejectionQc, .rejectionReady, .collected, .despatched].contains(self)
    }
}
```

### ActiveWorkItem.swift

```swift
struct ActiveWorkItem: Codable, Identifiable {
    let id: String
    let orderId: String
    let orderNumber: String
    let status: DeviceStatus
    let displayName: String
    let workType: WorkType
    let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case orderNumber = "order_number"
        case status
        case displayName = "display_name"
        case workType = "work_type"
        case startedAt = "started_at"
    }
}

enum WorkType: String, Codable {
    case diagnosis
    case repair
}
```

### MyQueueResponse.swift

```swift
struct MyQueueResponse: Codable {
    let data: [DeviceQueueItem]
    let pagination: Pagination
    let filters: QueueFilters
}

struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page, limit, total
        case totalPages = "total_pages"
    }
}

struct QueueFilters: Codable {
    let deviceTypes: [DeviceTypeInfo]
    let statuses: [String]
    let categoryCounts: CategoryCounts
    let engineers: [EngineerInfo]
    let locations: [LocationInfo]

    enum CodingKeys: String, CodingKey {
        case deviceTypes = "device_types"
        case statuses
        case categoryCounts = "category_counts"
        case engineers, locations
    }
}

struct CategoryCounts: Codable {
    let repair: Int
    let buyback: Int
    let unassigned: Int
}

struct LocationInfo: Codable, Identifiable {
    let id: String
    let name: String
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/DashboardStats.swift` | Dashboard stats response model |
| `Core/Models/EnquiryStats.swift` | Enquiry stats response model |
| `Core/Models/DeviceQueueItem.swift` | My queue device item model |
| `Core/Models/DeviceStatus.swift` | Device status enum with labels/colors |
| `Core/Models/ActiveWorkItem.swift` | Active work response model |
| `Features/Staff/Dashboard/DashboardView.swift` | Main dashboard UI |
| `Features/Staff/Dashboard/DashboardViewModel.swift` | Dashboard data fetching |
| `Features/Staff/Dashboard/MyQueueView.swift` | My queue list UI |
| `Features/Staff/Dashboard/MyQueueViewModel.swift` | My queue data fetching |
| `Features/Staff/Dashboard/Components/StatCard.swift` | Reusable stat card component |
| `Features/Staff/Dashboard/Components/DeviceQueueRow.swift` | Queue item row component |

---

## Testing

```bash
# Test dashboard stats (generate fresh token first if needed)
curl -s "https://api.repairminder.com/api/dashboard/stats?scope=user&period=this_month" \
  -H "Authorization: Bearer TOKEN" | jq

# Test with company scope (requires admin role)
curl -s "https://api.repairminder.com/api/dashboard/stats?scope=company&period=this_month" \
  -H "Authorization: Bearer TOKEN" | jq

# Test enquiry stats
curl -s "https://api.repairminder.com/api/dashboard/enquiry-stats?scope=user" \
  -H "Authorization: Bearer TOKEN" | jq

# Test my queue
curl -s "https://api.repairminder.com/api/devices/my-queue?page=1&limit=20" \
  -H "Authorization: Bearer TOKEN" | jq

# Test my active work
curl -s "https://api.repairminder.com/api/devices/my-active-work" \
  -H "Authorization: Bearer TOKEN" | jq
```

See `/docs/REFERENCE-test-tokens/CLAUDE.md` for valid tokens.

---

## Verification Checklist

- [ ] Dashboard stats load and display correctly
- [ ] Stats show current values and comparisons
- [ ] My Queue shows assigned devices
- [ ] My Queue pagination works
- [ ] My Queue category filters work (repair/buyback/unassigned)
- [ ] My Queue search works
- [ ] Device status displays with correct label and color
- [ ] Active work items show in-progress work
- [ ] Pull-to-refresh works on all views
- [ ] No JSON decode errors in console
- [ ] Empty states display appropriately
