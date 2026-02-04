# Stage 03: Core Models - Order & Dashboard Stats

## Objective

Verify and fix `Order.swift` and `DashboardStats.swift` models to match actual backend API responses.

## Dependencies

- **Requires**: None (can run parallel with Stages 01-02)

## Complexity

**Medium** - Order is mostly correct, DashboardStats needs verification

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Core/Models/Order.swift` | Verify structure, minor fixes if needed |
| `Repair Minder/Core/Models/DashboardStats.swift` | Verify and fix to match backend |

## Files to Create

None

## Backend Reference

### Order Endpoint
**Endpoint**: `GET /api/orders/:id`
**Handler**: Search `handleGetOrder` in `worker/index.js`

### Dashboard Endpoint
**Endpoint**: `GET /api/dashboard/stats`
**Handler**: Search `handleDashboardStats` in `worker/index.js`

## Actual Backend Responses

### Order Response

```json
{
  "id": "uuid",
  "order_number": 12345,
  "status": "in_progress",
  "order_total": "150.00",
  "amount_paid": "50.00",
  "balance_due": "100.00",
  "notes": "Customer notes here",
  "device_count": 2,
  "created_at": "2026-02-04T10:00:00.000Z",
  "updated_at": "2026-02-04T10:00:00.000Z",
  "client": {
    "id": "uuid",
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "phone": "+1234567890"
  },
  "location": {
    "id": "uuid",
    "name": "Main Store"
  },
  "assigned_user": {
    "id": "uuid",
    "name": "Jane Smith"
  }
}
```

### Dashboard Stats Response

**Important**: Verify exact structure by reading `handleDashboardStats` in backend.

```json
{
  "success": true,
  "data": {
    "period": "this_month",
    "devices_repaired": 42,
    "revenue": 8500.00,
    "new_clients": 15,
    "orders_created": 38,
    "average_repair_time": 2.5,
    "comparisons": {
      "devices_repaired": { "previous": 35, "change_percent": 20 },
      "revenue": { "previous": 7200, "change_percent": 18 }
    }
  }
}
```

**Note**: The exact structure needs verification from backend code. Read the handler function.

## Implementation Details

### Order.swift Verification

The Order model appears mostly correct based on existing verification doc. Verify these nested objects:

```swift
import Foundation

struct Order: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let orderNumber: Int
    let status: OrderStatus
    let orderTotal: String?
    let amountPaid: String?
    let balanceDue: String?
    let notes: String?
    let deviceCount: Int?
    let createdAt: Date
    let updatedAt: Date?
    let client: OrderClient?
    let location: OrderLocation?
    let assignedUser: OrderAssignedUser?

    // MARK: - Computed Properties

    var displayRef: String {
        "#\(orderNumber)"
    }

    var clientName: String? {
        guard let client = client else { return nil }
        let parts = [client.firstName, client.lastName].compactMap { $0 }
        return parts.isEmpty ? client.email : parts.joined(separator: " ")
    }
}

// MARK: - Nested Types

extension Order {
    struct OrderClient: Codable, Equatable, Sendable {
        let id: String
        let email: String
        let firstName: String?
        let lastName: String?
        let phone: String?
    }

    struct OrderLocation: Codable, Equatable, Sendable {
        let id: String
        let name: String
    }

    struct OrderAssignedUser: Codable, Equatable, Sendable {
        let id: String
        let name: String
    }
}

// MARK: - Order Status

enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case draft = "draft"
    case received = "received"
    case inProgress = "in_progress"
    case awaitingApproval = "awaiting_approval"
    case approved = "approved"
    case rejected = "rejected"
    case ready = "ready"
    case collected = "collected"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .received: return "Received"
        case .inProgress: return "In Progress"
        case .awaitingApproval: return "Awaiting Approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .cancelled: return "Cancelled"
        }
    }
}
```

### DashboardStats.swift

**Action Required**: Read `handleDashboardStats` in backend to get exact response structure.

```swift
import Foundation

// TODO: Verify this structure against actual backend response
struct DashboardStats: Codable, Equatable, Sendable {
    let period: String?
    let devicesRepaired: Int?
    let revenue: Double?
    let newClients: Int?
    let ordersCreated: Int?
    let averageRepairTime: Double?
    let comparisons: StatsComparisons?
}

struct StatsComparisons: Codable, Equatable, Sendable {
    let devicesRepaired: StatComparison?
    let revenue: StatComparison?
    let newClients: StatComparison?
    let ordersCreated: StatComparison?
}

struct StatComparison: Codable, Equatable, Sendable {
    let previous: Double?
    let changePercent: Double?
}
```

## Verification Steps

1. **Find dashboard handler**:
   ```bash
   grep -n "handleDashboardStats\|/api/dashboard/stats" \
     /Volumes/Riki\ Repos/repairminder/worker/index.js | head -20
   ```

2. **Read handler function** to document exact response fields

3. **Update DashboardStats.swift** to match

## Database Changes

None (iOS models only)

## Test Cases

### Order Tests

| Test | Input | Expected Output |
|------|-------|-----------------|
| Decode order JSON | Backend response | Order object populated |
| Decode nested client | JSON with client object | `order.client` populated |
| Status enum decode | `"in_progress"` | `OrderStatus.inProgress` |
| Computed clientName | client with first/last | "John Doe" |

### Dashboard Tests

| Test | Input | Expected Output |
|------|-------|-----------------|
| Decode dashboard stats | Backend response | DashboardStats populated |
| Handle missing comparisons | JSON without comparisons | `comparisons = nil` |

## Acceptance Checklist

- [ ] `Order.swift` compiles and matches backend
- [ ] Order nested types (`OrderClient`, `OrderLocation`, `OrderAssignedUser`) defined
- [ ] `OrderStatus` enum has all backend values
- [ ] `DashboardStats.swift` verified against actual backend handler
- [ ] DashboardStats model updated to match backend exactly
- [ ] Document any fields that differ from current implementation

## Deployment

```bash
# Build to verify compilation
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS"
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -destination "generic/platform=iOS" \
  build 2>&1 | head -50
```

## Handoff Notes

- Order model is used extensively - changes may cause compilation errors
- DashboardStats is used by DashboardViewModel - update in Stage 05
- Document exact dashboard response structure for Stage 05
