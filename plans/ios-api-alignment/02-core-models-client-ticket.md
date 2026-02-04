# Stage 02: Core Models - Client & Ticket

## Objective

Fix `Client.swift` and `Ticket.swift` models to match actual backend API response structures.

## Dependencies

- **Requires**: None (can run parallel with Stage 01)

## Complexity

**Medium** - Field renaming and additions, no complex nested structures

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Core/Models/Client.swift` | Fix field names, add/remove fields |
| `Repair Minder/Core/Models/Ticket.swift` | Fix field names, update structure |

## Files to Create

None

## Backend Reference

### Client Endpoint
**Endpoint**: `GET /api/clients/:id`
**Handler**: Search `handleGetClient` in `worker/index.js`

### Ticket Endpoint
**Endpoint**: `GET /api/tickets/:id`
**Handler**: Search `handleGetTicket` in `worker/index.js`

## Actual Backend Responses

### Client Response

```json
{
  "id": "uuid",
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone": "+1234567890",
  "country_code": "GB",
  "client_group_id": "uuid",
  "client_group_name": "VIP",
  "groups": [
    { "id": "uuid", "name": "VIP", "group_type": "manual" }
  ],
  "email_suppressed": false,
  "email_suppressed_at": null,
  "is_generated_email": false,
  "marketing_consent": true,
  "suppression_status": null,
  "suppression_error": null,
  "ticket_count": 5,
  "order_count": 10,
  "device_count": 15,
  "total_spend": 1234.56,
  "average_spend": 123.46,
  "last_contact_received": "2026-02-04T10:00:00.000Z",
  "last_contact_sent": "2026-02-04T10:00:00.000Z",
  "created_at": "2026-01-01T10:00:00.000Z"
}
```

### Ticket Response

```json
{
  "id": "uuid",
  "ticket_number": 12345,
  "subject": "Screen Repair",
  "status": "open",
  "ticket_type": "order",
  "assigned_user_id": "uuid",
  "location_id": "uuid",
  "created_at": "2026-02-04T10:00:00.000Z",
  "updated_at": "2026-02-04T10:00:00.000Z",
  "client_id": "uuid",
  "client_email": "john@example.com",
  "client_name": "John Doe",
  "assigned_first_name": "Jane",
  "assigned_last_name": "Smith",
  "loc_id": "uuid",
  "loc_name": "Main Store",
  "last_client_update": "2026-02-04T10:00:00.000Z",
  "order_id": "uuid",
  "order_status": "in_progress",
  "device_count": 2
}
```

## Implementation Details

### New Client.swift Structure

```swift
import Foundation

struct Client: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let countryCode: String?
    let clientGroupId: String?
    let clientGroupName: String?
    let groups: [ClientGroup]?
    let emailSuppressed: Bool?
    let emailSuppressedAt: Date?
    let isGeneratedEmail: Bool?
    let marketingConsent: Bool?
    let ticketCount: Int
    let orderCount: Int
    let deviceCount: Int
    let totalSpend: Double
    let averageSpend: Double?
    let lastContactReceived: Date?
    let lastContactSent: Date?
    let createdAt: Date

    // MARK: - Computed Properties

    var fullName: String {
        let parts = [firstName, lastName].compactMap { $0 }
        return parts.isEmpty ? email : parts.joined(separator: " ")
    }

    var initials: String {
        let first = firstName?.first.map(String.init) ?? ""
        let last = lastName?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

// MARK: - Nested Types

extension Client {
    struct ClientGroup: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let groupType: String?
    }
}
```

### Client Fields Removed (not in backend)

- `company`
- `address`
- `city`
- `postcode`
- `notes`
- `updatedAt`
- `totalSpent` (renamed to `totalSpend`)

### Client Fields Added (from backend)

- `countryCode`
- `clientGroupId`
- `clientGroupName`
- `groups` (array of ClientGroup)
- `emailSuppressed`
- `emailSuppressedAt`
- `isGeneratedEmail`
- `marketingConsent`
- `ticketCount`
- `deviceCount`
- `averageSpend`
- `lastContactReceived`
- `lastContactSent`

---

### New Ticket.swift Structure

```swift
import Foundation

struct Ticket: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let ticketNumber: Int
    let subject: String?
    let status: TicketStatus
    let ticketType: String?
    let assignedUserId: String?
    let locationId: String?
    let createdAt: Date
    let updatedAt: Date?
    let clientId: String?
    let clientEmail: String?
    let clientName: String?
    let assignedFirstName: String?
    let assignedLastName: String?
    let locId: String?
    let locName: String?
    let lastClientUpdate: Date?
    let orderId: String?
    let orderStatus: String?
    let deviceCount: Int?

    // MARK: - Computed Properties

    var assignedUserName: String? {
        guard let first = assignedFirstName else { return assignedLastName }
        guard let last = assignedLastName else { return first }
        return "\(first) \(last)"
    }

    var displayRef: String {
        "#\(ticketNumber)"
    }
}

// MARK: - Ticket Status

enum TicketStatus: String, Codable, CaseIterable, Sendable {
    case open = "open"
    case pending = "pending"
    case closed = "closed"
    case spam = "spam"
    case archived = "archived"

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .closed: return "Closed"
        case .spam: return "Spam"
        case .archived: return "Archived"
        }
    }

    var color: String {
        switch self {
        case .open: return "green"
        case .pending: return "orange"
        case .closed: return "gray"
        case .spam: return "red"
        case .archived: return "purple"
        }
    }
}
```

### Ticket Fields Removed (not in backend)

- `priority` (not in backend response)
- `orderRef` (use `orderId` and fetch order number separately if needed)
- `messageCount` (not in response, use `deviceCount`)
- `assignedUserName` (computed from first/last name now)

### Ticket Fields Added (from backend)

- `ticketType`
- `assignedFirstName`, `assignedLastName` (separate fields)
- `locId`, `locName`
- `lastClientUpdate`
- `orderStatus`
- `deviceCount`

## Database Changes

None (iOS models only)

## Test Cases

### Client Tests

| Test | Input | Expected Output |
|------|-------|-----------------|
| Decode client JSON | Backend response | Client object populated |
| Decode with null groups | JSON with `groups: null` | Client with `groups = nil` |
| Computed fullName | first="John", last="Doe" | "John Doe" |
| Computed fullName (no name) | first=nil, last=nil, email="test@x.com" | "test@x.com" |
| totalSpend decoding | `"total_spend": 1234.56` | `totalSpend = 1234.56` |

### Ticket Tests

| Test | Input | Expected Output |
|------|-------|-----------------|
| Decode ticket JSON | Backend response | Ticket object populated |
| Status enum decode | `"open"` | `TicketStatus.open` |
| Computed assignedUserName | first="Jane", last="Smith" | "Jane Smith" |
| displayRef | ticketNumber=12345 | "#12345" |

## Acceptance Checklist

- [ ] `Client.swift` compiles without errors
- [ ] `Ticket.swift` compiles without errors
- [ ] Client model has `totalSpend` (not `totalSpent`)
- [ ] Client model has `groups` array with `ClientGroup` struct
- [ ] Ticket model has separate `assignedFirstName`/`assignedLastName`
- [ ] Ticket computed `assignedUserName` works
- [ ] TicketStatus enum matches backend values

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

- Client views may reference `totalSpent` - needs update in Stage 08
- Enquiry views may reference `priority` - needs update in Stage 09
- List compilation errors for downstream stages
