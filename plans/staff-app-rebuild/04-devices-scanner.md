# Stage 04: Devices & Scanner

## Objective

Implement device listing, device detail view, barcode scanner for device lookup, and device status management.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Device list response** - Read `/Volumes/Riki Repos/repairminder/worker/device_handlers.js` and verify:
   - `getDevices()` function return shape
   - Filter and pagination structure
   - Nested objects (device_type, assigned_engineer, sub_location, notes)

2. **Device detail response** - Verify the full device object structure including:
   - Authorization info, timestamps, action_by fields
   - Images, accessories, parts_used arrays
   - Checklist structure

3. **Status transitions** - Read `/Volumes/Riki Repos/repairminder/worker/src/device-workflows.js` and verify:
   - `getNextStatuses()` function logic
   - Valid transitions for each status
   - Device page allowed transitions

4. **Actions endpoint** - Verify `/api/orders/:orderId/devices/:deviceId/actions` response shape

```bash
# Quick verification commands
grep -n "getDevices\|getDevice\|getNextStatuses" /Volumes/Riki\ Repos/repairminder/worker/device_handlers.js
grep -n "REPAIR_TRANSITIONS\|BUYBACK_TRANSITIONS" /Volumes/Riki\ Repos/repairminder/worker/src/device-workflows.js
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## API Endpoints

### 1. GET /api/devices

List all devices with filtering and pagination.

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | int | `1` | Page number |
| `limit` | int | `20` | Items per page (max 100) |
| `search` | string | - | Search serial, IMEI, brand, model, custom brand/model |
| `device_type_id` | string | - | Filter by device type (or `unassigned`) |
| `status` | string | - | Filter by status (comma-separated for multiple) |
| `exclude_status` | string | - | Exclude statuses (comma-separated) |
| `show_archived` | bool | `false` | Include archived devices |
| `engineer_id` | string | - | Filter by engineer (comma-separated, or `unassigned`) |
| `period` | string | - | `today`, `yesterday`, `this_week`, `this_month`, `last_month` |
| `date_filter` | string | `created` | `created` or `completed` |
| `location_id` | string | - | Filter by location |
| `include_buyback` | bool | `false` | Include buyback inventory items |
| `workflow_category` | string | - | `repair`, `buyback`, `refurb`, or `unassigned` |
| `collection_status` | string | - | `awaiting` - devices awaiting collection |
| `category` | string | - | Filter by order item type |

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
      "client_first_name": "John",
      "client_last_name": "Doe",
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
      "received_at": "2026-02-01T10:30:00Z",
      "due_date": "2026-02-05T17:00:00Z",
      "created_at": "2026-02-01T10:30:00Z",
      "notes": [
        {
          "body": "Customer mentioned water damage",
          "created_at": "2026-02-01T11:00:00Z",
          "created_by": "Jane Smith",
          "device_id": "device-uuid"
        }
      ],
      "source": "order"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  },
  "filters": {
    "device_types": [
      { "id": "type-uuid", "name": "Smartphone", "slug": "repair" }
    ],
    "engineers": [
      { "id": "user-uuid", "first_name": "John", "last_name": "Doe" }
    ],
    "locations": [
      { "id": "loc-uuid", "name": "Main Store" }
    ],
    "category_counts": {
      "repair": 120,
      "buyback": 25,
      "refurb": 8,
      "unassigned": 5
    }
  }
}
```

---

### 2. GET /api/orders/:orderId/devices/:deviceId

Get full device detail with all nested objects.

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "device-uuid",
    "order_id": "order-uuid",
    "brand": {
      "id": "brand-uuid",
      "name": "Apple",
      "category": "smartphone"
    },
    "model": {
      "id": "model-uuid",
      "name": "iPhone 14 Pro"
    },
    "custom_brand": null,
    "custom_model": null,
    "display_name": "Apple iPhone 14 Pro",
    "serial_number": "ABC123DEF456",
    "imei": "123456789012345",
    "colour": "Space Black",
    "storage_capacity": "256GB",
    "passcode": "1234",
    "passcode_type": "pin",
    "find_my_status": "disabled",
    "condition_grade": "B",
    "customer_reported_issues": "Screen cracked, battery draining fast",
    "technician_found_issues": "Display assembly damaged, battery at 78% health",
    "additional_issues_found": "Minor dent on frame",
    "condition_notes": "Overall good condition except screen",
    "data_backup_offered": true,
    "data_backup_accepted": true,
    "data_backup_completed": false,
    "factory_reset_required": false,
    "factory_reset_completed": false,
    "is_under_warranty": false,
    "warranty_provider": null,
    "warranty_expiry_date": null,
    "insurance_claim": false,
    "insurance_reference": null,
    "status": "diagnosing",
    "priority": "normal",
    "due_date": "2026-02-05T17:00:00Z",
    "assigned_engineer": {
      "id": "user-uuid",
      "name": "John Doe"
    },
    "sub_location_id": "subloc-uuid",
    "sub_location": {
      "id": "subloc-uuid",
      "code": "BENCH-A1",
      "description": "Repair Bench A1",
      "type": "bench"
    },
    "device_type": {
      "id": "type-uuid",
      "name": "Smartphone",
      "slug": "repair"
    },
    "diagnosis_notes": "Screen needs full replacement",
    "repair_notes": null,
    "technician_notes": "Customer wants original parts if possible",
    "authorization_notes": null,
    "authorization": {
      "status": null,
      "method": null,
      "authorized_at": null,
      "authorized_by": null,
      "authorized_by_name": null,
      "signature": null
    },
    "visual_check": "Cracked screen, no other visible damage",
    "electrical_check": "All functions working except Face ID",
    "mechanical_check": "Buttons responsive",
    "damage_matches_reported": true,
    "diagnosis_conclusion": "Recommend screen replacement",
    "timestamps": {
      "received_at": "2026-02-01T10:30:00Z",
      "checked_in_at": "2026-02-01T10:35:00Z",
      "diagnosis_started_at": "2026-02-01T11:00:00Z",
      "diagnosis_completed_at": null,
      "report_sent_at": null,
      "report_authorised_at": null,
      "report_rejected_at": null,
      "repair_started_at": null,
      "repair_completed_at": null,
      "quality_checked_at": null,
      "ready_for_collection_at": null,
      "collected_at": null,
      "despatched_at": null
    },
    "action_by": {
      "diagnosis_started_by": "John Doe",
      "diagnosis_completed_by": null,
      "repair_started_by": null,
      "repair_completed_by": null,
      "quote_sent_by": null,
      "marked_ready_by": null
    },
    "images": [
      {
        "id": "img-uuid",
        "image_type": "pre_repair",
        "r2_key": "devices/abc123/img1.jpg",
        "filename": "screen_damage.jpg",
        "caption": "Front screen damage",
        "sort_order": 1,
        "uploaded_at": "2026-02-01T11:05:00Z"
      }
    ],
    "accessories": [
      {
        "id": "acc-uuid",
        "accessory_type": "charger",
        "description": "Apple 20W USB-C charger",
        "returned_at": null,
        "created_at": "2026-02-01T10:30:00Z"
      }
    ],
    "parts_used": [
      {
        "id": "part-uuid",
        "part_name": "iPhone 14 Pro Screen Assembly",
        "part_sku": "IPH14P-SCR-001",
        "part_cost": 89.99,
        "supplier": "Mobile Parts Co",
        "is_oem": true,
        "warranty_days": 90,
        "installed_at": null,
        "installed_by": null
      }
    ],
    "line_items": [
      {
        "id": "item-uuid",
        "description": "Screen Replacement - iPhone 14 Pro",
        "quantity": 1,
        "unit_price": 149.99,
        "vat_rate": 20.0,
        "line_total_inc_vat": 179.99
      }
    ],
    "device_notes": [
      {
        "id": "note-uuid",
        "body": "Customer prefers collection after 5pm",
        "created_at": "2026-02-01T11:10:00Z",
        "created_by": "Jane Smith"
      }
    ],
    "workflow_type": "repair",
    "authorized_next_status": null,
    "checklist": [
      {
        "key": "found_issues",
        "label": "Document found issues",
        "completed": true,
        "required": true
      },
      {
        "key": "diagnosis_notes",
        "label": "Add diagnosis notes",
        "completed": true,
        "required": true
      },
      {
        "key": "line_items",
        "label": "Add line items",
        "completed": true,
        "required": true
      }
    ],
    "created_at": "2026-02-01T10:30:00Z",
    "updated_at": "2026-02-01T11:15:00Z"
  }
}
```

---

### 3. PATCH /api/orders/:orderId/devices/:deviceId

Update device fields.

**Request Body (all fields optional):**

```json
{
  "brand_id": "brand-uuid",
  "model_id": "model-uuid",
  "custom_brand": "Custom Brand",
  "custom_model": "Custom Model",
  "serial_number": "ABC123",
  "imei": "123456789012345",
  "colour": "Space Black",
  "storage_capacity": "256GB",
  "passcode": "1234",
  "passcode_type": "pin",
  "find_my_status": "disabled",
  "condition_grade": "B",
  "customer_reported_issues": "Screen cracked",
  "technician_found_issues": "Display damaged",
  "additional_issues_found": "Minor dent",
  "condition_notes": "Good overall",
  "diagnosis_notes": "Needs replacement",
  "repair_notes": "Completed successfully",
  "technician_notes": "Original parts used",
  "data_backup_offered": true,
  "data_backup_accepted": true,
  "data_backup_completed": true,
  "factory_reset_required": true,
  "factory_reset_completed": true,
  "is_under_warranty": false,
  "warranty_provider": "Apple",
  "warranty_expiry_date": "2025-12-31",
  "insurance_claim": false,
  "insurance_reference": "INS-12345",
  "priority": "urgent",
  "due_date": "2026-02-05T17:00:00Z",
  "assigned_engineer_id": "user-uuid",
  "sub_location_id": "subloc-uuid",
  "device_type_id": "type-uuid",
  "workflow_type": "repair",
  "visual_check": "No visible damage",
  "electrical_check": "All functions working",
  "mechanical_check": "Buttons responsive",
  "damage_matches_reported": true,
  "diagnosis_conclusion": "Ready for repair"
}
```

**Validation Rules:**

| Field | Valid Values |
|-------|--------------|
| `passcode_type` | `pin`, `pattern`, `password`, `biometric`, `none` |
| `find_my_status` | `disabled`, `enabled`, `unknown` |
| `condition_grade` | `A`, `B`, `C`, `D`, `F` |
| `priority` | `normal`, `urgent`, `express` |
| `workflow_type` | `repair`, `buyback`, `buyback_sale` |

**Response:**

```json
{
  "success": true,
  "data": { /* updated device object */ }
}
```

---

### 4. Device Scanner - Search by Serial/IMEI

Use `GET /api/devices?search=SERIAL_OR_IMEI` to look up devices by serial number or IMEI.

```bash
GET /api/devices?search=ABC123DEF456&limit=10
```

The search matches against:
- `serial_number`
- `imei`
- `brand.name`
- `model.name`
- `custom_brand`
- `custom_model`

---

## Device Statuses

> **🔄 DYNAMIC CONFIGURATION PENDING:** Device status definitions (labels, colors, transitions) should eventually be fetched from a `/api/config` endpoint rather than hardcoded. For now, use these as initial values but design the code to support dynamic updates. The authoritative source is `src/device-workflows.js` in the backend.

### Repair Workflow (REPAIR_DEVICE_STATUSES)

| Status | Label | Color |
|--------|-------|-------|
| `device_received` | Received | gray |
| `diagnosing` | Being Assessed | purple |
| `ready_to_quote` | Quote Ready | indigo |
| `awaiting_authorisation` | Awaiting Your Approval | yellow |
| `authorised_source_parts` | Approved - Sourcing Parts | orange |
| `authorised_awaiting_parts` | Approved - Awaiting Parts | orange |
| `ready_to_repair` | Repair Scheduled | cyan |
| `repairing` | Being Repaired | teal |
| `awaiting_revised_quote` | Awaiting Revised Quote | amber |
| `repaired_qc` | Quality Check | pink |
| `repaired_ready` | Ready for Collection | green |
| `rejected` | Quote Declined | red |
| `company_rejected` | Assessment Failed | orange |
| `rejection_qc` | Preparing Return | pink |
| `rejection_ready` | Ready for Collection | green |
| `collected` | Collected | emerald |
| `despatched` | Despatched | emerald |

### Buyback Workflow (BUYBACK_DEVICE_STATUSES)

| Status | Label | Color |
|--------|-------|-------|
| `device_received` | Received | gray |
| `diagnosing` | Being Assessed | purple |
| `company_rejected` | Assessment Failed | orange |
| `ready_to_quote` | Quote Ready | indigo |
| `awaiting_authorisation` | Awaiting Your Approval | yellow |
| `ready_to_pay` | Payment Processing | blue |
| `payment_made` | Payment Complete | emerald |
| `added_to_buyback` | Added to Buyback | violet |
| `rejected` | Quote Declined | red |
| `rejection_qc` | Preparing Return | pink |
| `rejection_ready` | Ready for Collection | green |
| `collected` | Collected | emerald |
| `despatched` | Despatched | emerald |

---

## Status Transitions

### Repair Workflow Transitions

```
device_received -> [diagnosing]

diagnosing -> [ready_to_quote]

ready_to_quote -> [awaiting_authorisation, company_rejected,
                   authorised_source_parts, authorised_awaiting_parts, ready_to_repair]

company_rejected -> [rejection_qc]

awaiting_authorisation -> [authorised_source_parts, authorised_awaiting_parts,
                           ready_to_repair, rejected]

authorised_source_parts -> [authorised_awaiting_parts, awaiting_authorisation]

authorised_awaiting_parts -> [ready_to_repair, awaiting_authorisation]

ready_to_repair -> [repairing, awaiting_authorisation]

repairing -> [repaired_qc, awaiting_revised_quote, awaiting_authorisation]

awaiting_revised_quote -> [awaiting_authorisation]

repaired_qc -> [repaired_ready, ready_to_repair]  // Can fail QC

repaired_ready -> [collected, despatched]

rejected -> [rejection_qc]

rejection_qc -> [rejection_ready]

rejection_ready -> [collected, despatched]

collected -> []  // Terminal
despatched -> []  // Terminal
```

### Buyback Workflow Transitions

```
device_received -> [diagnosing]

diagnosing -> [ready_to_quote, company_rejected]

company_rejected -> [rejection_qc]

ready_to_quote -> [awaiting_authorisation]

awaiting_authorisation -> [ready_to_pay, rejected]

ready_to_pay -> [payment_made]

payment_made -> [added_to_buyback]

added_to_buyback -> []  // Terminal

rejected -> [rejection_qc]

rejection_qc -> [rejection_ready]

rejection_ready -> [collected, despatched]

collected -> []  // Terminal
despatched -> []  // Terminal
```

### Transition Action Labels

| Transition | Action Label |
|------------|--------------|
| `device_received->diagnosing` | Start Diagnosis |
| `diagnosing->ready_to_quote` | Complete Diagnosis |
| `ready_to_quote->awaiting_authorisation` | Send Quote |
| `ready_to_quote->company_rejected` | Mark as Unrepairable |
| `awaiting_authorisation->authorised_source_parts` | Approved - Order Parts |
| `awaiting_authorisation->authorised_awaiting_parts` | Approved - Parts Ordered |
| `awaiting_authorisation->ready_to_repair` | Approved - Ready to Repair |
| `awaiting_authorisation->rejected` | Mark Rejected |
| `authorised_source_parts->authorised_awaiting_parts` | Parts Ordered |
| `authorised_awaiting_parts->ready_to_repair` | Parts Received |
| `ready_to_repair->repairing` | Start Repair |
| `repairing->repaired_qc` | Complete Repair |
| `repairing->awaiting_revised_quote` | Submit for Revised Quote |
| `repaired_qc->repaired_ready` | QC Passed |
| `repaired_qc->ready_to_repair` | QC Failed - Rework |
| `repaired_ready->collected` | Mark Collected |
| `repaired_ready->despatched` | Mark Despatched |
| `awaiting_authorisation->ready_to_pay` | Approved - Ready to Pay |
| `ready_to_pay->payment_made` | Payment Made |
| `payment_made->added_to_buyback` | Add to Buyback |
| `rejected->rejection_qc` | Prepare for Return |
| `company_rejected->rejection_qc` | Prepare for Return |
| `rejection_qc->rejection_ready` | Ready for Collection |

### Device Page Allowed Transitions

These transitions can only be made from the device detail page (hands-on work):

| From | To | Action |
|------|-----|--------|
| `device_received` | `diagnosing` | Start Diagnosis |
| `diagnosing` | `ready_to_quote` | Complete Diagnosis |
| `ready_to_repair` | `repairing` | Start Repair |
| `repairing` | `repaired_qc` | Complete Repair |
| `repairing` | `awaiting_revised_quote` | Submit for Revised Quote |

---

## Full Device Model

```swift
struct Device: Codable, Identifiable {
    let id: String
    let orderId: String
    let brandId: String?
    let modelId: String?
    let brandName: String?
    let modelName: String?
    let customBrand: String?
    let customModel: String?
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let status: DeviceStatus
    let workflowType: WorkflowType
    let priority: DevicePriority
    let dueDate: Date?
    let assignedEngineerId: String?
    let engineerName: String?
    let conditionGrade: String?
    let findMyStatus: FindMyStatus?
    let subLocationId: String?
    let subLocationCode: String?
    let deviceTypeId: String?
    let deviceTypeName: String?
    let customerReportedIssues: String?
    let technicianFoundIssues: String?
    let diagnosisNotes: String?
    let repairNotes: String?
    let receivedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var displayName: String {
        if let brand = brandName {
            return "\(brand) \(modelName ?? customModel ?? "")".trimmingCharacters(in: .whitespaces)
        } else if let custom = customBrand {
            return "\(custom) \(customModel ?? "")".trimmingCharacters(in: .whitespaces)
        }
        return modelName ?? customModel ?? "Unknown Device"
    }
}

enum DevicePriority: String, Codable {
    case normal
    case urgent
    case express
}

enum FindMyStatus: String, Codable {
    case disabled
    case enabled
    case unknown
}

enum PasscodeType: String, Codable {
    case pin
    case pattern
    case password
    case biometric
    case none
}

enum ConditionGrade: String, Codable, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
}
```

---

## Swift Models

### DeviceListItem.swift

```swift
struct DeviceListItem: Codable, Identifiable {
    let id: String
    let orderId: String
    let ticketId: String?
    let orderNumber: String?
    let clientFirstName: String?
    let clientLastName: String?
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
    let receivedAt: Date?
    let dueDate: Date?
    let createdAt: Date
    let notes: [DeviceNote]
    let source: DeviceSource

    var clientName: String? {
        guard let first = clientFirstName else { return nil }
        return "\(first) \(clientLastName ?? "")".trimmingCharacters(in: .whitespaces)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case ticketId = "ticket_id"
        case orderNumber = "order_number"
        case clientFirstName = "client_first_name"
        case clientLastName = "client_last_name"
        case displayName = "display_name"
        case serialNumber = "serial_number"
        case imei, colour, status
        case workflowType = "workflow_type"
        case deviceType = "device_type"
        case assignedEngineer = "assigned_engineer"
        case locationId = "location_id"
        case subLocationId = "sub_location_id"
        case subLocation = "sub_location"
        case receivedAt = "received_at"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case notes, source
    }
}
```

### DeviceDetail.swift

```swift
struct DeviceDetail: Codable, Identifiable {
    let id: String
    let orderId: String
    let brand: BrandInfo?
    let model: ModelInfo?
    let customBrand: String?
    let customModel: String?
    let displayName: String
    let serialNumber: String?
    let imei: String?
    let colour: String?
    let storageCapacity: String?
    let passcode: String?
    let passcodeType: String?
    let findMyStatus: String?
    let conditionGrade: String?
    let customerReportedIssues: String?
    let technicianFoundIssues: String?
    let additionalIssuesFound: String?
    let conditionNotes: String?
    let dataBackupOffered: Bool
    let dataBackupAccepted: Bool
    let dataBackupCompleted: Bool
    let factoryResetRequired: Bool
    let factoryResetCompleted: Bool
    let isUnderWarranty: Bool
    let warrantyProvider: String?
    let warrantyExpiryDate: String?
    let insuranceClaim: Bool
    let insuranceReference: String?
    let status: DeviceStatus
    let priority: String
    let dueDate: Date?
    let assignedEngineer: EngineerInfo?
    let subLocationId: String?
    let subLocation: SubLocationInfo?
    let deviceType: DeviceTypeInfo?
    let diagnosisNotes: String?
    let repairNotes: String?
    let technicianNotes: String?
    let authorizationNotes: String?
    let authorization: AuthorizationInfo
    let visualCheck: String?
    let electricalCheck: String?
    let mechanicalCheck: String?
    let damageMatchesReported: Bool?
    let diagnosisConclusion: String?
    let timestamps: DeviceTimestamps
    let actionBy: ActionByInfo
    let images: [DeviceImage]
    let accessories: [DeviceAccessory]
    let partsUsed: [DevicePart]
    let lineItems: [DeviceLineItem]
    let deviceNotes: [DeviceNote]
    let workflowType: WorkflowType
    let authorizedNextStatus: String?
    let checklist: [ChecklistItem]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case brand, model
        case customBrand = "custom_brand"
        case customModel = "custom_model"
        case displayName = "display_name"
        case serialNumber = "serial_number"
        case imei, colour
        case storageCapacity = "storage_capacity"
        case passcode
        case passcodeType = "passcode_type"
        case findMyStatus = "find_my_status"
        case conditionGrade = "condition_grade"
        case customerReportedIssues = "customer_reported_issues"
        case technicianFoundIssues = "technician_found_issues"
        case additionalIssuesFound = "additional_issues_found"
        case conditionNotes = "condition_notes"
        case dataBackupOffered = "data_backup_offered"
        case dataBackupAccepted = "data_backup_accepted"
        case dataBackupCompleted = "data_backup_completed"
        case factoryResetRequired = "factory_reset_required"
        case factoryResetCompleted = "factory_reset_completed"
        case isUnderWarranty = "is_under_warranty"
        case warrantyProvider = "warranty_provider"
        case warrantyExpiryDate = "warranty_expiry_date"
        case insuranceClaim = "insurance_claim"
        case insuranceReference = "insurance_reference"
        case status, priority
        case dueDate = "due_date"
        case assignedEngineer = "assigned_engineer"
        case subLocationId = "sub_location_id"
        case subLocation = "sub_location"
        case deviceType = "device_type"
        case diagnosisNotes = "diagnosis_notes"
        case repairNotes = "repair_notes"
        case technicianNotes = "technician_notes"
        case authorizationNotes = "authorization_notes"
        case authorization
        case visualCheck = "visual_check"
        case electricalCheck = "electrical_check"
        case mechanicalCheck = "mechanical_check"
        case damageMatchesReported = "damage_matches_reported"
        case diagnosisConclusion = "diagnosis_conclusion"
        case timestamps
        case actionBy = "action_by"
        case images, accessories
        case partsUsed = "parts_used"
        case lineItems = "line_items"
        case deviceNotes = "device_notes"
        case workflowType = "workflow_type"
        case authorizedNextStatus = "authorized_next_status"
        case checklist
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BrandInfo: Codable {
    let id: String
    let name: String
    let category: String?
}

struct ModelInfo: Codable {
    let id: String
    let name: String
}

struct AuthorizationInfo: Codable {
    let status: String?
    let method: String?
    let authorizedAt: Date?
    let authorizedBy: String?
    let authorizedByName: String?
    let signature: SignatureInfo?

    enum CodingKeys: String, CodingKey {
        case status, method
        case authorizedAt = "authorized_at"
        case authorizedBy = "authorized_by"
        case authorizedByName = "authorized_by_name"
        case signature
    }
}

struct SignatureInfo: Codable {
    let type: String
    let action: String
    let ipAddress: String?
    let userAgent: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case type, action
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case createdAt = "created_at"
    }
}

struct DeviceTimestamps: Codable {
    let receivedAt: Date?
    let checkedInAt: Date?
    let diagnosisStartedAt: Date?
    let diagnosisCompletedAt: Date?
    let reportSentAt: Date?
    let reportAuthorisedAt: Date?
    let reportRejectedAt: Date?
    let repairStartedAt: Date?
    let repairCompletedAt: Date?
    let qualityCheckedAt: Date?
    let readyForCollectionAt: Date?
    let collectedAt: Date?
    let despatchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case receivedAt = "received_at"
        case checkedInAt = "checked_in_at"
        case diagnosisStartedAt = "diagnosis_started_at"
        case diagnosisCompletedAt = "diagnosis_completed_at"
        case reportSentAt = "report_sent_at"
        case reportAuthorisedAt = "report_authorised_at"
        case reportRejectedAt = "report_rejected_at"
        case repairStartedAt = "repair_started_at"
        case repairCompletedAt = "repair_completed_at"
        case qualityCheckedAt = "quality_checked_at"
        case readyForCollectionAt = "ready_for_collection_at"
        case collectedAt = "collected_at"
        case despatchedAt = "despatched_at"
    }
}

struct ActionByInfo: Codable {
    let diagnosisStartedBy: String?
    let diagnosisCompletedBy: String?
    let repairStartedBy: String?
    let repairCompletedBy: String?
    let quoteSentBy: String?
    let markedReadyBy: String?

    enum CodingKeys: String, CodingKey {
        case diagnosisStartedBy = "diagnosis_started_by"
        case diagnosisCompletedBy = "diagnosis_completed_by"
        case repairStartedBy = "repair_started_by"
        case repairCompletedBy = "repair_completed_by"
        case quoteSentBy = "quote_sent_by"
        case markedReadyBy = "marked_ready_by"
    }
}

struct DeviceImage: Codable, Identifiable {
    let id: String
    let imageType: String
    let r2Key: String
    let filename: String?
    let caption: String?
    let sortOrder: Int
    let uploadedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case imageType = "image_type"
        case r2Key = "r2_key"
        case filename, caption
        case sortOrder = "sort_order"
        case uploadedAt = "uploaded_at"
    }
}

struct DeviceAccessory: Codable, Identifiable {
    let id: String
    let accessoryType: String
    let description: String?
    let returnedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accessoryType = "accessory_type"
        case description
        case returnedAt = "returned_at"
        case createdAt = "created_at"
    }
}

struct DevicePart: Codable, Identifiable {
    let id: String
    let partName: String
    let partSku: String?
    let partCost: Double?
    let supplier: String?
    let isOem: Bool
    let warrantyDays: Int?
    let installedAt: Date?
    let installedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case partName = "part_name"
        case partSku = "part_sku"
        case partCost = "part_cost"
        case supplier
        case isOem = "is_oem"
        case warrantyDays = "warranty_days"
        case installedAt = "installed_at"
        case installedBy = "installed_by"
    }
}

struct DeviceLineItem: Codable, Identifiable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Double
    let vatRate: Double
    let lineTotalIncVat: Double

    enum CodingKeys: String, CodingKey {
        case id, description, quantity
        case unitPrice = "unit_price"
        case vatRate = "vat_rate"
        case lineTotalIncVat = "line_total_inc_vat"
    }
}
```

### DeviceListResponse.swift

```swift
struct DeviceListResponse: Codable {
    let data: [DeviceListItem]
    let pagination: Pagination
    let filters: DeviceListFilters
}

struct DeviceListFilters: Codable {
    let deviceTypes: [DeviceTypeInfo]
    let engineers: [EngineerFilterInfo]
    let locations: [LocationInfo]
    let categoryCounts: DeviceCategoryCounts

    enum CodingKeys: String, CodingKey {
        case deviceTypes = "device_types"
        case engineers, locations
        case categoryCounts = "category_counts"
    }
}

struct EngineerFilterInfo: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String

    var name: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct DeviceCategoryCounts: Codable {
    let repair: Int
    let buyback: Int
    let refurb: Int
    let unassigned: Int
}
```

### DeviceUpdateRequest.swift

```swift
struct DeviceUpdateRequest: Codable {
    var brandId: String?
    var modelId: String?
    var customBrand: String?
    var customModel: String?
    var serialNumber: String?
    var imei: String?
    var colour: String?
    var storageCapacity: String?
    var passcode: String?
    var passcodeType: String?
    var findMyStatus: String?
    var conditionGrade: String?
    var customerReportedIssues: String?
    var technicianFoundIssues: String?
    var additionalIssuesFound: String?
    var conditionNotes: String?
    var diagnosisNotes: String?
    var repairNotes: String?
    var technicianNotes: String?
    var dataBackupOffered: Bool?
    var dataBackupAccepted: Bool?
    var dataBackupCompleted: Bool?
    var factoryResetRequired: Bool?
    var factoryResetCompleted: Bool?
    var isUnderWarranty: Bool?
    var warrantyProvider: String?
    var warrantyExpiryDate: String?
    var insuranceClaim: Bool?
    var insuranceReference: String?
    var priority: String?
    var dueDate: String?
    var assignedEngineerId: String?
    var subLocationId: String?
    var deviceTypeId: String?
    var workflowType: String?
    var visualCheck: String?
    var electricalCheck: String?
    var mechanicalCheck: String?
    var damageMatchesReported: Bool?
    var diagnosisConclusion: String?

    enum CodingKeys: String, CodingKey {
        case brandId = "brand_id"
        case modelId = "model_id"
        case customBrand = "custom_brand"
        case customModel = "custom_model"
        case serialNumber = "serial_number"
        case imei, colour
        case storageCapacity = "storage_capacity"
        case passcode
        case passcodeType = "passcode_type"
        case findMyStatus = "find_my_status"
        case conditionGrade = "condition_grade"
        case customerReportedIssues = "customer_reported_issues"
        case technicianFoundIssues = "technician_found_issues"
        case additionalIssuesFound = "additional_issues_found"
        case conditionNotes = "condition_notes"
        case diagnosisNotes = "diagnosis_notes"
        case repairNotes = "repair_notes"
        case technicianNotes = "technician_notes"
        case dataBackupOffered = "data_backup_offered"
        case dataBackupAccepted = "data_backup_accepted"
        case dataBackupCompleted = "data_backup_completed"
        case factoryResetRequired = "factory_reset_required"
        case factoryResetCompleted = "factory_reset_completed"
        case isUnderWarranty = "is_under_warranty"
        case warrantyProvider = "warranty_provider"
        case warrantyExpiryDate = "warranty_expiry_date"
        case insuranceClaim = "insurance_claim"
        case insuranceReference = "insurance_reference"
        case priority
        case dueDate = "due_date"
        case assignedEngineerId = "assigned_engineer_id"
        case subLocationId = "sub_location_id"
        case deviceTypeId = "device_type_id"
        case workflowType = "workflow_type"
        case visualCheck = "visual_check"
        case electricalCheck = "electrical_check"
        case mechanicalCheck = "mechanical_check"
        case damageMatchesReported = "damage_matches_reported"
        case diagnosisConclusion = "diagnosis_conclusion"
    }
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/DeviceListItem.swift` | Device list item model |
| `Core/Models/DeviceDetail.swift` | Full device detail model |
| `Core/Models/DeviceUpdateRequest.swift` | Device update request body |
| `Core/Models/DeviceListResponse.swift` | Device list response with filters |
| `Features/Staff/Devices/DevicesView.swift` | Device list view with filters |
| `Features/Staff/Devices/DevicesViewModel.swift` | Device list data fetching |
| `Features/Staff/Devices/DeviceDetailView.swift` | Device detail view |
| `Features/Staff/Devices/DeviceDetailViewModel.swift` | Device detail data fetching |
| `Features/Staff/Devices/Components/DeviceRow.swift` | Device list row component |
| `Features/Staff/Devices/Components/DeviceStatusBadge.swift` | Status badge component |
| `Features/Staff/Scanner/ScannerView.swift` | Barcode scanner view |
| `Features/Staff/Scanner/ScannerViewModel.swift` | Scanner logic and lookup |

---

## Testing

```bash
# Test device list
curl -s "https://api.repairminder.com/api/devices?page=1&limit=20" \
  -H "Authorization: Bearer TOKEN" | jq

# Test device search (scanner lookup)
curl -s "https://api.repairminder.com/api/devices?search=ABC123" \
  -H "Authorization: Bearer TOKEN" | jq

# Test device detail
curl -s "https://api.repairminder.com/api/orders/ORDER_ID/devices/DEVICE_ID" \
  -H "Authorization: Bearer TOKEN" | jq

# Test device update
curl -s -X PATCH "https://api.repairminder.com/api/orders/ORDER_ID/devices/DEVICE_ID" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"priority": "urgent"}' | jq

# Test with Wrangler
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT id, status, serial_number FROM order_devices LIMIT 5"
```

See `/docs/REFERENCE-test-tokens/CLAUDE.md` for valid tokens.

---

## Verification Checklist

- [ ] Device list loads with pagination
- [ ] Device list filters work (status, engineer, device type, location)
- [ ] Device search by serial/IMEI works
- [ ] Device category counts display correctly (repair/buyback/refurb/unassigned)
- [ ] Device detail loads with all nested objects
- [ ] Device status displays with correct label and color
- [ ] Status workflow transitions are validated
- [ ] Device update saves correctly
- [ ] Scanner view opens camera
- [ ] Scanner successfully looks up device by serial/IMEI
- [ ] Pull-to-refresh works on device list
- [ ] No JSON decode errors in console
- [ ] Empty states display appropriately
