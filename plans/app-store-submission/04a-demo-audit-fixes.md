# Demo Environment Seed Plan — Audit Report

**Audited:** 2026-02-06
**Plan file:** `04-demo-environment.md`
**Method:** Live D1 schema queries + backend source code review

---

## Summary

| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | Schema Verification | **PASS** | All 13 tables verified — every column exists, NOT NULL columns provided, types compatible |
| 2 | Foreign Key / Referential Integrity | **PASS** | All FK references resolve; INSERT order is correct |
| 3 | ID Collision Check | **PASS** | Zero `demo-` prefixed IDs in any production table (12 tables checked) |
| 4 | Security Audit | **PASS** | Bypass is exact-match only; existing `@repairminder.com` account unaffected |
| 5 | Data Consistency | **PASS** | All device/order/ticket statuses are internally consistent |
| 6 | Cleanup Safety | **PASS** | Deletes in correct FK order; WHERE clauses target only demo data |
| 7 | Customer Portal View | **PASS** | 3 orders for demo-client-001 cover active repair, pending quote, and completed order |

**Verdict: Safe to execute.** No issues found that would block execution.

---

## 1. Schema Verification (PASS)

Ran `SELECT name, sql FROM sqlite_master WHERE type='table'` for all 13 tables. Compared every column in every INSERT against the live schema.

| Table | Columns in INSERT | All exist? | NOT NULL satisfied? | Type OK? | UNIQUE OK? |
|-------|:-:|:-:|:-:|:-:|:-:|
| companies | 11 | Yes | Yes | Yes | Yes |
| company_locations | 13 | Yes | Yes | Yes | Yes |
| company_ticket_sequences | 2 | Yes | Yes | Yes | Yes |
| users | 17 | Yes | Yes | Yes | Yes |
| clients | 16 (varies) | Yes | Yes | Yes | Yes |
| tickets | 11 (varies) | Yes | Yes | Yes | Yes |
| ticket_messages | 7 (varies) | Yes | Yes | Yes | Yes |
| orders | 16 (varies) | Yes | Yes | Yes | Yes |
| order_devices | 25+ (varies) | Yes | Yes | Yes | Yes |
| order_items | 13 (varies) | Yes | Yes | Yes | Yes |
| order_payments | 8 | Yes | Yes | Yes | Yes |
| order_status_log | 6 | Yes | Yes | Yes | Yes |
| device_status_log | 7 | Yes | Yes | Yes | Yes |

### Key NOT NULL checks verified:
- `users.username` — provided as `'appstore-demo.repairminder'` (UNIQUE, confirmed not in production)
- `users.password` — provided as `''` (empty string, valid for magic-link-only users)
- `users.email` — UNIQUE, confirmed `appstore-demo@repairminder.com` not in production
- `clients.email` — part of `UNIQUE(company_id, email)`, no conflict since company is new
- `tickets.ticket_number` — part of `UNIQUE(company_id, ticket_number)`, no conflict since company is new
- `orders.ticket_id` — UNIQUE, all use demo ticket IDs that don't exist
- `users.phi_access_level` = `'full'` — valid per CHECK constraint `('none', 'limited', 'full')`
- `users.data_classification` = `'internal'` — valid per CHECK constraint `('public', 'internal', 'confidential', 'restricted')`

---

## 2. Foreign Key / Referential Integrity (PASS)

### INSERT order in the SQL script:
1. `companies` (no FK dependencies)
2. `company_locations` (FK → companies) ✓
3. `company_ticket_sequences` (FK → companies) ✓
4. `users` (FK → companies) ✓
5. `UPDATE companies SET admin_user_id` (user now exists) ✓
6. `clients` (FK → companies) ✓
7. `tickets` — order tickets (FK → companies, clients, users, company_locations) ✓
8. `tickets` — enquiry tickets (FK → companies, clients, company_locations) ✓
9. `ticket_messages` — enquiry messages (FK → tickets, users) ✓
10. `orders` (FK → companies, tickets, clients, company_locations, users) ✓
11. `order_devices` (FK → orders, users) ✓
12. `order_items` (FK → orders, users; `device_id` has no FK constraint) ✓
13. `order_payments` (FK → orders, users) ✓
14. `order_status_log` (FK → orders) ✓
15. `device_status_log` (FK → order_devices, orders) ✓
16. `ticket_messages` — order messages (FK → tickets, users) ✓

**Every FK reference resolves to an ID created earlier in the script.** No orphan references.

### Cross-reference verification:
| Reference | Source → Target | Valid? |
|-----------|----------------|:------:|
| `order_devices.order_id` → `orders.id` | All 8 devices point to valid orders | Yes |
| `order_items.device_id` → `order_devices.id` | All 14 items point to correct device for that order | Yes |
| `order_items.order_id` → `orders.id` | All items point to valid orders | Yes |
| `ticket_messages.ticket_id` → `tickets.id` | All 16 messages point to valid tickets | Yes |
| `orders.ticket_id` → `tickets.id` | All 7 orders point to unique tickets | Yes |
| `device_status_log.device_id` → `order_devices.id` | All 29 log entries point to valid devices | Yes |
| `order_status_log.order_id` → `orders.id` | All 11 log entries point to valid orders | Yes |

---

## 3. ID Collision Check (PASS)

Queried every table individually:

```
companies         WHERE id LIKE 'demo-%'    → 0
users             WHERE id LIKE 'demo-%'    → 0
clients           WHERE id LIKE 'demo-%'    → 0
tickets           WHERE id LIKE 'demo-%'    → 0
orders            WHERE id LIKE 'demo-%'    → 0
order_devices     WHERE id LIKE 'demo-%'    → 0
order_items       WHERE id LIKE 'demo-%'    → 0
order_payments    WHERE id LIKE 'demo-%'    → 0
order_status_log  WHERE id LIKE 'demo-%'    → 0
device_status_log WHERE id LIKE 'demo-%'    → 0
ticket_messages   WHERE id LIKE 'demo-%'    → 0
company_locations WHERE id LIKE 'demo-%'    → 0
```

### Additional collision checks:
- `users.username = 'appstore-demo.repairminder'` → **0 results** (no collision)
- `tickets WHERE ticket_number BETWEEN 100000001 AND 100000011` → **Many exist** in other companies, but `UNIQUE(company_id, ticket_number)` means **no conflict** since `demo-company-001` is new
- `company_ticket_sequences WHERE company_id = 'demo-company-001'` → **0 results** (no collision)

---

## 4. Security Audit (PASS)

### 4A. Staff bypass — `email.js:sendMagicLink()` (line 80)

**Current function signature:**
```javascript
async sendMagicLink(email, firstName, companyId, ipAddress = 'unknown')
```

**Planned bypass inserts at line 81** (top of try block, before rate limiting/email sending).

- Calls `this.updateMagicLinkToken(email, token, demoExpiry, demoCode)` — method confirmed to exist (called at line 104 in normal flow)
- Returns `{ token, magicCode, expiresAt }` — matches normal return shape
- Skips: rate limit check, email eligibility check, email sending
- Static code `123456` with 1-year expiry

**Verification:** `database.js:verifyMagicLinkCode()` (line 1625) checks:
```sql
WHERE email = ? AND magic_link_code = ? AND magic_link_expires > datetime('now') AND is_active = 1 AND deleted_at IS NULL
```
Demo user has `is_active = 1`, `deleted_at` will be NULL, code matches, expiry is far-future. **Will pass verification.** ✓

### 4B. Customer bypass — `customer-auth.js:requestMagicLink()` (line 19)

**Current function signature:**
```javascript
async requestMagicLink(email, companyId = null, request = null, domainCompanyId = null)
```

`effectiveCompanyId` is computed at line 23. Planned bypass inserts at line 25 (after effectiveCompanyId, before client lookup).

- Uses `this.db.getClientByEmailAndCompany()` and `this.db.getClientsByEmail()` — both confirmed in current code (lines 25-31)
- Calls `this.db.storeClientMagicCode()` — confirmed in current code (line 46)
- Returns generic message `'If an account exists, a login code has been sent'`

**Verification:** `database.js:verifyClientMagicCodeByEmail()` (line 2899) checks:
```sql
WHERE LOWER(email) = LOWER(?) AND magic_link_code = ? AND magic_link_expires > datetime('now')
```
Demo client has code `123456` with far-future expiry. **Will pass verification.** ✓

### 4C. Bypass scope — exact-match only

```javascript
const DEMO_ACCOUNTS = [
  'appstore-demo@repairminder.com',
  'appstore-customer@repairminder.com',
];
function isDemoAccount(email) {
  return email && DEMO_ACCOUNTS.includes(email.toLowerCase());
}
```

- Uses `Array.includes()` with exact string match — **NOT domain-wide**
- `.toLowerCase()` normalization prevents case-bypass attempts

### 4D. Existing @repairminder.com accounts in production

| Table | Email | Affected by bypass? |
|-------|-------|:---:|
| users | *(none found)* | N/A |
| clients | `test-coords@repairminder.com` | **No** — not in `DEMO_ACCOUNTS` array |

The existing `test-coords@repairminder.com` client cannot use code `123456`. **No production account is weakened.**

### 4E. Brute-force risk assessment

Code `123456` is static but:
- Only works for 2 hardcoded emails (not discoverable via the bypass)
- Normal rate limiting still applies to non-demo accounts
- Demo accounts bypass rate limiting only for their own code storage, not for verification attempts

---

## 5. Data Consistency (PASS)

### 5A. Device status vs. timestamp progression

| Device | Status | Timestamps set | Timestamps NOT set | Consistent? |
|--------|--------|---------------|-------------------|:-----------:|
| demo-device-001 | `repairing` | received, checked_in, diag_started, diag_completed, repair_started | repair_completed, quality_checked, ready_for_collection, collected | ✓ |
| demo-device-002 | `awaiting_authorisation` | received, checked_in, diag_started, diag_completed, report_sent | repair_started and beyond | ✓ |
| demo-device-003 | `collected` | ALL timestamps through collected_at | *(none missing)* | ✓ |
| demo-device-004 | `device_received` | received, checked_in | diag_started and beyond | ✓ |
| demo-device-005 | `diagnosing` | received, checked_in, diag_started | diag_completed and beyond | ✓ |
| demo-device-006 | `authorised_awaiting_parts` | received, checked_in, diag_started, diag_completed, report_authorised | repair_started and beyond | ✓ |
| demo-device-007 | `repaired_ready` | received through ready_for_collection | collected | ✓ |
| demo-device-008 | `repairing` | received, checked_in, diag_started, diag_completed, repair_started | repair_completed and beyond | ✓ |

All timestamps progress forward chronologically within each device. ✓

### 5B. Order status vs. device status

| Order | Order Status | Devices | Device Status(es) | Consistent? |
|-------|-------------|---------|-------------------|:-----------:|
| demo-order-001 | `in_progress` | device-001 | `repairing` | ✓ |
| demo-order-002 | `in_progress` | device-002 | `awaiting_authorisation` | ✓ |
| demo-order-003 | `collected_despatched` | device-003 | `collected` | ✓ |
| demo-order-004 | `in_progress` | device-004, device-005 | `device_received`, `diagnosing` | ✓ |
| demo-order-005 | `in_progress` | device-006 | `authorised_awaiting_parts` | ✓ |
| demo-order-006 | `service_complete` | device-007 | `repaired_ready` | ✓ |
| demo-order-007 | `in_progress` | device-008 | `repairing` | ✓ |

### 5C. Ticket status vs. order status

| Ticket | Ticket Status | Order Status | Consistent? |
|--------|-------------|-------------|:-----------:|
| demo-ticket-001 | `open` | `in_progress` | ✓ |
| demo-ticket-002 | `open` | `in_progress` | ✓ |
| demo-ticket-003 | `closed` | `collected_despatched` | ✓ |
| demo-ticket-004 | `open` | `in_progress` | ✓ |
| demo-ticket-005 | `open` | `in_progress` | ✓ |
| demo-ticket-006 | `open` | `service_complete` | ✓ (open until collected) |
| demo-ticket-007 | `open` | `in_progress` | ✓ |
| demo-ticket-enq-001 | `open` | N/A (enquiry) | ✓ |
| demo-ticket-enq-002 | `open` | N/A (enquiry) | ✓ |
| demo-ticket-enq-003 | `resolved` | N/A (enquiry) | ✓ |

### 5D. Status log coherence

**Order status logs** — each order's log tells a forward-progressing story:
- Order 1: → `in_progress` ✓
- Order 2: → `in_progress` ✓
- Order 3: → `in_progress` → `service_complete` → `awaiting_collection` → `collected_despatched` ✓
- Orders 4-7: → `in_progress` ✓
- Order 6: → `in_progress` → `service_complete` ✓

**Device status logs** — all 8 devices have coherent progression:
- Device 1: → `device_received` → `diagnosing` → `ready_to_repair` → `repairing` ✓
- Device 2: → `device_received` → `diagnosing` → `awaiting_authorisation` ✓
- Device 3: → `device_received` → `diagnosing` → `ready_to_repair` → `repairing` → `repaired_qc` → `repaired_ready` → `collected` ✓
- Device 4: → `device_received` ✓
- Device 5: → `device_received` → `diagnosing` ✓
- Device 6: → `device_received` → `diagnosing` → `authorised_awaiting_parts` ✓
- Device 7: → `device_received` → `diagnosing` → `ready_to_repair` → `repairing` → `repaired_qc` → `repaired_ready` ✓
- Device 8: → `device_received` → `diagnosing` → `repairing` ✓

**Note:** Device 8 skips `ready_to_repair` (goes `diagnosing` → `repairing` directly). This is plausible for a pre-approved device where the tech starts immediately, but differs from Device 1's path. Not a blocking issue.

### 5E. Order items → device cross-reference

| Order | Item device_id | Expected device for order | Match? |
|-------|---------------|--------------------------|:------:|
| demo-order-001 | demo-device-001 | iPhone 15 Pro | ✓ |
| demo-order-002 | demo-device-002 | iPad Air | ✓ |
| demo-order-003 | demo-device-003 | MacBook Pro | ✓ |
| demo-order-004 | demo-device-004 | Samsung Galaxy S24 | ✓ |
| demo-order-005 | demo-device-006 | iPhone 16 Pro Max | ✓ |
| demo-order-006 | demo-device-007 | MacBook Air | ✓ |
| demo-order-007 | demo-device-008 | Pixel 8 | ✓ |

Note: Order 4 has 2 devices (device-004 and device-005), but only device-004 has a line item (diagnostic fee). Device-005 (iPhone 14, still diagnosing) correctly has no line items yet.

### 5F. Payment verification

Order 3 payment: $379.00
Order 3 line items: $299.00 (part) + $80.00 (labour) = **$379.00** ✓

---

## 6. Cleanup Safety (PASS)

### DELETE order (children before parents):
```
1. device_status_log  (child of order_devices, orders)
2. order_status_log   (child of orders)
3. order_payments     (child of orders)
4. order_items        (child of orders)
5. order_devices      (child of orders)
6. ticket_messages    (child of tickets)
7. orders             (child of tickets, clients, companies)
8. tickets            (child of companies, clients)
9. clients            (child of companies)
10. users             (child of companies)
11. company_ticket_sequences (child of companies)
12. company_locations (child of companies)
13. companies         (root)
```

FK constraint order: **Correct** — all children deleted before parents. ✓

### WHERE clause safety:
| DELETE statement | WHERE clause | Could match non-demo data? |
|----------------|-------------|:-:|
| device_status_log | `device_id LIKE 'demo-device-%'` | No |
| order_status_log | `order_id LIKE 'demo-order-%'` | No |
| order_payments | `order_id LIKE 'demo-order-%'` | No |
| order_items | `order_id LIKE 'demo-order-%'` | No |
| order_devices | `order_id LIKE 'demo-order-%'` | No |
| ticket_messages | `ticket_id LIKE 'demo-ticket-%'` | No |
| orders | `id LIKE 'demo-order-%'` | No |
| tickets | `id LIKE 'demo-ticket-%'` | No |
| clients | `id LIKE 'demo-client-%'` | No |
| users | `id = 'demo-staff-001'` | No (exact match) |
| company_ticket_sequences | `company_id = 'demo-company-001'` | No (exact match) |
| company_locations | `id = 'demo-location-001'` | No (exact match) |
| companies | `id = 'demo-company-001'` | No (exact match) |

**No risk of deleting non-demo data.** All production IDs are UUIDs (hex), never prefixed with `demo-`. ✓

---

## 7. Customer Portal View (PASS)

Three orders visible to `demo-client-001` (Alex Thompson, the customer login):

| Order | Ticket # | Device | Status | Key Feature Demonstrated |
|-------|---------|--------|--------|------------------------|
| demo-order-001 | 100000001 | iPhone 15 Pro | `repairing` | Active repair with 3-message thread |
| demo-order-002 | 100000002 | iPad Air | `awaiting_authorisation` | Pending quote ($65 part + $35 labour = **$100**), auth_round=1, auth_status=`pending` |
| demo-order-003 | 100000003 | MacBook Pro 14" | `collected` | Complete timeline (7 status transitions), payment ($379), 2-message thread |

### Customer actions available:
- **Order 1:** View timeline, read/send messages ✓
- **Order 2:** Approve or reject the $100 quote ✓
- **Order 3:** View full repair history and timeline ✓

---

## Issues Found: None

The plan is thorough, schema-accurate, and safe to execute against production D1.

---

## Post-Audit Fixes (2026-02-06)

Two changes made to `04-demo-environment.md` for booking feature compatibility:

### Fix 1: Added `terms_conditions` to demo company INSERT

The booking wizard's signature step fetches company T&Cs from `/api/company/public-info`. Without `terms_conditions` set, the field would be NULL and the reviewer would see an empty terms section when testing the new booking flow. Added `terms_conditions` (realistic short repair shop terms) and `terms_conditions_updated_at` (set to `datetime('now', '-90 days')`, matching the company `created_at`).

### Fix 2: Replaced cleanup script with company-scoped deletes

The original cleanup used `WHERE id LIKE 'demo-%'` which only catches seeded records with demo-prefixed IDs. If the App Store reviewer creates a booking during testing, those records get regular UUID IDs and would be orphaned on cleanup. Replaced all deletes with `WHERE company_id = 'demo-company-001'` subquery scoping so every record belonging to the demo company is cleaned up, regardless of ID format. Also added `device_signatures` and `order_signatures` tables (used by the booking signature step) to the delete cascade.
