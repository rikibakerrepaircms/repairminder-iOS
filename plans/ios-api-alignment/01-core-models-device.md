# Stage 01: Core Models - Device

## Objective

Rewrite `Device.swift` to match the actual backend API response structure exactly.

## Dependencies

- **Requires**: None (foundation stage)

## Complexity

**High** - Complete model rewrite with nested structs

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Core/Models/Device.swift` | Complete rewrite to match backend |

## Files to Create

None

## Backend Reference

**Endpoint**: `GET /api/devices/:id` and `GET /api/devices`
**Handler**: Search `handleGetDevice` in `worker/index.js` around line 2903

## Actual Backend Response

```json
{
  "id": "uuid",
  "order_id": "uuid",
  "ticket_id": "uuid",
  "order_number": 12345,
  "client_first_name": "John",
  "client_last_name": "Doe",
  "display_name": "Apple iPhone 14 Pro",
  "serial_number": "ABC123",
  "imei": "123456789",
  "colour": "Black",
  "status": "received",
  "workflow_type": "repair",
  "device_type": {
    "id": "uuid",
    "name": "Phone",
    "slug": "repair"
  },
  "assigned_engineer": {
    "id": "uuid",
    "name": "John Smith"
  },
  "location_id": "uuid",
  "sub_location_id": "uuid",
  "sub_location": {
    "id": "uuid",
    "code": "A1",
    "description": "Shelf A1",
    "type": "shelf",
    "location_id": "uuid"
  },
  "received_at": "2026-02-04T10:00:00.000Z",
  "due_date": "2026-02-07T10:00:00.000Z",
  "created_at": "2026-02-04T10:00:00.000Z",
  "notes": [],
  "source": "order"
}
```

## Implementation Details

### New Device.swift Structure

```swift
import Foundation

struct Device: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let orderId: String?
    let ticketId: String?
    let orderNumber: Int?
    let clientFirstName: String?
    let clientLastName: String?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let status: DeviceStatus
    let workflowType: String?
    let deviceType: DeviceTypeInfo?
    let assignedEngineer: AssignedEngineer?
    let locationId: String?
    let subLocationId: String?
    let subLocation: SubLocation?
    let receivedAt: Date?
    let dueDate: Date?
    let createdAt: Date
    let notes: [DeviceNote]?
    let source: String?

    // MARK: - Computed Properties

    var clientFullName: String? {
        guard let first = clientFirstName else { return clientLastName }
        guard let last = clientLastName else { return first }
        return "\(first) \(last)"
    }

    var assignedEngineerName: String? {
        assignedEngineer?.name
    }

    var locationDescription: String? {
        subLocation?.description ?? subLocation?.code
    }
}

// MARK: - Nested Types

extension Device {
    struct DeviceTypeInfo: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let slug: String
    }

    struct AssignedEngineer: Codable, Equatable, Sendable {
        let id: String
        let name: String
    }

    struct SubLocation: Codable, Equatable, Sendable {
        let id: String
        let code: String?
        let description: String?
        let type: String?
        let locationId: String?
    }

    struct DeviceNote: Codable, Equatable, Sendable {
        let id: String?
        let body: String?
        let createdAt: Date?
        let createdBy: String?
        let deviceId: String?
    }
}

// MARK: - Device Status

enum DeviceStatus: String, Codable, CaseIterable, Sendable {
    case received = "received"
    case diagnosing = "diagnosing"
    case pendingApproval = "pending_approval"
    case awaitingParts = "awaiting_parts"
    case inRepair = "in_repair"
    case qualityCheck = "quality_check"
    case ready = "ready"
    case collected = "collected"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .received: return "Received"
        case .diagnosing: return "Diagnosing"
        case .pendingApproval: return "Pending Approval"
        case .awaitingParts: return "Awaiting Parts"
        case .inRepair: return "In Repair"
        case .qualityCheck: return "Quality Check"
        case .ready: return "Ready"
        case .collected: return "Collected"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .received: return "blue"
        case .diagnosing: return "orange"
        case .pendingApproval: return "yellow"
        case .awaitingParts: return "purple"
        case .inRepair: return "indigo"
        case .qualityCheck: return "teal"
        case .ready: return "green"
        case .collected: return "gray"
        case .cancelled: return "red"
        }
    }
}
```

### Fields Removed (not in backend)

- `type` (use `deviceType.name` instead)
- `brand` (part of `displayName`)
- `model` (part of `displayName`)
- `serial` (renamed to `serialNumber`)
- `passcode` (not in backend)
- `issue` (not in backend - use notes)
- `diagnosis` (not in backend - use notes)
- `resolution` (not in backend - use notes)
- `price` (not in device response)
- `assignedUserId` (use `assignedEngineer.id`)
- `assignedUserName` (use `assignedEngineer.name`)
- `updatedAt` (not in backend)

### Fields Added (from backend)

- `ticketId`
- `orderNumber`
- `clientFirstName`, `clientLastName`
- `displayName`
- `colour`
- `workflowType`
- `deviceType` (nested object)
- `assignedEngineer` (nested object)
- `locationId`
- `subLocationId`, `subLocation` (nested object)
- `receivedAt`
- `dueDate`
- `notes` (array)
- `source`

## Database Changes

None (iOS models only)

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Decode device JSON | Backend response JSON | Device object with all fields populated |
| Decode device with null optionals | JSON with null engineer | Device with `assignedEngineer = nil` |
| Decode device list | Array of device JSON | `[Device]` array |
| Status enum decode | `"in_repair"` | `DeviceStatus.inRepair` |
| Computed clientFullName | first="John", last="Doe" | "John Doe" |

## Acceptance Checklist

- [ ] `Device.swift` compiles without errors
- [ ] All properties match backend response field names (with camelCase conversion)
- [ ] Nested structs (`DeviceTypeInfo`, `AssignedEngineer`, `SubLocation`, `DeviceNote`) are defined
- [ ] `DeviceStatus` enum has all values from backend
- [ ] Computed properties work correctly
- [ ] Files that import Device still compile (may have errors to fix in later stages)

## Deployment

```bash
# Build to verify compilation
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS"
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -destination "generic/platform=iOS" \
  build 2>&1 | head -50
```

Note: Build may fail due to other files using old Device properties. Document these for later stages.

## Handoff Notes

- View models using Device will need updates in Stage 07
- Components like `DeviceStatusBadge`, `DeviceHeaderCard` may reference old properties
- List any compilation errors found for Stage 07 to fix
