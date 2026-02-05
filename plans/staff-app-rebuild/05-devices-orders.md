# Stage 05: Orders & Clients

## Objective

Implement order list, order detail, client list, and client detail views with full API alignment.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Order list response** - Read `/Volumes/Riki Repos/repairminder/worker/order_handlers.js` and verify:
   - `getOrders()` function return shape
   - Filter options returned in response
   - Nested client, location, assigned_user objects

2. **Order detail response** - Verify the full order object structure including:
   - Items, payments, signatures, refunds arrays
   - Totals calculation fields
   - Dates object structure

3. **Order status** - Confirm status is auto-calculated from device statuses (read-only in iOS)

4. **Client responses** - Read `/Volumes/Riki Repos/repairminder/worker/client_handlers.js` and verify:
   - List vs detail response differences
   - Stats object structure
   - Nested tickets, orders, devices arrays

```bash
# Quick verification commands
grep -n "getOrders\|getOrder" /Volumes/Riki\ Repos/repairminder/worker/order_handlers.js | head -10
grep -n "getClients\|getClient" /Volumes/Riki\ Repos/repairminder/worker/client_handlers.js | head -10
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## API Endpoints

### GET /api/orders

List orders with pagination and filtering.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | Int | Page number (default: 1) |
| `limit` | Int | Items per page (default: 20, max: 100) |
| `status` | String | Comma-separated order statuses |
| `payment_status` | String | Comma-separated: `unpaid`, `partial`, `paid` |
| `location_id` | String | Location UUID or `unset` or `all` |
| `assigned_user_id` | String | User UUID or `unassigned` |
| `device_type_id` | String | Device type UUID or `unassigned` |
| `search` | String | Search order number, client name, email |
| `date_from` | String | Start date (YYYY-MM-DD) |
| `date_to` | String | End date (YYYY-MM-DD) |
| `sort` | String | `created_at`, `updated_at`, `status`, `order_number` |
| `order` | String | `asc` or `desc` (default: desc) |
| `category` | String | `repair`, `device_sale`, `accessory`, `device_purchase` |
| `period` | String | `today`, `yesterday`, `this_week`, `this_month`, `last_month` |
| `date_filter` | String | `created` or `collected` (default: created) |
| `has_refund` | String | `true` to show only orders with refunds |
| `unpaid` | String | `true` to show only orders with balance due |
| `collection_status` | String | `awaiting` for complete orders awaiting collection |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "ticket_id": "uuid",
      "order_number": 12345,
      "client": {
        "id": "uuid",
        "email": "client@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+44..."
      },
      "location": {
        "id": "uuid",
        "name": "Main Store"
      },
      "assigned_user": {
        "id": "uuid",
        "name": "Tech Name"
      },
      "intake_method": "walk_in",
      "status": "in_progress",
      "payment_status": "unpaid",
      "order_total": 150.00,
      "amount_paid": 0.00,
      "balance_due": 150.00,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T14:22:00Z",
      "notes": [
        {
          "body": "Note text",
          "created_at": "...",
          "created_by": "Staff Name",
          "device_id": "uuid or null",
          "device_name": "iPhone 14 or null"
        }
      ]
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 156,
    "total_pages": 8
  },
  "filters": {
    "locations": [{ "id": "uuid", "name": "Location Name" }],
    "users": [{ "id": "uuid", "name": "User Name" }],
    "statuses": ["awaiting_device", "in_progress", "service_complete", "awaiting_collection", "collected_despatched"],
    "payment_statuses": ["unpaid", "partial", "paid"],
    "device_types": [{ "id": "uuid", "name": "iPhone", "slug": "iphone" }]
  }
}
```

---

### GET /api/orders/:id

Get single order with all related data. Supports lookup by UUID or order_number.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_id": "uuid",
    "order_number": 12345,
    "company_id": "uuid",
    "client": {
      "id": "uuid",
      "email": "client@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "phone": "+44...",
      "notes": "Client notes",
      "address_line_1": "123 Street",
      "address_line_2": null,
      "city": "London",
      "county": "Greater London",
      "postcode": "SW1A 1AA",
      "country": "United Kingdom",
      "email_suppressed": false,
      "email_suppressed_at": null,
      "suppression_status": null,
      "suppression_error": null
    },
    "location": {
      "id": "uuid",
      "name": "Main Store",
      "address_line_1": "456 High Street",
      "address_line_2": null,
      "city": "London",
      "postcode": "E1 6AN",
      "phone": "+44..."
    },
    "assigned_user": {
      "id": "uuid",
      "name": "Tech Name"
    },
    "intake_method": "walk_in",
    "status": "in_progress",
    "stored_status": "in_progress",
    "authorisation_type": "email",
    "authorisation_amount": 150.00,
    "authorisation_notes": "Notes about auth",
    "tracking_number": "RM123456789GB",
    "carrier": "Royal Mail",
    "terms_conditions_snapshot": "...",
    "items": [
      {
        "id": "uuid",
        "item_type": "repair",
        "description": "Screen Replacement",
        "quantity": 1,
        "unit_price": 79.99,
        "vat_rate": 20.0,
        "line_total": 79.99,
        "vat_amount": 16.00,
        "line_total_inc_vat": 95.99,
        "device_id": "uuid or null",
        "created_at": "...",
        "authorization_status": "authorized",
        "authorization_round": 1
      }
    ],
    "payments": [
      {
        "id": "uuid",
        "amount": 50.00,
        "payment_method": "card",
        "payment_date": "2024-01-15",
        "notes": "Deposit",
        "recorded_by_name": "Staff Name",
        "created_at": "...",
        "is_deposit": 1,
        "device_id": null,
        "pos_transaction_id": "uuid or null",
        "pos_transaction_status": "completed",
        "card_brand": "visa",
        "card_last_four": "4242",
        "auth_code": "ABC123",
        "is_refundable": true,
        "total_refunded": 0,
        "refundable_amount": 50.00
      }
    ],
    "signatures": [
      {
        "id": "uuid",
        "signature_type": "drop_off",
        "has_signature": true,
        "typed_name": "John Doe",
        "terms_agreed": true,
        "captured_at": "..."
      }
    ],
    "device_signatures": [
      {
        "id": "uuid",
        "device_id": "uuid",
        "device_name": "iPhone 14 Pro",
        "signature_type": "authorization",
        "signature_data": "base64...",
        "action": "authorize",
        "ip_address": "...",
        "user_agent": "...",
        "created_at": "..."
      }
    ],
    "refunds": [
      {
        "id": "uuid",
        "order_payment_id": "uuid",
        "amount": 10.00,
        "refund_date": "2024-01-20",
        "reason": "Partial refund",
        "recorded_by_name": "Staff Name",
        "created_at": "..."
      }
    ],
    "devices": [
      {
        "id": "uuid",
        "status": "repairing",
        "workflow_type": "repair",
        "ready_for_collection_at": null,
        "authorization_status": "authorized",
        "authorization_method": "email",
        "authorized_at": "...",
        "deposits": 50.00,
        "final_paid": 0.00
      }
    ],
    "totals": {
      "subtotal": 79.99,
      "vat_total": 16.00,
      "grand_total": 95.99,
      "deposits_paid": 50.00,
      "final_payments_paid": 0.00,
      "amount_paid": 50.00,
      "total_refunded": 0.00,
      "net_paid": 50.00,
      "balance_due": 45.99
    },
    "payment_status": "partial",
    "dates": {
      "created_at": "...",
      "updated_at": "...",
      "quote_sent_at": "...",
      "authorised_at": "...",
      "rejected_at": null,
      "service_completed_at": null,
      "collected_at": null,
      "despatched_at": null,
      "ready_by_date": null
    },
    "portal_access_disabled": 0,
    "portal_access_expires_at": null,
    "ticket": {
      "id": "uuid",
      "subject": "iPhone 14 Pro - Screen Repair",
      "status": "open",
      "messages": [...],
      "messages_count": 5
    },
    "company": {
      "name": "Repair Shop Ltd",
      "vat_number": "GB123456789",
      "terms_conditions": "...",
      "logo_url": "https://...",
      "vat_rate_repair": 20,
      "vat_rate_device_sale": 0,
      "vat_rate_accessory": 20,
      "vat_rate_device_purchase": 0,
      "portal_access_days_after_collection": 14,
      "deposits_enabled": 1
    }
  }
}
```

---

### PATCH /api/orders/:id

Update order fields. **Note: Status is auto-calculated from device statuses - cannot be set manually.**

**Request Body (all optional):**
```json
{
  "location_id": "uuid",
  "assigned_user_id": "uuid",
  "intake_method": "walk_in|mail_in|courier|counter_sale|accessories_in_store",
  "authorisation_type": "pre_authorised|phone|email|portal",
  "authorisation_amount": 150.00,
  "authorisation_notes": "string",
  "tracking_number": "string",
  "carrier": "Royal Mail|DPD|DHL|UPS|FedEx|Hermes|Yodel|Other",
  "ready_by_date": "2024-01-20",
  "portal_access_expires_at": "2024-02-01T23:59:59Z",
  "portal_access_disabled": true
}
```

---

### GET /api/clients

List clients with pagination and filtering.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | Int | Page number (default: 1) |
| `limit` | Int | Items per page (default: 50, max: 100) |
| `search` | String | Search email, name, phone, group name |
| `group_id` | String | Filter by client group UUID |
| `sort` | String | `created_at`, `updated_at`, `email`, `name`, `first_name`, `last_name` |
| `order` | String | `asc` or `desc` (default: desc) |
| `period` | String | `today`, `yesterday`, `this_week`, `this_month`, `last_month` |
| `new` | String | `true` - clients whose first order is in period |
| `returning` | String | `true` - clients with orders in period who had prior orders |
| `had_orders_in_period` | String | `true` - clients with any order in period |
| `blocked` | String | `true` - show only suppressed/bounced clients |

**Response:**
```json
{
  "success": true,
  "data": {
    "clients": [
      {
        "id": "uuid",
        "email": "client@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+44...",
        "country_code": "GB",
        "client_group_id": "uuid or null",
        "client_group_name": "VIP Customers",
        "groups": [
          { "id": "uuid", "name": "VIP", "group_type": "manual" }
        ],
        "email_suppressed": false,
        "email_suppressed_at": null,
        "is_generated_email": false,
        "marketing_consent": true,
        "suppression_status": null,
        "suppression_error": null,
        "ticket_count": 3,
        "order_count": 5,
        "device_count": 8,
        "total_spend": 450.00,
        "average_spend": 90.00,
        "last_contact_received": "...",
        "last_contact_sent": "...",
        "created_at": "..."
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 234,
      "totalPages": 5
    }
  }
}
```

---

### GET /api/clients/:id

Get single client with full details.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "client@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "name": "John Doe",
    "phone": "+44...",
    "notes": "VIP customer, prefers morning appointments",
    "address_line_1": "123 Street",
    "address_line_2": null,
    "city": "London",
    "county": "Greater London",
    "postcode": "SW1A 1AA",
    "country": "United Kingdom",
    "country_code": "GB",
    "social_facebook": "https://facebook.com/...",
    "social_instagram": "https://instagram.com/...",
    "social_twitter": "https://twitter.com/...",
    "social_linkedin": null,
    "social_tiktok": null,
    "social_youtube": null,
    "social_pinterest": null,
    "social_whatsapp": "+44...",
    "social_snapchat": null,
    "social_threads": null,
    "client_group_id": "uuid",
    "client_group": {
      "id": "uuid",
      "name": "VIP Customers"
    },
    "groups": [
      {
        "id": "uuid",
        "name": "VIP",
        "group_type": "manual",
        "location_id": null,
        "added_at": "...",
        "added_source": "manual"
      }
    ],
    "email_suppressed": false,
    "email_suppressed_at": null,
    "marketing_consent": true,
    "marketing_consent_at": "...",
    "marketing_consent_source": "signup",
    "suppression_status": null,
    "suppression_error": null,
    "created_at": "...",
    "updated_at": "...",
    "deleted_at": null,
    "tickets": [
      {
        "id": "uuid",
        "ticket_number": 12345,
        "subject": "iPhone repair",
        "status": "open",
        "created_at": "..."
      }
    ],
    "orders": [
      {
        "id": "uuid",
        "order_number": 12345,
        "status": "in_progress",
        "total": 150.00,
        "created_at": "..."
      }
    ],
    "devices": [
      {
        "id": "uuid",
        "order_id": "uuid",
        "order_number": 12345,
        "brand_name": "Apple",
        "model_name": "iPhone 14 Pro",
        "custom_brand": null,
        "custom_model": null,
        "serial_number": "ABCD1234",
        "status": "repairing"
      }
    ],
    "stats": {
      "ticket_count": 3,
      "order_count": 5,
      "device_count": 8,
      "total_spend": 450.00,
      "average_spend": 90.00,
      "spend_breakdown": {
        "repair": { "count": 6, "total": 380.00, "average": 63.33 },
        "buyback": { "count": 1, "total": -50.00, "average": -50.00 },
        "accessory": { "count": 3, "total": 45.00, "average": 15.00 },
        "device_sale": { "count": 1, "total": 75.00, "average": 75.00 }
      },
      "last_contact_received": "...",
      "last_contact_sent": "...",
      "avg_authorization_hours": 2.5,
      "authorization_count": 4,
      "avg_rejection_hours": null,
      "rejection_count": 0,
      "avg_collection_hours": 24.3,
      "collection_count": 4
    }
  }
}
```

---

## Constants

### Order Statuses (Auto-calculated from devices)

```swift
enum OrderStatus: String, Codable, CaseIterable {
    case awaitingDevice = "awaiting_device"
    case inProgress = "in_progress"
    case serviceComplete = "service_complete"
    case awaitingCollection = "awaiting_collection"
    case collectedDespatched = "collected_despatched"

    var label: String {
        switch self {
        case .awaitingDevice: return "Awaiting Device"
        case .inProgress: return "In Progress"
        case .serviceComplete: return "Service Complete"
        case .awaitingCollection: return "Awaiting Collection/Despatch"
        case .collectedDespatched: return "Collected/Despatched"
        }
    }
}
```

**Important:** Order status is auto-calculated from device statuses. iOS should NOT set this directly.

### Payment Statuses

```swift
enum PaymentStatus: String, Codable, CaseIterable {
    case unpaid
    case partial
    case paid
    case refunded
}
```

### Intake Methods

```swift
enum IntakeMethod: String, Codable, CaseIterable {
    case walkIn = "walk_in"
    case mailIn = "mail_in"
    case courier
    case counterSale = "counter_sale"
    case accessoriesInStore = "accessories_in_store"
}
```

### Authorisation Types

```swift
enum AuthorisationType: String, Codable, CaseIterable {
    case preAuthorised = "pre_authorised"
    case phone
    case email
    case portal
}
```

### Payment Methods

```swift
enum PaymentMethod: String, Codable, CaseIterable {
    case cash
    case card
    case bankTransfer = "bank_transfer"
    case paypal
    case invoice
    case other
}
```

### Signature Types

```swift
enum SignatureType: String, Codable, CaseIterable {
    case dropOff = "drop_off"
    case collection
    case authorization
}
```

### Item Types

```swift
enum OrderItemType: String, Codable, CaseIterable {
    case repair
    case deviceSale = "device_sale"
    case accessory
    case devicePurchase = "device_purchase"
}
```

### Carriers

```swift
enum Carrier: String, Codable, CaseIterable {
    case royalMail = "Royal Mail"
    case dpd = "DPD"
    case dhl = "DHL"
    case ups = "UPS"
    case fedEx = "FedEx"
    case hermes = "Hermes"
    case yodel = "Yodel"
    case other = "Other"
}
```

---

## Swift Models

### Order.swift

```swift
struct Order: Codable, Identifiable {
    let id: String
    let ticketId: String
    let orderNumber: Int
    let companyId: String?

    // Nested objects
    let client: OrderClient?
    let location: OrderLocation?
    let assignedUser: AssignedUser?

    // Order settings
    let intakeMethod: IntakeMethod?
    let status: OrderStatus
    let storedStatus: OrderStatus?
    let authorisationType: AuthorisationType?
    let authorisationAmount: Double?
    let authorisationNotes: String?
    let trackingNumber: String?
    let carrier: Carrier?
    let termsConditionsSnapshot: String?

    // Line items, payments, etc.
    let items: [OrderItem]?
    let payments: [OrderPayment]?
    let signatures: [OrderSignature]?
    let deviceSignatures: [DeviceSignature]?
    let refunds: [OrderRefund]?
    let devices: [OrderDeviceSummary]?

    // Totals
    let totals: OrderTotals?
    let paymentStatus: PaymentStatus?

    // Dates
    let dates: OrderDates?

    // Portal access
    let portalAccessDisabled: Int?
    let portalAccessExpiresAt: String?

    // Related data
    let ticket: OrderTicket?
    let company: OrderCompany?

    // List view properties (denormalized)
    let orderTotal: Double?
    let amountPaid: Double?
    let balanceDue: Double?
    let createdAt: String?
    let updatedAt: String?
    let notes: [OrderNote]?
}
```

### Client.swift

```swift
struct Client: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let name: String?
    let phone: String?
    let notes: String?
    let countryCode: String?

    // Address
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let county: String?
    let postcode: String?
    let country: String?

    // Social media
    let socialFacebook: String?
    let socialInstagram: String?
    let socialTwitter: String?
    let socialLinkedin: String?
    let socialTiktok: String?
    let socialYoutube: String?
    let socialPinterest: String?
    let socialWhatsapp: String?
    let socialSnapchat: String?
    let socialThreads: String?

    // Groups
    let clientGroupId: String?
    let clientGroup: ClientGroup?
    let groups: [ClientGroupMembership]?

    // Email status
    let emailSuppressed: Bool?
    let emailSuppressedAt: String?
    let isGeneratedEmail: Bool?
    let marketingConsent: Bool?
    let marketingConsentAt: String?
    let marketingConsentSource: String?
    let suppressionStatus: String?
    let suppressionError: String?

    // Timestamps
    let createdAt: String?
    let updatedAt: String?
    let deletedAt: String?

    // Detail view arrays
    let tickets: [ClientTicket]?
    let orders: [ClientOrder]?
    let devices: [ClientDevice]?

    // Stats
    let stats: ClientStats?

    // List view stats (denormalized)
    let ticketCount: Int?
    let orderCount: Int?
    let deviceCount: Int?
    let totalSpend: Double?
    let averageSpend: Double?
    let lastContactReceived: String?
    let lastContactSent: String?
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/Order.swift` | Order model with all nested types |
| `Core/Models/OrderStatus.swift` | Order status enum with labels |
| `Core/Models/Client.swift` | Client model with nested types |
| `Core/Models/OrderEnums.swift` | Shared enums (IntakeMethod, PaymentStatus, etc.) |
| `Core/Services/OrderService.swift` | Order API service |
| `Core/Services/ClientService.swift` | Client API service |
| `Features/Staff/Orders/OrderListView.swift` | Order list UI |
| `Features/Staff/Orders/OrderListViewModel.swift` | Order list logic |
| `Features/Staff/Orders/OrderDetailView.swift` | Order detail UI |
| `Features/Staff/Orders/OrderDetailViewModel.swift` | Order detail logic |
| `Features/Staff/Clients/ClientListView.swift` | Client list UI |
| `Features/Staff/Clients/ClientListViewModel.swift` | Client list logic |
| `Features/Staff/Clients/ClientDetailView.swift` | Client detail UI |
| `Features/Staff/Clients/ClientDetailViewModel.swift` | Client detail logic |

---

## Testing

**Query orders with Wrangler:**
```bash
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT id, order_number, status FROM orders WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' LIMIT 5"
```

**Test with curl:**
```bash
# List orders
curl "https://api.repairminder.co.uk/api/orders?page=1&limit=20" \
  -H "Authorization: Bearer {token}" | jq .

# Get order by ID
curl "https://api.repairminder.co.uk/api/orders/{order_id}" \
  -H "Authorization: Bearer {token}" | jq .

# Get order by number
curl "https://api.repairminder.co.uk/api/orders/12345" \
  -H "Authorization: Bearer {token}" | jq .

# Update order
curl -X PATCH "https://api.repairminder.co.uk/api/orders/{order_id}" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"assigned_user_id": "uuid"}' | jq .

# List clients
curl "https://api.repairminder.co.uk/api/clients?page=1&limit=50&search=john" \
  -H "Authorization: Bearer {token}" | jq .

# Get client detail
curl "https://api.repairminder.co.uk/api/clients/{client_id}" \
  -H "Authorization: Bearer {token}" | jq .
```

---

## Verification Checklist

- [ ] Order list loads with pagination
- [ ] Order list filters work (status, payment_status, location, assigned_user)
- [ ] Order list search works (order number, client name/email)
- [ ] Order detail shows all sections (client, devices, payments, signatures, totals)
- [ ] Order totals calculate correctly (subtotal, VAT, grand_total, balance_due)
- [ ] Order dates display correctly (quote_sent_at, authorised_at, etc.)
- [ ] Order update works for allowed fields
- [ ] Client list loads with pagination
- [ ] Client list search works
- [ ] Client detail shows orders, tickets, devices
- [ ] Client stats display correctly (spend breakdown, timing metrics)
- [ ] No decode errors for any response
