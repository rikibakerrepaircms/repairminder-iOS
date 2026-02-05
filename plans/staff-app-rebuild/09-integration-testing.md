# Stage 09: Integration Testing

## Objective

End-to-end verification of all iOS app features against the live RepairMinder backend API. This document provides comprehensive test checklists, curl commands, and verification procedures.

---

## ⚠️ Pre-Testing Verification

**Before running integration tests, verify:**

1. **Backend hasn't changed** - Check recent commits to `/Volumes/Riki Repos/repairminder/worker/` for any API changes since implementation

2. **Test data exists** - Verify test company has sufficient data for all test scenarios

3. **All stages complete** - Confirm stages 01-08 were implemented with their verification steps completed

```bash
# Check for recent backend changes
cd /Volumes/Riki\ Repos/repairminder && git log --oneline -10 -- worker/

# Verify test company data
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT COUNT(*) as orders FROM orders WHERE company_id = '4b63c1e6ade1885e73171e10221cac53'"
```

---

## Pre-Testing Setup

### 1. Always Test Token Validity First

Before any testing session, verify your token is valid:

```bash
curl -s "https://api.repairminder.com/api/dashboard/stats" \
  -H "Authorization: Bearer TOKEN" | jq '.success'
```

If this returns `true`, the token is valid. If `false` or error, generate a new token.

### 2. Test Data Company

**Always use the RepairMinder test company:**
- **Company ID:** `4b63c1e6ade1885e73171e10221cac53`
- **Company Name:** RepairMinder

### 3. Test Users by Role

| Role | Email | Access Level |
|------|-------|--------------|
| `master_admin` | rikibaker+repairminder@gmail.com | Full system access |
| `admin` | rikibaker+admin@gmail.com | Company admin - full company access |
| `senior_engineer` | rikibaker+linda@gmail.com | Enhanced engineer access |
| `engineer` | rikibaker+engineer@gmail.com | Restricted: dashboard, active_queue, settings, booking |
| `office` | rikibaker+office@gmail.com | Office staff: orders, clients, enquiries |
| `customer` | rikibaker+customer@gmail.com | Customer portal access |

---

## Token Generation

### Staff Token (Magic Link)

```bash
# Step 1: Request magic link
curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/request" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+admin@gmail.com"}'

# Step 2: Get code from database
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" \
  2>/dev/null | jq -r '.[0].results[0].magic_link_code'

# Step 3: Exchange for token (replace XXXXXX with code)
curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+admin@gmail.com", "code": "XXXXXX"}' | jq -r '.data.token'
```

### Customer Token

```bash
# Step 1: Request magic link
curl -s -X POST "https://api.repairminder.com/api/customer/auth/request-magic-link" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com"}'

# Step 2: Get code from database
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT magic_link_code FROM clients WHERE email = 'rikibaker+customer@gmail.com'" \
  2>/dev/null | jq -r '.[0].results[0].magic_link_code'

# Step 3: Exchange for token (replace XXXXXX with code)
curl -s -X POST "https://api.repairminder.com/api/customer/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com", "code": "XXXXXX"}' | jq -r '.data.token'
```

---

## Rate Limit Handling

If you see "Too many login attempts":

```bash
# Get your IP address
curl -s https://api.repairminder.com/api/health | jq -r '.data.clientIp'

# Clear rate limit (replace YOUR_IP)
npx wrangler kv key delete "ratelimit:login:YOUR_IP" --namespace-id=57411dc0d8ef442db466a4e74c59ebb2
```

---

## Endpoint Test Commands

### Authentication Endpoints

#### Staff Login Flow

```bash
# POST /api/auth/login - Initial login
curl -s -X POST "https://api.repairminder.com/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+admin@gmail.com", "password": "test123"}' | jq

# POST /api/auth/2fa/request - Request 2FA code
curl -s -X POST "https://api.repairminder.com/api/auth/2fa/request" \
  -H "Content-Type: application/json" \
  -d '{"userId": "USER_ID", "email": "rikibaker+admin@gmail.com"}' | jq

# POST /api/auth/2fa/verify - Verify 2FA code
curl -s -X POST "https://api.repairminder.com/api/auth/2fa/verify" \
  -H "Content-Type: application/json" \
  -d '{"userId": "USER_ID", "code": "123456"}' | jq

# POST /api/auth/refresh - Refresh token
curl -s -X POST "https://api.repairminder.com/api/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refreshToken": "REFRESH_TOKEN"}' | jq

# GET /api/auth/me - Get current user
curl -s "https://api.repairminder.com/api/auth/me" \
  -H "Authorization: Bearer TOKEN" | jq

# POST /api/auth/logout - Logout
curl -s -X POST "https://api.repairminder.com/api/auth/logout" \
  -H "Authorization: Bearer TOKEN" | jq
```

#### Customer Login Flow

```bash
# POST /api/customer/auth/request-magic-link
curl -s -X POST "https://api.repairminder.com/api/customer/auth/request-magic-link" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com"}' | jq

# POST /api/customer/auth/verify-code
curl -s -X POST "https://api.repairminder.com/api/customer/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com", "code": "XXXXXX"}' | jq

# GET /api/customer/auth/me
curl -s "https://api.repairminder.com/api/customer/auth/me" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq
```

### Dashboard Endpoints

```bash
# GET /api/dashboard/stats - User scope
curl -s "https://api.repairminder.com/api/dashboard/stats?scope=user&period=this_month" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/dashboard/stats - Company scope (admin only)
curl -s "https://api.repairminder.com/api/dashboard/stats?scope=company&period=this_month" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/dashboard/stats - Custom period
curl -s "https://api.repairminder.com/api/dashboard/stats?period=custom&start_date=2026-01-01&end_date=2026-01-31" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/dashboard/stats - With comparison
curl -s "https://api.repairminder.com/api/dashboard/stats?period=this_month&compare_periods=3" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/dashboard/enquiry-stats
curl -s "https://api.repairminder.com/api/dashboard/enquiry-stats?scope=user" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/dashboard/lifecycle
curl -s "https://api.repairminder.com/api/dashboard/lifecycle" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/dashboard/activity-log
curl -s "https://api.repairminder.com/api/dashboard/activity-log" \
  -H "Authorization: Bearer TOKEN" | jq
```

### Devices Endpoints

```bash
# GET /api/devices - List all devices
curl -s "https://api.repairminder.com/api/devices?page=1&limit=20" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/devices - With filters
curl -s "https://api.repairminder.com/api/devices?status=diagnosing&workflow_category=repair" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/devices - Search by serial/IMEI
curl -s "https://api.repairminder.com/api/devices?search=ABC123" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/devices/my-queue - My assigned devices
curl -s "https://api.repairminder.com/api/devices/my-queue?page=1&limit=20" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/devices/my-queue - By category
curl -s "https://api.repairminder.com/api/devices/my-queue?category=repair" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/devices/my-active-work - Active work
curl -s "https://api.repairminder.com/api/devices/my-active-work" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders/:orderId/devices/:deviceId - Device detail
curl -s "https://api.repairminder.com/api/orders/ORDER_ID/devices/DEVICE_ID" \
  -H "Authorization: Bearer TOKEN" | jq

# PATCH /api/orders/:orderId/devices/:deviceId - Update device
curl -s -X PATCH "https://api.repairminder.com/api/orders/ORDER_ID/devices/DEVICE_ID" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"priority": "urgent", "technician_notes": "Test note"}' | jq

# GET /api/orders/:orderId/devices/:deviceId/actions - Available actions
curl -s "https://api.repairminder.com/api/orders/ORDER_ID/devices/DEVICE_ID/actions" \
  -H "Authorization: Bearer TOKEN" | jq

# PATCH /api/orders/:orderId/devices/:deviceId/status - Update status
curl -s -X PATCH "https://api.repairminder.com/api/orders/ORDER_ID/devices/DEVICE_ID/status" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "diagnosing"}' | jq
```

### Orders Endpoints

```bash
# GET /api/orders - List orders
curl -s "https://api.repairminder.com/api/orders?page=1&limit=20" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders - With filters
curl -s "https://api.repairminder.com/api/orders?status=in_progress&payment_status=unpaid" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders - Search
curl -s "https://api.repairminder.com/api/orders?search=12345" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders/:id - Order detail by UUID
curl -s "https://api.repairminder.com/api/orders/ORDER_UUID" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders/:id - Order detail by number
curl -s "https://api.repairminder.com/api/orders/12345" \
  -H "Authorization: Bearer TOKEN" | jq

# PATCH /api/orders/:id - Update order
curl -s -X PATCH "https://api.repairminder.com/api/orders/ORDER_ID" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"assigned_user_id": "USER_UUID"}' | jq

# GET /api/orders/:id/items - List order items
curl -s "https://api.repairminder.com/api/orders/ORDER_ID/items" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders/:id/payments - List payments
curl -s "https://api.repairminder.com/api/orders/ORDER_ID/payments" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/orders/:id/signatures - List signatures
curl -s "https://api.repairminder.com/api/orders/ORDER_ID/signatures" \
  -H "Authorization: Bearer TOKEN" | jq
```

### Clients Endpoints

```bash
# GET /api/clients - List clients
curl -s "https://api.repairminder.com/api/clients?page=1&limit=50" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/clients - Search
curl -s "https://api.repairminder.com/api/clients?search=john" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/clients/:id - Client detail
curl -s "https://api.repairminder.com/api/clients/CLIENT_ID" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/clients/search - Quick search
curl -s "https://api.repairminder.com/api/clients/search?q=smith" \
  -H "Authorization: Bearer TOKEN" | jq
```

### Tickets/Enquiries Endpoints

```bash
# GET /api/tickets - List tickets
curl -s "https://api.repairminder.com/api/tickets?page=1&limit=20" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/tickets - Filter by status
curl -s "https://api.repairminder.com/api/tickets?status=open" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/tickets - Filter by type
curl -s "https://api.repairminder.com/api/tickets?ticket_type=lead" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/tickets/:id - Ticket detail by UUID
curl -s "https://api.repairminder.com/api/tickets/TICKET_UUID" \
  -H "Authorization: Bearer TOKEN" | jq

# GET /api/tickets/:id - Ticket detail by number
curl -s "https://api.repairminder.com/api/tickets/100000001" \
  -H "Authorization: Bearer TOKEN" | jq

# POST /api/tickets/:id/reply - Send reply
curl -s -X POST "https://api.repairminder.com/api/tickets/TICKET_ID/reply" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"html_body": "<p>Test reply from API</p>", "status": "pending"}' | jq

# POST /api/tickets/:id/note - Add internal note
curl -s -X POST "https://api.repairminder.com/api/tickets/TICKET_ID/note" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body": "Internal note - customer called"}' | jq

# POST /api/tickets/:id/generate-response - Generate AI response
curl -s -X POST "https://api.repairminder.com/api/tickets/TICKET_ID/generate-response" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq

# GET /api/macros - List macros
curl -s "https://api.repairminder.com/api/macros?include_stages=true" \
  -H "Authorization: Bearer TOKEN" | jq

# POST /api/tickets/:id/macro - Execute macro
curl -s -X POST "https://api.repairminder.com/api/tickets/TICKET_ID/macro" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"macro_id": "MACRO_UUID"}' | jq
```

### Push Notification Endpoints

```bash
# POST /api/user/device-token - Register token
curl -s -X POST "https://api.repairminder.com/api/user/device-token" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "deviceToken": "test_apns_token_12345",
    "platform": "ios",
    "appType": "staff",
    "deviceName": "iPhone 15 Pro",
    "osVersion": "17.4",
    "appVersion": "1.0.0"
  }' | jq

# GET /api/user/device-tokens - List tokens
curl -s "https://api.repairminder.com/api/user/device-tokens" \
  -H "Authorization: Bearer TOKEN" | jq

# DELETE /api/user/device-token - Unregister token
curl -s -X DELETE "https://api.repairminder.com/api/user/device-token" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"deviceToken": "test_apns_token_12345"}' | jq

# GET /api/user/push-preferences - Get preferences
curl -s "https://api.repairminder.com/api/user/push-preferences" \
  -H "Authorization: Bearer TOKEN" | jq

# PUT /api/user/push-preferences - Update preferences
curl -s -X PUT "https://api.repairminder.com/api/user/push-preferences" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"newEnquiry": false, "notificationsEnabled": true}' | jq
```

### Customer Portal Endpoints

```bash
# GET /api/customer/orders - List customer orders
curl -s "https://api.repairminder.com/api/customer/orders" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq

# GET /api/customer/orders/:orderId - Order detail
curl -s "https://api.repairminder.com/api/customer/orders/ORDER_ID" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq

# POST /api/customer/orders/:orderId/approve - Approve quote (typed)
curl -s -X POST "https://api.repairminder.com/api/customer/orders/ORDER_ID/approve" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "approve",
    "signature_type": "typed",
    "signature_data": "John Smith",
    "amount_acknowledged": 127.18
  }' | jq

# POST /api/customer/orders/:orderId/approve - Reject quote
curl -s -X POST "https://api.repairminder.com/api/customer/orders/ORDER_ID/approve" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "reject",
    "rejection_reason": "Price too high"
  }' | jq

# POST /api/customer/orders/:orderId/reply - Send message
curl -s -X POST "https://api.repairminder.com/api/customer/orders/ORDER_ID/reply" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "When will my device be ready?"}' | jq
```

---

## Wrangler D1 Verification Queries

### Test Data Lookup

```bash
# Find orders for test company
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT id, order_number, status FROM orders WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' ORDER BY created_at DESC LIMIT 10"

# Find devices for test company
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT d.id, d.status, d.serial_number, o.order_number FROM order_devices d JOIN orders o ON d.order_id = o.id WHERE o.company_id = '4b63c1e6ade1885e73171e10221cac53' ORDER BY d.created_at DESC LIMIT 10"

# Find tickets for test company
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT id, ticket_number, status, subject FROM tickets WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' ORDER BY created_at DESC LIMIT 10"

# Find clients for test company
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT id, email, first_name, last_name FROM clients WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' LIMIT 10"

# Find users by role
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT id, email, role, first_name FROM users WHERE company_id = '4b63c1e6ade1885e73171e10221cac53'"
```

### Verify Data State

```bash
# Check device status distribution
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT status, COUNT(*) as count FROM order_devices d JOIN orders o ON d.order_id = o.id WHERE o.company_id = '4b63c1e6ade1885e73171e10221cac53' GROUP BY status"

# Check push tokens
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT platform, app_type, device_name, is_active FROM device_tokens WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' AND is_active = 1"

# Check magic link codes (for testing)
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT email, magic_link_code, magic_link_expires_at FROM users WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' AND magic_link_code IS NOT NULL"
```

---

## Console Error Patterns

### Swift Decoding Errors to Watch

| Error Pattern | Cause | Solution |
|---------------|-------|----------|
| `keyNotFound(CodingKeys...)` | Missing field in Swift model | Add optional property or check API response |
| `typeMismatch(...)` | Wrong type (e.g., String vs Int) | Fix Swift type to match API |
| `valueNotFound(...null)` | Null where non-optional expected | Make property optional |
| `dataCorrupted(...)` | Invalid data format | Check date/enum parsing |

### Common Field Name Mismatches

| Backend (snake_case) | Swift (camelCase) | Check |
|---------------------|-------------------|-------|
| `first_name` | `firstName` | CodingKeys or decoder |
| `created_at` | `createdAt` | Date decoder strategy |
| `device_type_id` | `deviceTypeId` | CodingKeys mapping |
| `total_pages` | `totalPages` | Pagination model |
| `workflow_type` | `workflowType` | Device/order models |
| `ticket_number` | `ticketNumber` | Ticket models |
| `order_number` | `orderNumber` | Order models |

### HTTP Errors

| Status | Meaning | Check |
|--------|---------|-------|
| `401` | Token expired/invalid | Trigger token refresh |
| `403` | Insufficient permissions | Check role has access |
| `404` | Resource not found | Verify ID/path |
| `422` | Validation error | Check request body |
| `429` | Rate limited | Clear rate limit |

---

## Role-Based Testing Matrix

### Test each role to verify proper access restrictions:

#### Master Admin (`master_admin`)
- [ ] Full access to all endpoints
- [ ] Can view company-scope dashboard stats
- [ ] Can access any company data

#### Admin (`admin`)
- [ ] Dashboard with company scope
- [ ] All devices, orders, clients, tickets
- [ ] User management endpoints
- [ ] Company settings

#### Senior Engineer (`senior_engineer`)
- [ ] Dashboard with user scope
- [ ] Devices, orders, clients
- [ ] Tickets (enquiries)
- [ ] Active queue

#### Engineer (`engineer`)
- [ ] Dashboard (user scope only)
- [ ] My Queue / Active Queue
- [ ] Settings
- [ ] **NO ACCESS**: Orders list, Clients list, Enquiries list

```bash
# Test engineer role restrictions (should return 403)
curl -s "https://api.repairminder.com/api/orders" \
  -H "Authorization: Bearer ENGINEER_TOKEN" | jq
# Expected: {"success":false,"error":"Access denied..."}

curl -s "https://api.repairminder.com/api/clients" \
  -H "Authorization: Bearer ENGINEER_TOKEN" | jq
# Expected: {"success":false,"error":"Access denied..."}
```

#### Office (`office`)
- [ ] Orders and order management
- [ ] Clients and client management
- [ ] Enquiries
- [ ] Products
- [ ] **NO ACCESS**: Devices list, Dashboard analytics

```bash
# Test office role restrictions
curl -s "https://api.repairminder.com/api/devices" \
  -H "Authorization: Bearer OFFICE_TOKEN" | jq
# Expected: {"success":false,"error":"Access denied..."}
```

---

## Customer Flow Testing

### Complete Customer Journey

1. **Request Magic Link**
```bash
curl -s -X POST "https://api.repairminder.com/api/customer/auth/request-magic-link" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com"}' | jq
```

2. **Verify Magic Link**
```bash
# Get code from DB first, then:
curl -s -X POST "https://api.repairminder.com/api/customer/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com", "code": "XXXXXX"}' | jq
```

3. **List Orders (Scoped to Customer)**
```bash
curl -s "https://api.repairminder.com/api/customer/orders" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq
```

4. **View Order Detail**
```bash
curl -s "https://api.repairminder.com/api/customer/orders/ORDER_ID" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq
```

5. **Approve Quote with Signature**
```bash
curl -s -X POST "https://api.repairminder.com/api/customer/orders/ORDER_ID/approve" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "approve",
    "signature_type": "typed",
    "signature_data": "Test Customer",
    "amount_acknowledged": 99.99
  }' | jq
```

6. **Verify 404 on Other Customer's Orders**
```bash
# Try accessing another customer's order - should return 404
curl -s "https://api.repairminder.com/api/customer/orders/OTHER_CUSTOMER_ORDER_ID" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq
# Expected: {"success":false,"error":"Order not found"}
```

---

## Feature Test Checklists

### Staff Authentication
- [ ] Login with email/password + 2FA
- [ ] Login with magic link
- [ ] Token refresh on 401
- [ ] Logout clears tokens
- [ ] Session persists across app restart
- [ ] Mobile User-Agent gets 90-day refresh token

### Dashboard & My Queue
- [ ] Stats load with user scope
- [ ] Stats load with company scope (admin)
- [ ] Period picker changes data (today/week/month)
- [ ] Compare periods shows historical data
- [ ] My Queue shows assigned devices
- [ ] My Queue filters (repair/buyback/unassigned)
- [ ] My Queue search works
- [ ] Active work shows in-progress items
- [ ] Pull-to-refresh updates data

### Devices
- [ ] Device list loads with pagination
- [ ] Device list filters (status, engineer, device type)
- [ ] Device search by serial/IMEI
- [ ] Device detail shows all sections
- [ ] Device notes display
- [ ] Device checklist displays
- [ ] Status badge shows correct color/label
- [ ] Status transitions work
- [ ] Only valid transitions shown
- [ ] Scanner opens camera
- [ ] Barcode scan finds device

### Orders
- [ ] Order list loads with pagination
- [ ] Order list filters (status, payment_status, location)
- [ ] Order search by number/client
- [ ] Order detail shows client info
- [ ] Order detail shows devices
- [ ] Order detail shows items
- [ ] Order detail shows payments
- [ ] Order detail shows signatures
- [ ] Order totals calculate correctly
- [ ] Order status reflects device statuses

### Clients
- [ ] Client list loads with pagination
- [ ] Client search works
- [ ] Client detail shows orders
- [ ] Client detail shows tickets
- [ ] Client detail shows devices
- [ ] Client stats display correctly

### Enquiries/Tickets
- [ ] Ticket list loads with pagination
- [ ] Ticket list filters (status, type, location)
- [ ] Status counts display correctly
- [ ] Ticket detail shows messages
- [ ] Inbound messages styled as customer
- [ ] Outbound messages styled as staff
- [ ] Internal notes styled distinctly
- [ ] Message events display (sent, delivered)
- [ ] Send reply works
- [ ] Add internal note works
- [ ] AI response generates
- [ ] Macro list loads
- [ ] Macro execution works
- [ ] Workflow status displays
- [ ] Cannot reply to closed tickets

### Settings & Push
- [ ] Push token registers on login
- [ ] Push token has correct appType (staff/customer)
- [ ] Push preferences load
- [ ] Individual preferences toggle
- [ ] Master toggle disables all
- [ ] Token unregisters on logout
- [ ] Deep link navigates correctly

### Customer Flow
- [ ] Customer login with magic link
- [ ] Multi-company selection works
- [ ] Customer sees only their orders
- [ ] Order timeline displays correctly
- [ ] Repair workflow stages correct
- [ ] Buyback workflow stages correct
- [ ] Technical report displays
- [ ] Device images load
- [ ] Pre-repair checklist displays
- [ ] Quote approval with typed signature
- [ ] Quote approval with drawn signature
- [ ] Quote rejection works
- [ ] Buyback collects bank details
- [ ] Customer can send messages
- [ ] Collection location displays
- [ ] 404 on other customer's orders

---

## Performance Targets

| Screen | Target Load Time |
|--------|-----------------|
| Dashboard | < 2 seconds |
| Device List | < 1 second (first page) |
| Order Detail | < 1 second |
| Ticket Thread | < 1 second |
| Customer Order List | < 1 second |

### Verify with Console

Monitor network requests in Xcode console:
- Request duration logged
- Response size logged
- Any warnings about slow requests

---

## Edge Cases

### Network Conditions
- [ ] Offline shows error state
- [ ] Slow network shows loading indicator
- [ ] Retry after failure works
- [ ] Token refresh during request works

### Data Edge Cases
- [ ] Empty lists display "no data" state
- [ ] Long text truncates properly
- [ ] Special characters (emoji, unicode) display
- [ ] Null optional fields handled
- [ ] Missing nested objects handled

### Auth Edge Cases
- [ ] Expired token triggers refresh
- [ ] Invalid refresh token shows login
- [ ] Concurrent requests during refresh queue properly
- [ ] Company suspension shows quarantine message

---

## Sign-Off Criteria

Before marking Stage 09 complete:

1. **Zero Decode Errors** - No `keyNotFound`, `typeMismatch`, or `valueNotFound` in console
2. **All Checklists Complete** - Every checkbox above verified
3. **Role Restrictions Verified** - Each role tested for proper access
4. **Customer Journey Complete** - Full flow from login to approval
5. **Performance Met** - All screens load within targets
6. **Push Notifications Work** - Token registers, preferences save
7. **No Regressions** - All previous stages still functional

---

## Quick Reference Commands

```bash
# Token validity check
curl -s "https://api.repairminder.com/api/dashboard/stats" -H "Authorization: Bearer TOKEN" | jq '.success'

# Clear rate limit
npx wrangler kv key delete "ratelimit:login:YOUR_IP" --namespace-id=57411dc0d8ef442db466a4e74c59ebb2

# Get test order
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT id, order_number FROM orders WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' LIMIT 1"

# Get test device
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT d.id, o.id as order_id, d.status FROM order_devices d JOIN orders o ON d.order_id = o.id WHERE o.company_id = '4b63c1e6ade1885e73171e10221cac53' LIMIT 1"

# Get test ticket
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT id, ticket_number FROM tickets WHERE company_id = '4b63c1e6ade1885e73171e10221cac53' LIMIT 1"
```
