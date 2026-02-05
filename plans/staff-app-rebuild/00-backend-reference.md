# RepairMinder Backend API Reference

This document provides a comprehensive reference for the RepairMinder backend API, covering authentication, endpoints, and response shapes needed for the iOS app rebuild.

> **Authoritative Source:** The complete list of 260+ endpoint authorization rules is in `/Volumes/Riki Repos/repairminder/worker/src/middleware/authorization.js` (also viewable at `/settings/api-endpoints` for master admins in the web app).

## Table of Contents
1. [Authentication](#authentication)
2. [Roles & Authorization](#roles--authorization)
3. [Staff API Endpoints](#staff-api-endpoints)
4. [Customer API Endpoints](#customer-api-endpoints)
5. [Device Workflows & Statuses](#device-workflows--statuses)
6. [Push Notifications](#push-notifications)
7. [Response Shapes](#response-shapes)

---

## Authentication

### Staff Authentication

**Base URL:** `https://api.repairminder.com`

#### Login Flow (2FA Required)

1. **POST /api/auth/login** - Initial login with email/password
   ```json
   // Request
   { "email": "user@example.com", "password": "xxx" }

   // Response (requires 2FA)
   {
     "requiresTwoFactor": true,
     "userId": "uuid",
     "email": "user@example.com",
     "user": {
       "id": "uuid",
       "email": "user@example.com",
       "firstName": "John",
       "lastName": "Doe",
       "companyId": "uuid"
     }
   }
   ```

2. **POST /api/auth/2fa/request** - Request 2FA code via email
   ```json
   // Request
   { "userId": "uuid", "email": "user@example.com" }

   // Response
   { "message": "2FA code sent to your email" }
   ```

3. **POST /api/auth/2fa/verify** - Verify 2FA code and get tokens
   ```json
   // Request
   { "userId": "uuid", "code": "123456" }

   // Response
   {
     "token": "access_token_jwt",
     "refreshToken": "opaque_refresh_token",
     "expiresIn": 900,
     "user": { /* sanitized user object */ },
     "company": { /* sanitized company object */ }
   }
   ```

#### Alternative: Magic Link Login

1. **POST /api/auth/magic-link/request** - Request magic link
2. **POST /api/auth/magic-link/verify-code** - Verify 6-digit code

#### Token Management

- **Access Token:** JWT, 15 minutes expiry
- **Refresh Token:** Opaque, 7 days (web) or 90 days (mobile)
- Mobile detected via User-Agent header

**POST /api/auth/refresh** - Refresh tokens
```json
// Request
{ "refreshToken": "opaque_refresh_token" }

// Response
{
  "token": "new_access_token",
  "refreshToken": "new_refresh_token",
  "expiresIn": 900
}
```

**GET /api/auth/me** - Get current user
```json
// Response
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "company_id": "uuid",
    "role": "admin|technician|receptionist|analyst|master_admin",
    "phi_access_level": "none|read|full",
    "data_classification": "public|internal|confidential|restricted",
    "is_active": 1,
    "magic_link_enabled": 1,
    "company_status": "active|pending_approval|suspended"
  },
  "company": {
    "id": "uuid",
    "name": "Company Name",
    "status": "active",
    "currency_code": "GBP",
    /* other company fields */
  },
  "hasPassword": true
}
```

**POST /api/auth/logout** - Logout

#### TOTP (Authenticator App)

- **POST /api/auth/totp/setup** - Setup TOTP
- **POST /api/auth/totp/verify-setup** - Verify setup with code
- **POST /api/auth/totp/disable** - Disable TOTP
- **GET /api/auth/totp/status** - Get TOTP status

---

### Customer Authentication

Customer auth is **completely separate** from staff auth and uses magic link only (no passwords).

#### Login Flow

1. **POST /api/customer/auth/request-magic-link**
   ```json
   // Request
   { "email": "customer@example.com", "companyId": "optional_uuid" }

   // Response
   { "message": "If an account exists, a login code has been sent" }
   ```

2. **POST /api/customer/auth/verify-code**
   ```json
   // Request
   { "email": "customer@example.com", "code": "123456", "companyId": "optional_uuid" }

   // Response (single company)
   {
     "token": "customer_jwt",
     "client": {
       "id": "uuid",
       "firstName": "Jane",
       "lastName": "Doe",
       "email": "customer@example.com",
       "name": "Jane Doe"
     },
     "company": {
       "id": "uuid",
       "name": "Repair Shop",
       "logoUrl": "https://..."
     }
   }

   // Response (multiple companies - customer has accounts with multiple shops)
   {
     "requiresCompanySelection": true,
     "companies": [
       { "id": "uuid", "name": "Shop 1", "logoUrl": "..." },
       { "id": "uuid", "name": "Shop 2", "logoUrl": "..." }
     ],
     "email": "customer@example.com",
     "code": "123456"
   }
   ```

3. **GET /api/customer/auth/me** - Get current customer session
4. **POST /api/customer/auth/logout** - Logout

#### Customer JWT Claims
```json
{
  "type": "customer",
  "clientId": "uuid",
  "companyId": "uuid",
  "email": "customer@example.com",
  "scope": "customer_portal",
  "sessionId": "uuid"
}
```

---

## Roles & Authorization

The backend uses role-based access control (RBAC) with 260+ endpoint authorization rules.

### Built-in Roles

| Role | Description |
|------|-------------|
| `master_admin` | Full system access across all companies |
| `admin` | Company administrator with full company access |
| `senior_engineer` | Senior technician with operational access |
| `engineer` | Technician with queue and basic access |
| `office` | Office staff with client/order management |

### Role Default Page Access

Each role has built-in default access to certain pages (from `ROLE_BUILTIN_PAGES` in [authorization.js](/Volumes/Riki%20Repos/repairminder/worker/src/middleware/authorization.js)):

| Role | Default Pages |
|------|---------------|
| `master_admin` | All pages |
| `admin` | dashboard, enquiries, orders, devices, products, booking, active_queue, clients, buyback, inventory, vat_reports, socials_gallery, settings, company_settings, company_users, audit_logs |
| `senior_engineer` | dashboard, enquiries, orders, devices, active_queue, clients, products, buyback, settings, booking, inventory, vat_reports |
| `engineer` | dashboard, active_queue, settings, booking |
| `office` | dashboard, enquiries, orders, clients, products, settings, booking, inventory, vat_reports |

### Page-Protected Features

Certain endpoints require access to specific feature pages (configurable per company):

| pageKey | Endpoints |
|---------|-----------|
| `dashboard` | `/api/dashboard/*` |
| `orders` | `/api/orders/*`, `/api/pos/payments/*` |
| `devices` | `/api/devices/*`, `/api/device-types/*` |
| `clients` | `/api/clients/*`, `/api/client-groups/*` |
| `inventory` | `/api/assets/*`, `/api/supplier-orders/*` |
| `products` | `/api/product-types/*` |
| `buyback` | `/api/buyback/*` |
| `booking` | `/api/schedule/*` |
| `analytics` | `/api/analytics/*` |
| `reports` | `/api/reports/*` |
| `enquiries` | `/api/tickets/*` |

### Public Endpoints (No Auth Required)

- `/api/health` - Health check
- `/api/currencies` - Currency list
- `/api/auth/*` - Authentication flows
- `/api/customer/*` - Customer portal (uses customer JWT)
- `/api/webhooks/*` - External service webhooks
- `/api/public/*` - Public API (uses X-Api-Key header)

### Company Isolation

All data is isolated per company. The middleware automatically filters by `company_id` from the user's JWT. Users can only access data from their own company (except `master_admin`).

---

## Staff API Endpoints

### Dashboard

**GET /api/dashboard/stats**
- Query params: `scope=user|company`, `period=today|yesterday|this_week|this_month|last_month|custom`, `compare_periods=1-18`, `start_date`, `end_date`, `user_id` (admin only)
- Returns device counts, revenue, comparisons

**GET /api/dashboard/lifecycle** - Lifecycle metrics
**GET /api/dashboard/category-breakdown** - Revenue by category
**GET /api/dashboard/enquiry-stats** - Enquiry statistics
**GET /api/dashboard/booking-heatmap** - Booking patterns
**GET /api/dashboard/buyback-stats** - Buyback statistics
**GET /api/dashboard/activity-log** - Activity log
**GET /api/dashboard/bookings-by-time** - Bookings over time

### Orders

**GET /api/orders** - List orders
- Query params: `page`, `limit`, `status`, `payment_status`, `location_id`, `assigned_user_id`, `device_type_id`, `search`, `date_from`, `date_to`, `sort`, `order`, `category`, `period`

**POST /api/orders** - Create order
**GET /api/orders/:id** - Get order detail
**PATCH /api/orders/:id** - Update order

**Order Items:**
- GET/POST /api/orders/:id/items
- PATCH/DELETE /api/orders/:id/items/:itemId

**Order Payments:**
- GET/POST /api/orders/:id/payments
- DELETE /api/orders/:id/payments/:paymentId

**Order Signatures:**
- GET/POST /api/orders/:id/signatures
- GET /api/orders/:id/signatures/:signatureId

**Order Actions:**
- POST /api/orders/:id/send-quote
- POST /api/orders/:id/authorize
- POST /api/orders/:id/despatch
- POST /api/orders/:id/collect

### Devices (Order Devices)

**GET /api/devices** - List all devices (company-wide)
- Query params: `page`, `limit`, `search`, `device_type_id`, `status`, `exclude_status`, `show_archived`, `engineer_id`, `period`, `date_filter`, `location_id`, `include_buyback`

**GET /api/devices/my-queue** - Devices assigned to current user
**GET /api/devices/my-active-work** - Active work for current user

**GET /api/orders/:orderId/devices** - List devices for order
**POST /api/orders/:orderId/devices** - Add device to order
**GET /api/orders/:orderId/devices/:deviceId** - Get device detail
**PATCH /api/orders/:orderId/devices/:deviceId** - Update device
**DELETE /api/orders/:orderId/devices/:deviceId** - Delete device

**Device Status:**
- PATCH /api/orders/:orderId/devices/:deviceId/status
- GET /api/orders/:orderId/devices/:deviceId/actions - Get available actions
- POST /api/orders/:orderId/devices/:deviceId/action - Execute action

**Device Parts & Accessories:**
- GET/POST/DELETE /api/orders/:orderId/devices/:deviceId/accessories
- GET/POST/DELETE /api/orders/:orderId/devices/:deviceId/parts

**Device Images:**
- GET/POST /api/orders/:orderId/devices/:deviceId/images
- GET/PATCH/DELETE /api/orders/:orderId/devices/:deviceId/images/:imageId

### Clients

**GET /api/clients** - List clients
- Query params: `search`, `group_id`, `page`, `limit`, `sort`, `order`, `period`, `new`, `returning`, `blocked`

**POST /api/clients** - Create client
**GET /api/clients/:id** - Get client detail
**PATCH /api/clients/:id** - Update client
**DELETE /api/clients/:id** - Soft delete client

**GET /api/clients/search** - Search clients
**GET /api/clients/export** - Export clients
**POST /api/clients/import** - Import clients

**Client Groups:**
- GET/POST /api/client-groups
- GET/PATCH/DELETE /api/client-groups/:id
- POST /api/client-groups/:id/members
- DELETE /api/client-groups/:id/members/:clientId

### Tickets (Enquiries)

**GET /api/tickets** - List tickets
- Query params: `status`, `ticket_type`, `assigned_user_id`, `location_id`, `workflow_status`, `page`, `limit`

**POST /api/tickets** - Create ticket
**GET /api/tickets/:id** - Get ticket detail
**PATCH /api/tickets/:id** - Update ticket

**POST /api/tickets/:id/reply** - Send reply
**POST /api/tickets/:id/note** - Add internal note
**POST /api/tickets/:id/resolve** - Resolve ticket
**POST /api/tickets/:id/reassign** - Reassign ticket

**POST /api/tickets/enquiry** - Create enquiry (public)

### Users

**GET /api/users** - List company users
**GET /api/users/:id** - Get user detail
**POST /api/users** - Create user (admin only)
**PATCH /api/users/:id** - Update user
**DELETE /api/users/:id** - Delete user

**GET /api/users/me** - Get current user
**PATCH /api/users/me** - Update current user profile
**POST /api/users/me/avatar** - Upload avatar

### Locations

**GET /api/locations** - List locations
**POST /api/locations** - Create location
**GET /api/locations/:id** - Get location
**PATCH /api/locations/:id** - Update location
**DELETE /api/locations/:id** - Delete location
**POST /api/locations/:id/set-primary** - Set as primary

### Company Settings

**GET /api/companies/:id** - Get company settings
**PATCH /api/companies/:id** - Update company settings

---

## Customer API Endpoints

All require customer authentication token.

**GET /api/customer/orders** - List customer's orders
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "ticket_number": 12345,
      "status": "in_progress",
      "created_at": "2024-01-15T10:00:00Z",
      "devices": [
        {
          "id": "uuid",
          "status": "repairing",
          "display_name": "Apple iPhone 15 Pro"
        }
      ],
      "totals": {
        "subtotal": 100.00,
        "vat_total": 20.00,
        "grand_total": 120.00
      }
    }
  ],
  "currency_code": "GBP"
}
```

**GET /api/customer/orders/:orderId** - Get order detail with devices, items, messages

**POST /api/customer/orders/:orderId/approve** - Approve quote/device
**POST /api/customer/orders/:orderId/reply** - Send message to shop
**GET /api/customer/orders/:orderId/invoice** - Get invoice PDF

**GET /api/customer/devices/:deviceId/images/:imageId/file** - Get device image

---

## Device Workflows & Statuses

### Workflow Types
- `repair` - Standard repair workflow
- `buyback` - Device buyback/trade-in workflow

### Order Statuses (Auto-calculated from devices)
| Status | Label | Description |
|--------|-------|-------------|
| `awaiting_device` | Awaiting Device | No devices received yet |
| `in_progress` | In Progress | Work ongoing on devices |
| `service_complete` | Service Complete | All devices at final service stage |
| `awaiting_collection` | Awaiting Collection/Despatch | All devices ready for pickup |
| `collected_despatched` | Collected/Despatched | All devices collected or despatched |

### Repair Device Statuses
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

### Buyback Device Statuses
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

### Status Transitions (Repair)
```
device_received -> diagnosing
diagnosing -> ready_to_quote
ready_to_quote -> awaiting_authorisation | company_rejected | authorised_source_parts | authorised_awaiting_parts | ready_to_repair
awaiting_authorisation -> authorised_source_parts | authorised_awaiting_parts | ready_to_repair | rejected
authorised_source_parts -> authorised_awaiting_parts | awaiting_authorisation
authorised_awaiting_parts -> ready_to_repair | awaiting_authorisation
ready_to_repair -> repairing | awaiting_authorisation
repairing -> repaired_qc | awaiting_revised_quote | awaiting_authorisation
awaiting_revised_quote -> awaiting_authorisation
repaired_qc -> repaired_ready | ready_to_repair (QC failed)
repaired_ready -> collected | despatched
rejected -> rejection_qc
company_rejected -> rejection_qc
rejection_qc -> rejection_ready
rejection_ready -> collected | despatched
```

### Terminal Statuses
- `collected`
- `despatched`
- `added_to_buyback`

---

## Push Notifications

> **Status: Fully Implemented** - All D1 tables, API endpoints, APNs service, and trigger functions are production-ready.

### D1 Database Tables

| Table | Purpose |
|-------|---------|
| `device_tokens` | APNS tokens with user/company association, platform, app_type, device metadata |
| `push_notification_preferences` | Per-user notification toggles (10 categories + master toggle) |
| `push_notification_log` | Delivery audit trail with status, apns_id, error messages |

### Backend Implementation Files

| File | Purpose |
|------|---------|
| `migrations/0265_device_tokens.sql` | Creates device_tokens and push_notification_log tables |
| `migrations/0266_push_notification_preferences.sql` | Creates preferences table |
| `device_token_handlers.js` | API endpoint handlers for token/preference CRUD |
| `src/apns.js` | APNs service with JWT auth (ES256), HTTP/2, batch sending |
| `src/order-push-triggers.js` | 8 trigger functions called from order_handlers.js |

### Trigger Functions

| Function | Preference Key | Description |
|----------|----------------|-------------|
| `triggerOrderStatusPush` | `order_status_changed` | Staff notified of order status changes |
| `triggerCustomerOrderStatusPush` | - | Customer app order updates |
| `triggerDeviceStatusPush` | `device_status_changed` | Prioritizes assigned engineer |
| `triggerNewEnquiryPush` | `new_enquiry` | New customer enquiry |
| `triggerEnquiryReplyPush` | `enquiry_reply` | Customer reply on ticket |
| `triggerQuoteApprovedPush` | `quote_approved` | Quote approved |
| `triggerQuoteRejectedPush` | `quote_rejected` | Quote rejected |
| `triggerPaymentReceivedPush` | `payment_received` | Payment received |

### APNs Configuration (Environment Variables)

```
APNS_TEAM_ID       = "T578MBWLM2"
APNS_KEY_ID        = "..." (required)
APNS_AUTH_KEY      = "..." (PEM format, required)
APNS_BUNDLE_ID     = "com.mendmyi.repairminder" (staff app)
APNS_CUSTOMER_BUNDLE_ID = "com.mendmyi.Repair-Minder-Customer" (customer app)
APNS_ENVIRONMENT   = "sandbox" | "production"
```

### Device Token Registration

**POST /api/user/device-token** - Register device token
```json
// Request
{
  "deviceToken": "apns_token_string",
  "platform": "ios",
  "appType": "staff|customer",
  "deviceName": "iPhone 15 Pro",
  "osVersion": "17.4",
  "appVersion": "1.0.0"
}

// Response
{ "success": true, "message": "Device token registered successfully" }
```

**DELETE /api/user/device-token** - Unregister (on logout)
```json
// Request
{ "deviceToken": "apns_token_string" }
```

**GET /api/user/device-tokens** - List user's registered tokens

### Push Preferences

**GET /api/user/push-preferences**
```json
{
  "success": true,
  "preferences": {
    "notificationsEnabled": true,
    "orderStatusChanged": true,
    "orderCreated": true,
    "orderCollected": true,
    "deviceStatusChanged": true,
    "quoteApproved": true,
    "quoteRejected": true,
    "paymentReceived": true,
    "newEnquiry": true,
    "enquiryReply": true
  }
}
```

**PUT /api/user/push-preferences** - Update preferences
```json
// Request (only include fields to update)
{
  "notificationsEnabled": true,
  "newEnquiry": false
}
```

---

## Response Shapes

### Standard Response Wrapper
```json
{
  "success": true|false,
  "data": { /* response data */ },
  "error": "Error message if success=false"
}
```

### Paginated List Response
```json
{
  "success": true,
  "data": [ /* items */ ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

### User Object (Sanitized)
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "company_id": "uuid",
  "role": "admin",
  "phi_access_level": "none",
  "data_classification": "public",
  "is_active": 1,
  "last_login": "2024-01-15T10:00:00Z",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-15T10:00:00Z"
}
```

### Company Object (Sanitized)
```json
{
  "id": "uuid",
  "name": "Company Name",
  "status": "active",
  "currency_code": "GBP",
  "vat_number": "GB123456789",
  "terms_conditions": "...",
  "logo_url": "https://...",
  "vat_rate_repair": 20.0,
  "vat_rate_device_sale": 20.0,
  "vat_rate_accessory": 20.0,
  "vat_rate_device_purchase": 0.0
}
```

### Order Object
```json
{
  "id": "uuid",
  "order_number": 12345,
  "ticket_id": "uuid",
  "client_id": "uuid",
  "company_id": "uuid",
  "location_id": "uuid",
  "assigned_user_id": "uuid",
  "status": "in_progress",
  "payment_status": "unpaid|partial|paid|refunded",
  "total": 120.00,
  "amount_paid": 0.00,
  "balance_due": 120.00,
  "quote_sent_at": null,
  "quote_approved_at": null,
  "rejected_at": null,
  "collected_at": null,
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-15T10:00:00Z"
}
```

### Device Object
```json
{
  "id": "uuid",
  "order_id": "uuid",
  "brand_id": "uuid",
  "model_id": "uuid",
  "custom_brand": null,
  "custom_model": null,
  "brand_name": "Apple",
  "model_name": "iPhone 15 Pro",
  "serial_number": "ABC123",
  "imei": "123456789012345",
  "colour": "Black",
  "storage_capacity": "256GB",
  "status": "repairing",
  "workflow_type": "repair",
  "priority": "normal",
  "due_date": null,
  "assigned_engineer_id": "uuid",
  "engineer_name": "John Doe",
  "condition_grade": "B",
  "find_my_status": "off",
  "sub_location_id": "uuid",
  "sub_location_code": "A1",
  "device_type_id": "uuid",
  "device_type_name": "Phone",
  "customer_reported_issues": "Screen cracked",
  "technician_found_issues": "Battery also degraded",
  "diagnosis_notes": "...",
  "repair_notes": "...",
  "received_at": "2024-01-15T10:00:00Z",
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-15T12:00:00Z"
}
```

### Client Object
```json
{
  "id": "uuid",
  "company_id": "uuid",
  "email": "customer@example.com",
  "first_name": "Jane",
  "last_name": "Doe",
  "name": "Jane Doe",
  "phone": "+44 7700 900000",
  "notes": "VIP customer",
  "address_line_1": "123 High Street",
  "address_line_2": null,
  "city": "London",
  "county": "Greater London",
  "postcode": "SW1A 1AA",
  "country": "United Kingdom",
  "email_suppressed": 0,
  "order_count": 5,
  "last_order_at": "2024-01-15T10:00:00Z",
  "created_at": "2023-01-01T00:00:00Z",
  "updated_at": "2024-01-15T10:00:00Z"
}
```

### Ticket Object
```json
{
  "id": "uuid",
  "company_id": "uuid",
  "ticket_number": 12345,
  "subject": "iPhone repair enquiry",
  "ticket_type": "enquiry|order",
  "status": "open|pending|resolved|closed",
  "priority": "low|normal|high|urgent",
  "client_id": "uuid",
  "client_email": "customer@example.com",
  "client_name": "Jane Doe",
  "assigned_user_id": "uuid",
  "assigned_first_name": "John",
  "assigned_last_name": "Doe",
  "location_id": "uuid",
  "loc_name": "Main Store",
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-01-15T10:00:00Z"
}
```

---

## Headers

### Required Headers
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

### Mobile Detection
The backend detects mobile clients via User-Agent header containing:
- `Mobile`, `Android`, `iPhone`, `iPad`, `iPod`, `BlackBerry`, `Windows Phone`, `Opera Mini`

Mobile clients get longer refresh token expiry (90 days vs 7 days).

---

## Error Responses

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation error)
- `401` - Unauthorized (invalid/expired token)
- `403` - Forbidden (insufficient permissions or quarantine mode)
- `404` - Not Found
- `429` - Rate Limited
- `500` - Server Error

### Quarantine Mode
Users from companies with `status='pending_approval'` or `status='suspended'` are in quarantine mode and can only access limited endpoints:
- /api/auth/me, /api/auth/logout, /api/auth/refresh, /api/auth/change-password
- /api/companies (own company only)
- /api/locations
- /api/users/me
- /api/subscription, /api/subscription/features

Error response when blocked:
```json
{
  "success": false,
  "error": "Your account is pending approval. Please wait for your account to be verified.",
  "code": "ACCOUNT_PENDING_APPROVAL"
}
```
