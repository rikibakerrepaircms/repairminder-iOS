# Stage 08: Customer Screens

## Objective

Build customer-facing screens: order list, order detail with timeline, quote approval flow, and messaging. The iOS app should replicate the customer portal experience from the web app.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Customer order endpoints** - Search for `/api/customer/` routes in `/Volumes/Riki Repos/repairminder/worker/index.js` and verify:
   - Order list response shape
   - Order detail response (devices, items, messages, company)
   - What fields are excluded for customers (e.g., internal notes)

2. **Approval endpoint** - Read `/Volumes/Riki Repos/repairminder/worker/authorization_handlers.js` and verify:
   - Request body structure (action, signature_type, signature_data)
   - Buyback bank details requirements
   - Error conditions (already approved, not yet quoted, etc.)

3. **Customer progress stages** - Compare with web app's `CustomerProgressBar` component to ensure stage mappings match

4. **Device authorization** - Verify per-device vs per-order authorization flow

```bash
# Quick verification commands
grep -n "/api/customer" /Volumes/Riki\ Repos/repairminder/worker/index.js | head -20
grep -n "approveQuote\|rejectQuote" /Volumes/Riki\ Repos/repairminder/worker/authorization_handlers.js
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## API Endpoints

### GET /api/customer/orders

Returns customer's order list (scoped to authenticated customer).

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "ticket_number": 12345,
      "status": "awaiting_authorisation",
      "created_at": "2024-01-15T10:30:00Z",
      "quote_sent_at": "2024-01-16T14:00:00Z",
      "quote_approved_at": null,
      "rejected_at": null,
      "updated_at": "2024-01-16T14:00:00Z",
      "devices": [
        {
          "id": "uuid",
          "status": "awaiting_authorisation",
          "display_name": "Apple iPhone 14 Pro"
        }
      ],
      "totals": {
        "subtotal": 105.98,
        "vat_total": 21.20,
        "grand_total": 127.18
      }
    }
  ],
  "currency_code": "GBP"
}
```

**Error Conditions:**
- `403` if order-scoped token tries to list all orders (returns `requiresLogin: true`)

---

### GET /api/customer/orders/:orderId

Returns full order detail with devices, items, messages, and company info.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_number": 12345,
    "status": "awaiting_authorisation",
    "created_at": "2024-01-15T10:30:00Z",
    "collected_at": null,
    "quote_sent_at": "2024-01-16T14:00:00Z",
    "quote_approved_at": null,
    "quote_approved_method": null,
    "rejected_at": null,

    "pre_authorization": {
      "amount": 200.00,
      "notes": "Up to £200 pre-approved",
      "authorised_at": "2024-01-15T10:30:00Z",
      "authorised_by": {
        "first_name": "John",
        "last_name": "Staff"
      },
      "signature": {
        "id": "uuid",
        "type": "drawn",
        "data": "data:image/png;base64,...",
        "typed_name": null,
        "captured_at": "2024-01-15T10:30:00Z"
      }
    },

    "review_links": {
      "google": "https://search.google.com/local/writereview?placeid=...",
      "facebook": "https://facebook.com/company/reviews",
      "trustpilot": "https://trustpilot.com/review/company",
      "yelp": null,
      "apple": null
    },

    "devices": [
      {
        "id": "uuid",
        "display_name": "Apple iPhone 14 Pro",
        "status": "awaiting_authorisation",
        "workflow_type": "repair",
        "customer_reported_issues": "Cracked screen, battery drains fast",
        "serial_number": "FVFXC123456",
        "imei": "123456789012345",

        "visual_check": "Screen cracked in multiple places",
        "electrical_check": "Battery health at 72%",
        "mechanical_check": "All buttons functional",
        "damage_matches_reported": "Yes, damage consistent with drop",
        "diagnosis_conclusion": "Screen replacement + battery recommended",

        "authorization_status": "pending",
        "authorization_method": null,
        "authorized_at": null,
        "auth_ip_address": null,
        "auth_user_agent": null,
        "auth_signature_type": null,
        "auth_signature_data": null,
        "authorization_reason": null,

        "collection_location": {
          "id": "uuid",
          "name": "Main Store",
          "address": "123 High Street, London, SW1A 1AA",
          "address_line_1": "123 High Street",
          "address_line_2": null,
          "city": "London",
          "county": null,
          "postcode": "SW1A 1AA",
          "phone": "020 1234 5678",
          "email": "store@example.com",
          "google_maps_url": "https://www.google.com/maps/place/?q=place_id:...",
          "apple_maps_url": "https://maps.apple.com/?...",
          "opening_hours": {
            "monday": { "open": "09:00", "close": "17:30" },
            "tuesday": { "open": "09:00", "close": "17:30" },
            "wednesday": { "open": "09:00", "close": "17:30" },
            "thursday": { "open": "09:00", "close": "17:30" },
            "friday": { "open": "09:00", "close": "17:30" },
            "saturday": { "open": "10:00", "close": "16:00" },
            "sunday": null
          }
        },

        "deposit_paid": 50.00,

        "images": [
          {
            "id": "uuid",
            "image_type": "pre_repair",
            "url": "https://api.repairminder.com/api/customer/devices/{id}/images/{id}/file",
            "filename": "crack_photo.jpg",
            "caption": "Front screen damage",
            "uploaded_at": "2024-01-15T10:35:00Z"
          }
        ],

        "pre_repair_checklist": {
          "id": "uuid",
          "template_name": "iPhone Pre-Repair",
          "results": {
            "groups": {
              "Display": {
                "touch_response": { "status": "pass", "notes": null },
                "lcd_bleeding": { "status": "fail", "notes": "Minor bleeding top left" }
              },
              "Audio": {
                "speaker": { "status": "pass", "notes": null },
                "microphone": { "status": "pass", "notes": null }
              }
            }
          },
          "completed_at": "2024-01-15T11:00:00Z",
          "completed_by_name": "Tech Name"
        },

        "payout_amount": null,
        "payout_method": null,
        "payout_date": null,
        "paid_at": null,
        "payment": null
      }
    ],

    "items": [
      {
        "id": "uuid",
        "description": "iPhone 14 Pro Screen Replacement",
        "quantity": 1,
        "unit_price": 89.99,
        "vat_rate": 0.20,
        "line_total": 89.99,
        "vat_amount": 18.00,
        "line_total_inc_vat": 107.99,
        "device_id": "uuid",
        "authorization_status": "pending",
        "signature_id": null,
        "authorized_price": null
      },
      {
        "id": "uuid",
        "description": "Battery Replacement",
        "quantity": 1,
        "unit_price": 15.99,
        "vat_rate": 0.20,
        "line_total": 15.99,
        "vat_amount": 3.20,
        "line_total_inc_vat": 19.19,
        "device_id": "uuid",
        "authorization_status": "pending",
        "signature_id": null,
        "authorized_price": null
      }
    ],

    "totals": {
      "subtotal": 105.98,
      "vat_total": 21.20,
      "grand_total": 127.18,
      "deposits_paid": 50.00,
      "final_payments_paid": 0,
      "amount_paid": 50.00,
      "balance_due": 77.18
    },

    "messages": [
      {
        "id": "uuid",
        "type": "outbound",
        "subject": "Quote for Order #12345",
        "body_text": "Please find attached your quote...",
        "created_at": "2024-01-16T14:00:00Z"
      }
    ],

    "company": {
      "name": "Phone Repairs Ltd",
      "phone": "020 1234 5678",
      "email": "hello@phonerepairs.com",
      "logo_url": "https://api.repairminder.com/api/branding/{id}/logo",
      "currency_code": "GBP",
      "terms_conditions": "Standard terms and conditions...",
      "collection_storage_fee_enabled": true,
      "collection_recycling_enabled": true,
      "collection_storage_fee_daily": 5,
      "collection_storage_fee_cap": 150
    }
  }
}
```

**Note:** Messages exclude internal notes (`type != 'note'`).

---

### POST /api/customer/orders/:orderId/approve

Approve or reject a quote. Requires signature for approval.

**Approve with Typed Signature:**
```json
{
  "action": "approve",
  "signature_type": "typed",
  "signature_data": "John Smith",
  "amount_acknowledged": 127.18
}
```

**Approve with Drawn Signature:**
```json
{
  "action": "approve",
  "signature_type": "drawn",
  "signature_data": "data:image/png;base64,...",
  "amount_acknowledged": 127.18
}
```

**Reject Quote:**
```json
{
  "action": "reject",
  "rejection_reason": "Price too high"
}
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "message": "Quote approved successfully",
    "approved_at": "2024-01-17T09:00:00Z",
    "signature_id": "uuid"
  }
}
```

**Error Conditions:**
| Status | Condition |
|--------|-----------|
| `400` | `quote_sent_at` is null (quote not yet sent) |
| `400` | Already approved (`quote_approved_at` not null) |
| `400` | Already rejected (`rejected_at` not null) |
| `400` | Invalid action (must be "approve" or "reject") |
| `400` | Invalid signature type (must be "typed" or "drawn") |
| `400` | Missing signature data |
| `404` | Order doesn't belong to customer |

---

### POST /api/customer/devices/:deviceId/authorize

Per-device authorization (used for per-device workflow and buyback with bank details).

**Approve Repair:**
```json
{
  "action": "approve",
  "signature_type": "typed",
  "signature_data": "John Smith"
}
```

**Approve Buyback (requires bank details):**
```json
{
  "action": "approve",
  "signature_type": "typed",
  "signature_data": "John Smith",
  "bank_details": {
    "account_holder": "John Smith",
    "sort_code": "123456",
    "account_number": "12345678"
  }
}
```

**Reject:**
```json
{
  "action": "reject",
  "signature_type": "typed",
  "signature_data": null
}
```

---

### POST /api/customer/orders/:orderId/reply

Send a message from the customer portal.

**Request:**
```json
{
  "message": "When will my device be ready?",
  "device_id": "uuid"
}
```

`device_id` is optional - use for device-specific messages.

**Response:**
```json
{
  "success": true,
  "data": {
    "message_id": "uuid",
    "created_at": "2024-01-17T10:00:00Z"
  }
}
```

---

### GET /api/customer/orders/:orderId/invoice

Returns HTML invoice for download/print.

**Response:** `text/html` content with `Content-Disposition: attachment`

---

### GET /api/customer/devices/:deviceId/images/:imageId/file

Returns device image file (authenticated endpoint).

**Response:** Image binary with appropriate `Content-Type`

---

## Customer JWT Structure

Customer tokens are separate from staff tokens.

**Full Portal Access:**
```json
{
  "type": "customer",
  "clientId": "uuid",
  "companyId": "uuid",
  "email": "customer@example.com",
  "scope": "customer_portal"
}
```

**Order-Scoped Access (from magic link):**
```json
{
  "type": "customer_order",
  "clientId": "uuid",
  "companyId": "uuid",
  "orderId": "uuid",
  "scope": "order_access"
}
```

Order-scoped tokens can only access the specific order, not the full order list.

---

## Device Status Progress Timeline

> **🔄 DYNAMIC CONFIGURATION PENDING:** Customer-facing status labels and stage mappings should eventually be fetched from a `/api/config` endpoint. For now, these mappings mirror the web app's `CustomerProgressBar` component. Verify against the web app source before implementing.

### Repair Workflow Stages

| Stage | Internal Statuses | Customer Label | Description |
|-------|-------------------|----------------|-------------|
| 1 | `device_received` | Received | We have your device |
| 2 | `diagnosing` | Being Assessed | Our technicians are checking your device |
| 3 | `ready_to_quote`, `awaiting_authorisation` | Quote Ready | Please review and approve |
| 4 | `authorised_source_parts`, `authorised_awaiting_parts`, `ready_to_repair`, `repairing` | In Repair | Work is in progress |
| 5 | `repaired_qc` | Quality Check | Final checks in progress |
| 6 | `repaired_ready` | Ready | Ready for collection |
| 7 | `collected`, `despatched` | Complete | All done! |

### Buyback Workflow Stages

| Stage | Internal Statuses | Customer Label | Description |
|-------|-------------------|----------------|-------------|
| 1 | `device_received` | Received | We have your device |
| 2 | `diagnosing` | Being Assessed | Evaluating your device |
| 3 | `ready_to_quote`, `awaiting_authorisation` | Offer Ready | Please review our offer |
| 4 | `ready_to_pay` | Processing Payment | Preparing your payment |
| 5 | `payment_made` | Paid | Payment has been sent |

### Special Statuses (Non-Linear)

| Status | Customer Display | Description |
|--------|------------------|-------------|
| `rejected` | Quote/Offer Declined | Contact us to arrange collection |
| `company_rejected` | Assessment Failed | Buyback cannot proceed |
| `rejection_qc` | Preparing Return | Device being prepared for return |
| `rejection_ready` | Ready for Collection | Device ready, visit to collect |

---

## Swift Models

### CustomerOrder.swift

```swift
// CustomerOrderSummary - for list view
struct CustomerOrderSummary: Codable, Identifiable {
    let id: String
    let ticketNumber: Int
    let status: String
    let createdAt: Date
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let rejectedAt: Date?
    let updatedAt: Date?
    let devices: [CustomerDeviceSummary]
    let totals: CustomerOrderTotals

    enum CodingKeys: String, CodingKey {
        case id
        case ticketNumber = "ticket_number"
        case status
        case createdAt = "created_at"
        case quoteSentAt = "quote_sent_at"
        case quoteApprovedAt = "quote_approved_at"
        case rejectedAt = "rejected_at"
        case updatedAt = "updated_at"
        case devices, totals
    }
}

struct CustomerDeviceSummary: Codable, Identifiable {
    let id: String
    let status: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case displayName = "display_name"
    }
}

struct CustomerOrderTotals: Codable {
    let subtotal: Decimal
    let vatTotal: Decimal
    let grandTotal: Decimal
    let depositsPaid: Decimal?
    let finalPaymentsPaid: Decimal?
    let amountPaid: Decimal?
    let balanceDue: Decimal?

    enum CodingKeys: String, CodingKey {
        case subtotal
        case vatTotal = "vat_total"
        case grandTotal = "grand_total"
        case depositsPaid = "deposits_paid"
        case finalPaymentsPaid = "final_payments_paid"
        case amountPaid = "amount_paid"
        case balanceDue = "balance_due"
    }
}
```

### CustomerOrderDetail.swift

```swift
struct CustomerOrderDetail: Codable, Identifiable {
    let id: String
    let ticketNumber: Int
    let status: String
    let createdAt: Date
    let collectedAt: Date?
    let quoteSentAt: Date?
    let quoteApprovedAt: Date?
    let quoteApprovedMethod: String?
    let rejectedAt: Date?
    let preAuthorization: PreAuthorization?
    let reviewLinks: ReviewLinks?
    let devices: [CustomerDevice]
    let items: [CustomerOrderItem]
    let totals: CustomerOrderTotals
    let messages: [CustomerMessage]
    let company: CustomerCompanyInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case ticketNumber = "ticket_number"
        case status
        case createdAt = "created_at"
        case collectedAt = "collected_at"
        case quoteSentAt = "quote_sent_at"
        case quoteApprovedAt = "quote_approved_at"
        case quoteApprovedMethod = "quote_approved_method"
        case rejectedAt = "rejected_at"
        case preAuthorization = "pre_authorization"
        case reviewLinks = "review_links"
        case devices, items, totals, messages, company
    }
}

struct PreAuthorization: Codable {
    let amount: Decimal
    let notes: String?
    let authorisedAt: Date
    let authorisedBy: AuthorisedBy?
    let signature: PreAuthSignature?

    enum CodingKeys: String, CodingKey {
        case amount, notes
        case authorisedAt = "authorised_at"
        case authorisedBy = "authorised_by"
        case signature
    }
}

struct AuthorisedBy: Codable {
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct PreAuthSignature: Codable {
    let id: String
    let type: String  // "typed" or "drawn"
    let data: String?
    let typedName: String?
    let capturedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, data
        case typedName = "typed_name"
        case capturedAt = "captured_at"
    }
}

struct ReviewLinks: Codable {
    let google: String?
    let facebook: String?
    let trustpilot: String?
    let yelp: String?
    let apple: String?
}
```

### CustomerDevice.swift

```swift
struct CustomerDevice: Codable, Identifiable {
    let id: String
    let displayName: String
    let status: String
    let workflowType: WorkflowType
    let customerReportedIssues: String?
    let serialNumber: String?
    let imei: String?

    // Diagnostic assessment
    let visualCheck: String?
    let electricalCheck: String?
    let mechanicalCheck: String?
    let damageMatchesReported: String?
    let diagnosisConclusion: String?

    // Authorization
    let authorizationStatus: String?
    let authorizationMethod: String?
    let authorizedAt: Date?
    let authIpAddress: String?
    let authUserAgent: String?
    let authSignatureType: String?
    let authSignatureData: String?
    let authorizationReason: String?

    // Collection location
    let collectionLocation: CollectionLocation?

    // Payment info
    let depositPaid: Decimal?
    let payoutAmount: Decimal?
    let payoutMethod: String?
    let payoutDate: String?
    let paidAt: Date?
    let payment: DevicePayment?

    // Images and checklist
    let images: [DeviceImage]?
    let preRepairChecklist: PreRepairChecklist?

    enum WorkflowType: String, Codable {
        case repair
        case buyback
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case status
        case workflowType = "workflow_type"
        case customerReportedIssues = "customer_reported_issues"
        case serialNumber = "serial_number"
        case imei
        case visualCheck = "visual_check"
        case electricalCheck = "electrical_check"
        case mechanicalCheck = "mechanical_check"
        case damageMatchesReported = "damage_matches_reported"
        case diagnosisConclusion = "diagnosis_conclusion"
        case authorizationStatus = "authorization_status"
        case authorizationMethod = "authorization_method"
        case authorizedAt = "authorized_at"
        case authIpAddress = "auth_ip_address"
        case authUserAgent = "auth_user_agent"
        case authSignatureType = "auth_signature_type"
        case authSignatureData = "auth_signature_data"
        case authorizationReason = "authorization_reason"
        case collectionLocation = "collection_location"
        case depositPaid = "deposit_paid"
        case payoutAmount = "payout_amount"
        case payoutMethod = "payout_method"
        case payoutDate = "payout_date"
        case paidAt = "paid_at"
        case payment
        case images
        case preRepairChecklist = "pre_repair_checklist"
    }
}

struct CollectionLocation: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let phone: String?
    let email: String?
    let googleMapsUrl: String?
    let appleMapsUrl: String?
    let openingHours: OpeningHours?

    enum CodingKeys: String, CodingKey {
        case id, name, address
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case city, county, postcode, phone, email
        case googleMapsUrl = "google_maps_url"
        case appleMapsUrl = "apple_maps_url"
        case openingHours = "opening_hours"
    }
}

struct OpeningHours: Codable {
    let monday: DayHours?
    let tuesday: DayHours?
    let wednesday: DayHours?
    let thursday: DayHours?
    let friday: DayHours?
    let saturday: DayHours?
    let sunday: DayHours?
}

struct DayHours: Codable {
    let open: String
    let close: String
}

struct DeviceImage: Codable, Identifiable {
    let id: String
    let imageType: String
    let url: String
    let filename: String
    let caption: String?
    let uploadedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case imageType = "image_type"
        case url, filename, caption
        case uploadedAt = "uploaded_at"
    }
}

struct DevicePayment: Codable {
    let method: String
    let notes: String?
    let date: String
    let amount: Decimal
}

struct PreRepairChecklist: Codable {
    let id: String
    let templateName: String
    let results: ChecklistResults
    let completedAt: Date
    let completedByName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case templateName = "template_name"
        case results
        case completedAt = "completed_at"
        case completedByName = "completed_by_name"
    }
}

// Checklist results can be grouped or flat array
enum ChecklistResults: Codable {
    case grouped(groups: [String: [String: ChecklistItem]])
    case flat([FlatChecklistItem])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let grouped = try? container.decode(GroupedResults.self) {
            self = .grouped(groups: grouped.groups)
        } else if let flat = try? container.decode([FlatChecklistItem].self) {
            self = .flat(flat)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown format")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .grouped(let groups):
            try container.encode(GroupedResults(groups: groups))
        case .flat(let items):
            try container.encode(items)
        }
    }
}

struct GroupedResults: Codable {
    let groups: [String: [String: ChecklistItem]]
}

struct ChecklistItem: Codable {
    let status: String  // "pass", "fail", "omit", "not_tested", "not_applicable"
    let notes: String?
}

struct FlatChecklistItem: Codable {
    let name: String
    let status: String
    let notes: String?
}
```

### CustomerOrderItem.swift

```swift
struct CustomerOrderItem: Codable, Identifiable {
    let id: String
    let description: String
    let quantity: Int
    let unitPrice: Decimal
    let vatRate: Decimal
    let lineTotal: Decimal
    let vatAmount: Decimal
    let lineTotalIncVat: Decimal
    let deviceId: String?
    let authorizationStatus: String
    let signatureId: String?
    let authorizedPrice: Decimal?

    enum CodingKeys: String, CodingKey {
        case id, description, quantity
        case unitPrice = "unit_price"
        case vatRate = "vat_rate"
        case lineTotal = "line_total"
        case vatAmount = "vat_amount"
        case lineTotalIncVat = "line_total_inc_vat"
        case deviceId = "device_id"
        case authorizationStatus = "authorization_status"
        case signatureId = "signature_id"
        case authorizedPrice = "authorized_price"
    }
}
```

### CustomerMessage.swift

```swift
struct CustomerMessage: Codable, Identifiable {
    let id: String
    let type: String  // "outbound", "inbound" (excludes "note")
    let subject: String?
    let bodyText: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, subject
        case bodyText = "body_text"
        case createdAt = "created_at"
    }
}
```

### CustomerCompanyInfo.swift

```swift
struct CustomerCompanyInfo: Codable {
    let name: String
    let phone: String?
    let email: String?
    let logoUrl: String?
    let currencyCode: String?
    let termsConditions: String?
    let collectionStorageFeeEnabled: Bool?
    let collectionRecyclingEnabled: Bool?
    let collectionStorageFeeDaily: Decimal?
    let collectionStorageFeeCap: Decimal?

    enum CodingKeys: String, CodingKey {
        case name, phone, email
        case logoUrl = "logo_url"
        case currencyCode = "currency_code"
        case termsConditions = "terms_conditions"
        case collectionStorageFeeEnabled = "collection_storage_fee_enabled"
        case collectionRecyclingEnabled = "collection_recycling_enabled"
        case collectionStorageFeeDaily = "collection_storage_fee_daily"
        case collectionStorageFeeCap = "collection_storage_fee_cap"
    }
}
```

---

## UI Components

### CustomerProgressBar

A visual timeline showing order progress. Replicate the web app's `CustomerProgressBar` component:

- Horizontal progress bar with numbered stage indicators
- Completed stages show checkmark icon
- Current stage is highlighted with blue ring
- Pending stages show gray numbers
- Current stage description shown below in blue banner

**Implementation Notes:**
- Use `device.status` and `device.workflowType` to determine current stage
- Map internal statuses to customer-facing stages per tables above
- Handle special statuses (rejected, rejection_ready, etc.) with dedicated displays

### CustomerDeviceCard

Card component for each device showing:
1. Device header (icon, name, workflow badge, serial number)
2. Progress timeline (CustomerProgressBar)
3. Authorization status banner (if approved)
4. Collection location details (if ready for collection)
5. Payment complete banner (for buyback)
6. Technical report (when awaiting authorization):
   - Pre-repair assessment
   - Damage assessment
   - Electrical/mechanical checks
   - Diagnosis conclusion
   - Pre-repair checklist results
7. Device images gallery (when awaiting authorization)
8. Quote/offer details with line items
9. Approve button (when awaiting authorization)
10. Customer reported issues

### CustomerApprovalModal

Multi-step approval flow:
1. **Review Step**: Show quote/offer details, Approve/Decline buttons
2. **Bank Details Step** (buyback only): Collect account holder, sort code, account number
3. **Signature Step**: Type name or draw signature
4. **Confirm Reject Step**: Confirmation before declining

### CustomerMessageList

Display messages (excluding internal notes):
- Company logo/favicon as avatar for outbound messages
- Customer initial as avatar for inbound messages
- Subject line if present
- Message body
- Timestamp

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/CustomerOrder.swift` | Order list summary model |
| `Core/Models/CustomerOrderDetail.swift` | Full order detail model |
| `Core/Models/CustomerDevice.swift` | Device with all diagnostic/auth fields |
| `Core/Models/CustomerOrderItem.swift` | Line item model |
| `Core/Models/CustomerMessage.swift` | Message model |
| `Core/Models/CustomerCompanyInfo.swift` | Company info model |
| `Core/Services/CustomerAPIClient.swift` | API client for customer endpoints |
| `Customer/Orders/CustomerOrderListView.swift` | Order list screen |
| `Customer/Orders/CustomerOrderListViewModel.swift` | Order list logic |
| `Customer/Orders/CustomerOrderDetailView.swift` | Order detail screen |
| `Customer/Orders/CustomerOrderDetailViewModel.swift` | Order detail logic |
| `Customer/Components/CustomerProgressBar.swift` | Timeline component |
| `Customer/Components/CustomerDeviceCard.swift` | Device card component |
| `Customer/Components/CustomerApprovalSheet.swift` | Approval flow sheet |
| `Customer/Components/CustomerSignatureView.swift` | Signature capture |
| `Customer/Components/CustomerMessageList.swift` | Message display |
| `Customer/Components/CustomerImageGallery.swift` | Device images gallery |
| `Customer/Components/BankDetailsForm.swift` | Bank details input (buyback) |

---

## Testing

### Generate Customer Token

```bash
# Get magic link code from database
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT magic_link_code FROM clients WHERE email = 'rikibaker+customer@gmail.com'"
```

### Test API Endpoints

```bash
# List orders
curl https://api.repairminder.com/api/customer/orders \
  -H "Authorization: Bearer {customer_token}" | jq .

# Get order detail
curl https://api.repairminder.com/api/customer/orders/{orderId} \
  -H "Authorization: Bearer {customer_token}" | jq .

# Approve quote
curl -X POST https://api.repairminder.com/api/customer/orders/{orderId}/approve \
  -H "Authorization: Bearer {customer_token}" \
  -H "Content-Type: application/json" \
  -d '{"action":"approve","signature_type":"typed","signature_data":"Test User","amount_acknowledged":127.18}'

# Send message
curl -X POST https://api.repairminder.com/api/customer/orders/{orderId}/reply \
  -H "Authorization: Bearer {customer_token}" \
  -H "Content-Type: application/json" \
  -d '{"message":"Test message from iOS app"}'
```

---

## Verification Checklist

- [ ] Customer can view order list with status badges
- [ ] Order detail shows timeline progression correctly
- [ ] Repair workflow stages display correctly
- [ ] Buyback workflow stages display correctly
- [ ] Special statuses (rejected, rejection_ready) handled
- [ ] Pre-authorization banner displays correctly
- [ ] Technical report shows diagnostic details
- [ ] Device images load and display
- [ ] Pre-repair checklist displays (grouped and flat formats)
- [ ] Quote approval with typed signature works
- [ ] Quote approval with drawn signature works
- [ ] Quote rejection works
- [ ] Buyback approval collects bank details
- [ ] Messages display correctly (no internal notes)
- [ ] Reply to order sends message
- [ ] Collection location with opening hours displays
- [ ] Review links show when order completed
- [ ] Invoice download works
- [ ] Currency formatting uses company currency_code
- [ ] Order-scoped tokens can only access allowed order
- [ ] No JSON decode errors
