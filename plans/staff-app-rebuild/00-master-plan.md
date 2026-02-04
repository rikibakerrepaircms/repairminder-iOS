# iOS Unified App Rebuild - Master Plan

## Feature Overview

### What
Complete rebuild of the iOS app as a **single unified app target** supporting both **Staff** and **Customer** roles using an **API-first methodology**. Users select their role at login, and the app shows the appropriate interface:
- **Staff**: Dashboard, devices, orders, enquiries, settings
- **Customer**: Order list, order detail with quote approval, messaging

### Why
The original iOS app was built without verifying backend API endpoints, causing:
- JSON decoding failures ("Failed to decode response")
- Features that silently fail or show no data
- Endpoints calling paths that don't exist
- Request/response format mismatches with snake_case vs camelCase

Additionally, having separate Staff and Customer app targets created unnecessary duplication. A unified app:
- **Single app target** - `Repair Minder` handles both roles
- Shares models, networking, and components
- Single App Store presence
- Simpler maintenance and deployment
- Backend already supports both auth flows

This rebuild documents all endpoints first, then builds Swift models and UI that match the backend exactly.

---

## Backend Reference (Source of Truth)

All iOS implementation should match the backend at `/Volumes/Riki Repos/repairminder/worker/`

### Backend Handlers by Feature

| Feature | Backend Handler | Key Endpoints |
|---------|-----------------|---------------|
| **Dashboard** | `dashboard_handlers.js` | `GET /api/dashboard/stats`, `GET /api/dashboard/enquiry-stats` |
| **My Queue** | `device_handlers.js` | `GET /api/devices/my-queue`, `GET /api/devices/my-active-work` |
| **Devices** | `device_handlers.js` | `GET /api/devices`, `GET /api/devices/:id`, `PATCH /api/devices/:id` |
| **Orders** | `order_handlers.js` | `GET /api/orders`, `GET /api/orders/:id`, `PATCH /api/orders/:id` |
| **Clients** | `client_handlers.js` | `GET /api/clients`, `GET /api/clients/:id`, `GET /api/clients/search` |
| **Enquiries** | `ticket_handlers.js`, `ticket_llm_handlers.js`, `macro_execution_handlers.js` | `GET/PATCH /api/tickets`, `POST .../reply`, `POST .../note`, `POST .../generate-response`, `POST .../macro` |
| **Auth** | `auth_handlers.js` | `POST /api/auth/login`, `GET /api/auth/me`, `POST /api/auth/refresh` |
| **Customer Auth** | `auth_handlers.js` | `POST /api/customer/auth/request-magic-link`, `POST /api/customer/auth/verify-code` |
| **Customer Orders** | `order_handlers.js` | `GET /api/customer/orders`, `GET /api/customer/orders/:id` |
| **Push Tokens** | `device_token_handlers.js` | `POST /api/user/device-token`, `DELETE /api/user/device-token` |
| **Push Prefs** | `device_token_handlers.js` | `GET /api/user/push-preferences`, `PUT /api/user/push-preferences` |

### Device Workflow (Source of Truth)

From `worker/src/device-workflows.js`:

**Repair Workflow (17 statuses):**
```
device_received → diagnosing → ready_to_quote → awaiting_authorisation →
  → authorised_source_parts → authorised_awaiting_parts → ready_to_repair →
  → repairing → repaired_qc → repaired_ready → collected/despatched

Branch: awaiting_authorisation → rejected → rejection_qc → rejection_ready → collected
Branch: diagnosing → company_rejected → rejection_qc → rejection_ready → collected
Branch: repairing → awaiting_revised_quote → awaiting_authorisation
```

**Buyback Workflow (adds):** `ready_to_pay`, `payment_made`, `added_to_buyback`

### Response Format

All backend responses use:
```json
{
  "success": true,
  "data": { ... },
  "pagination": { "page": 1, "limit": 50, "total": 100, "totalPages": 2 }
}
```

### Key Business Logic

1. **Order status is AUTO-CALCULATED** from device statuses - iOS should NOT set order status directly
2. **Device transitions** follow strict state machine - use `getNextStatuses()` from workflows
3. **Push notifications** require `platform: "ios"`, `app_type: "staff"|"customer"`
4. **All field names** are `snake_case` from backend

---

## Detail View Responses (What to Display)

### Order Detail (`GET /api/orders/:id`)

From `order_handlers.js` - includes everything needed for order view:

| Section | Data |
|---------|------|
| **Header** | `order_number`, `status`, `payment_status`, `intake_method` |
| **Client** | Nested `client` object: name, email, phone, address, `email_suppressed` |
| **Location** | Nested `location` object: name, address |
| **Assigned** | Nested `assigned_user`: id, name |
| **Devices** | Array of devices with `status`, `workflow_type`, `authorization_status` |
| **Line Items** | Array: description, quantity, unit_price, vat_rate, line_total_inc_vat |
| **Payments** | Array: amount, payment_method, payment_date, is_deposit, refundable_amount |
| **Totals** | Nested `totals`: subtotal, vat_total, grand_total, amount_paid, balance_due |
| **Signatures** | Array: signature_type, typed_name, terms_agreed, captured_at |
| **Messages** | Nested `ticket.messages`: type, from_name, body_text, created_at |
| **Dates** | Nested `dates`: created_at, quote_sent_at, authorised_at, collected_at |

### Device Detail (`GET /api/orders/:orderId/devices/:deviceId`)

From `device_handlers.js` - comprehensive device data:

| Section | Data |
|---------|------|
| **Header** | `display_name` (brand/model), `status`, `workflow_type`, `priority` |
| **Specs** | serial_number, imei, colour, storage_capacity, passcode_type, find_my_status |
| **Condition** | condition_grade, customer_reported_issues, technician_found_issues |
| **Brand/Model** | Nested `brand` and `model` objects, or `custom_brand`/`custom_model` |
| **Assignment** | Nested `assigned_engineer`: id, name |
| **Location** | Nested `sub_location`: code, description, type |
| **Notes** | diagnosis_notes, repair_notes, technician_notes, authorization_notes |
| **Authorization** | Nested `authorization`: status, method, authorized_at, signature |
| **Images** | Array: image_type, filename, caption, r2_key (for URL) |
| **Accessories** | Array: accessory_type, description, returned_at |
| **Parts** | Array: part_name, part_sku, part_cost, supplier, is_oem |
| **Line Items** | Array: description, quantity, unit_price, line_total_inc_vat |
| **Device Notes** | Array: body, created_at, created_by |
| **Timestamps** | Nested `timestamps`: 12 date fields tracking full workflow |
| **Checklist** | Nested `checklist`: items array with completion_percentage |

### Ticket/Enquiry Detail (`GET /api/tickets/:id`)

From `ticket_handlers.js` - full conversation thread:

| Section | Data |
|---------|------|
| **Header** | `ticket_number`, `subject`, `status`, `ticket_type` |
| **Client** | Nested `client`: email, name, phone, email_suppressed, is_generated_email |
| **Assigned** | Nested `assigned_user`: first_name, last_name |
| **Location** | Nested `location`: id, name; `requires_location` flag |
| **Messages** | Array of full message objects (see below) |
| **Custom Email** | Nested `received_custom_email`: email_address, display_name |

**Message Object:**
```
type: outbound|inbound|internal_note|outbound_sms
from_email, from_name, to_email, subject
body_text, body_html
device_id, device_name (if linked to device)
created_by: {id, first_name, last_name}
events: [{event_type, event_data, created_at}]  // delivery tracking
attachments: [{filename, content_type, size_bytes, download_url}]
```

### Ticket Actions (Quick Reply Bar)

The ticket detail view needs action buttons for:

| Action | Endpoint | Request Body |
|--------|----------|--------------|
| **Send Public Reply** | `POST /api/tickets/:id/reply` | `{ html_body, text_body?, from_email_id? }` |
| **Add Internal Note** | `POST /api/tickets/:id/note` | `{ body }` |
| **Generate AI Reply** | `POST /api/tickets/:id/generate-response` | `{ location_id? }` - returns `{ response }` |
| **Execute Workflow** | `POST /api/tickets/:id/macro` | `{ macro_id, variable_overrides? }` |

**Workflow Modal** requires fetching available workflows:
- `GET /api/macros` → Returns array of workflows with `id`, `name`, `description`, `is_active`
- Each workflow has stages that execute sequentially (email, delay, follow-up)
- `variable_overrides` allows customizing template variables before execution

---

## Step 0: Pre-Implementation Setup (DO THIS FIRST)

Before starting any stage, set up a clean unified app target.

### Clean the iOS Project

Remove existing broken code and start fresh with backend as source of truth:

```bash
# Remove existing Core (will rebuild from backend specs)
rm -rf "Repair Minder/Repair Minder/Core/Models/"
rm -rf "Repair Minder/Repair Minder/Core/Networking/"
rm -rf "Repair Minder/Repair Minder/Core/Auth/"

# Remove existing Features (will rebuild matching backend)
rm -rf "Repair Minder/Repair Minder/Features/"

# Remove separate Customer target
rm -rf "Repair Minder/Customer/"

# Keep: App/, Shared/Components/, Resources/
```

### Already Removed (Offline/Sync)

These files have already been deleted as part of removing offline mode:
```
Core/Storage/                          # CoreData, repositories, sync
Resources/RepairMinder.xcdatamodeld/   # CoreData model
```

### Xcode Project Setup

1. Open `Repair Minder.xcodeproj`
2. Remove the "Customer" target if it exists
3. Ensure only "Repair Minder" target remains
4. Remove references to deleted files

### Backend Verification

Before coding, verify backend is running and test endpoints:

```bash
# Test staff auth
curl -X POST http://localhost:8787/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}'

# Test dashboard (with token)
curl http://localhost:8787/api/dashboard/stats \
  -H "Authorization: Bearer {token}"

# Test devices
curl http://localhost:8787/api/devices/my-queue \
  -H "Authorization: Bearer {token}"
```

---

## Success Criteria

| Criteria | Measurement |
|----------|-------------|
| Zero decode errors | No "keyNotFound", "typeMismatch", or "Failed to decode" in console |
| Role selection works | User can choose Staff or Customer at login |
| **Staff Features** | |
| Dashboard loads | Stats display with correct values, period picker works |
| My Queue functional | Shows user's assigned devices, updates on refresh |
| Device actions work | Status transitions execute successfully via API |
| Scanner works | Barcode/QR scan opens device detail |
| Orders display | List and detail views show all data correctly |
| Clients display | List and detail views show all data correctly |
| Enquiries functional | Messages display, replies send successfully |
| **Customer Features** | |
| Customer orders load | Customer sees their orders only |
| Quote approval works | Customer can approve/reject with signature |
| Customer messaging | Customer can send messages on orders |
| **Shared** | |
| Push notifications | Token registers with correct appType, deep links work |
| Build succeeds | Single target builds without errors |

---

## Dependencies & Prerequisites

### Required Before Starting
- [ ] Backend running (staging or local) at `/Volumes/Riki Repos/repairminder`
- [ ] Test staff account with valid credentials
- [ ] Xcode 15+ installed
- [ ] iOS 17+ deployment target confirmed
- [ ] Push notification certificates configured in Apple Developer Portal

### Backend Reference
All endpoint verification against: `/Volumes/Riki Repos/repairminder/worker/`

| Feature | Backend Handler File |
|---------|---------------------|
| Authentication | `worker/index.js` (auth routes), `worker/auth_handlers.js` |
| Dashboard | `worker/dashboard_handlers.js` |
| Devices | `worker/device_handlers.js` |
| Device Statuses | `worker/src/device-workflows.js` |
| Orders | `worker/order_handlers.js` |
| Tickets/Enquiries | `worker/ticket_handlers.js` |
| Clients | `worker/client_handlers.js` |
| Scanner | Uses device lookup endpoints in `worker/device_handlers.js` |
| Push Notifications | `worker/device_token_handlers.js` |
| Company Settings | `worker/company_handlers.js` |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Backend API changes during rebuild | Medium | High | Document endpoint versions, coordinate with backend team |
| Missing device statuses | Medium | Medium | Use `device-workflows.js` as source of truth for all 18 statuses |
| Push notification cert issues | Medium | Low | Test on physical device early, verify cert configuration |
| Token refresh race conditions | Low | High | Implement proper token refresh queue, handle 401s gracefully |
| Decode errors from new fields | Medium | Medium | Use optional types liberally, log unknown fields |

---

## Stage Index

| Stage | Name | Backend Source | Key Endpoints |
|-------|------|----------------|---------------|
| **01** | [API Verification](01-api-verification.md) | `worker/index.js` (routes) | Document all endpoints from backend |
| **02** | [Foundation](02-foundation.md) | All handler files | Models matching backend response shapes |
| **03** | [Authentication](03-authentication.md) | `auth_handlers.js` | `POST /api/auth/login`, `POST /api/customer/auth/*` |
| **04** | [Dashboard & My Queue](04-dashboard-myqueue.md) | `dashboard_handlers.js`, `device_handlers.js` | `GET /api/dashboard/stats`, `GET /api/devices/my-queue` |
| **05** | [Devices & Scanner](05-devices-scanner.md) | `device_handlers.js`, `device-workflows.js` | `GET/PATCH /api/devices`, status transitions |
| **06** | [Orders & Clients](06-orders-clients.md) | `order_handlers.js`, `client_handlers.js` | `GET/PATCH /api/orders`, `GET /api/clients` |
| **07** | [Enquiries](07-enquiries.md) | `ticket_handlers.js`, `ticket_llm_handlers.js`, `macro_execution_handlers.js` | List, detail, reply, internal note, AI generate, workflow execute |
| **08** | [Settings & Push](08-settings-push.md) | `device_token_handlers.js` | `POST/DELETE /api/user/device-token`, preferences |
| **09** | [Customer Screens](09-customer-screens.md) | `order_handlers.js` | `GET /api/customer/orders`, quote approval |
| **10** | [Integration Testing](10-integration-testing.md) | All handlers | End-to-end against live backend |

### Stage Dependencies

```
Stage 01 ──> Stage 02 ──> Stage 03 ──┬──> Stage 04 (Staff: Dashboard)
                                     ├──> Stage 05 (Staff: Devices & Scanner)
                                     ├──> Stage 06 (Staff: Orders & Clients)
                                     ├──> Stage 07 (Staff: Enquiries)
                                     ├──> Stage 08 (Both: Settings & Push)
                                     └──> Stage 09 (Customer: Screens)
                                                    │
                                     All Stages ────┴──> Stage 10 (Integration Testing)
```

- Stages 04-09 can run in parallel after Stage 03 completes
- Stage 08 (Settings) is shared by both roles
- Stage 10 (Integration Testing) runs after all other stages are complete
- Each stage is independently testable once its dependencies are met

---

## Out of Scope

This plan explicitly does NOT cover:

| Item | Reason | Location |
|------|--------|----------|
| **Booking Feature** | Separate plan exists | `plans/new-booking-feature/` |
| **Offline Mode / CoreData** | Already removed, staying online-only | N/A |
| **Unit Tests** | Separate effort after rebuild | Future work |
| **UI Polish / Animations** | Focus on functionality first | Future work |
| **Accessories / Parts Management** | Not core staff workflow | Future work |
| **Inventory / Stock** | Not core staff workflow | Future work |
| **Payment Processing** | Web-only for now | N/A |
| **Customer Enquiry Submission** | Done via website/public API | N/A |

---

## File Structure

### Plan Documents
```
plans/staff-app-rebuild/
├── 00-master-plan.md           # This file
├── 01-api-verification.md      # Endpoint documentation (staff + customer)
├── 02-foundation.md            # Models + networking
├── 03-authentication.md        # Role selection, dual auth flows
├── 04-dashboard-myqueue.md     # Dashboard feature (Staff)
├── 05-devices-scanner.md       # Devices and scanner features (Staff)
├── 06-orders-clients.md        # Orders and clients features (Staff)
├── 07-enquiries.md             # Enquiries/tickets feature (Staff)
├── 08-settings-push.md         # Settings and push notifications (Both)
├── 09-customer-screens.md      # Customer order list, quote approval (Customer)
└── 10-integration-testing.md   # End-to-end testing (Both)
```

### iOS App Structure (Rebuild)

Clean rebuild matching backend structure:

```
Repair Minder/Repair Minder/
├── App/
│   ├── AppDelegate.swift           # Push notification handling
│   ├── AppState.swift              # Global state + UserRole
│   ├── UserRole.swift              # Staff vs Customer enum
│   └── Repair_MinderApp.swift      # Entry point with role-based navigation
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift       # Handles staff + customer auth flows
│   │   └── KeychainManager.swift   # Secure token storage
│   ├── Models/                     # Match backend response shapes exactly
│   │   ├── Device.swift            # From device_handlers.js response
│   │   ├── DeviceStatus.swift      # From device-workflows.js (20 statuses)
│   │   ├── Order.swift             # From order_handlers.js response
│   │   ├── OrderStatus.swift       # Auto-calculated statuses
│   │   ├── Ticket.swift            # From ticket_handlers.js response
│   │   ├── Client.swift            # From client_handlers.js response
│   │   ├── DashboardStats.swift    # From dashboard_handlers.js response
│   │   └── User.swift              # From auth_handlers.js response
│   ├── Networking/
│   │   ├── APIClient.swift         # snake_case decoder, auth interceptor
│   │   ├── APIEndpoints.swift      # All endpoints from worker/index.js
│   │   └── APIResponse.swift       # Standard {success, data, pagination}
│   └── Notifications/
│       ├── PushNotificationManager.swift  # device_token_handlers.js
│       └── DeepLinkHandler.swift
├── Features/
│   ├── Auth/                       # Role selection + login screens
│   ├── Staff/
│   │   ├── Dashboard/              # dashboard_handlers.js
│   │   ├── Devices/                # device_handlers.js
│   │   ├── Scanner/                # Device lookup
│   │   ├── Orders/                 # order_handlers.js
│   │   ├── Clients/                # client_handlers.js
│   │   └── Enquiries/              # ticket_handlers.js
│   ├── Customer/
│   │   ├── OrderList/              # GET /api/customer/orders
│   │   ├── OrderDetail/            # GET /api/customer/orders/:id
│   │   └── QuoteApproval/          # POST /api/customer/orders/:id/approve
│   └── Settings/                   # Push preferences (both roles)
└── Shared/
    └── Components/                 # Reusable UI components
```

---

## API Response Format

All backend responses use this envelope:

```json
{
  "success": true,
  "data": { ... },
  "error": "Error message if success=false",
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "total_pages": 5
  }
}
```

**Critical**: All field names are `snake_case` from backend. Swift decoder converts to `camelCase`.

---

## Device Statuses (Source of Truth)

From `[Ref: /Volumes/Riki Repos/repairminder/worker/src/device-workflows.js]`:

### Repair Workflow (17 statuses)
| Status | Display Name |
|--------|--------------|
| `device_received` | Device Received |
| `diagnosing` | Diagnosing |
| `ready_to_quote` | Ready to Quote |
| `company_rejected` | Company Rejected |
| `awaiting_authorisation` | Awaiting Authorisation |
| `authorised_source_parts` | Authorised - Source Parts |
| `authorised_awaiting_parts` | Awaiting Parts |
| `ready_to_repair` | Ready to Repair |
| `repairing` | Repairing |
| `awaiting_revised_quote` | Awaiting Revised Quote |
| `repaired_qc` | Repaired - QC |
| `repaired_ready` | Repaired - Ready |
| `rejected` | Rejected |
| `rejection_qc` | Rejection - QC |
| `rejection_ready` | Rejection - Ready |
| `collected` | Collected |
| `despatched` | Despatched |

### Buyback Workflow (3 additional)
| Status | Display Name |
|--------|--------------|
| `ready_to_pay` | Ready to Pay |
| `payment_made` | Payment Made |
| `added_to_buyback` | Added to Buyback |

---

## Verification Commands

### Build Verification
```bash
# Build staff app for simulator
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro" \
  build

# Build for device (release)
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -destination "generic/platform=iOS" \
  build
```

### Runtime Verification
1. Launch app in Simulator
2. Login with test credentials
3. Monitor Xcode console for decode errors
4. Navigate through all features
5. Verify data displays correctly

---

## Handoff Notes

After all stages complete:
1. Run full integration test on physical device
2. Verify push notifications work end-to-end
3. Test all deep link scenarios
4. Performance check on list views with pagination
5. Ready for TestFlight internal testing
