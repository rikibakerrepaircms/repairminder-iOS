# Stage 4: Demo Environment Setup — Implementation Plan

## Overview

Create a fully functional demo environment for Apple's App Review team. The reviewer logs in with static magic code `123456` (no email delivery needed) and sees realistic repair shop data.

**Two demo accounts:**
- **Staff:** `appstore-demo@repairminder.com` — admin of "Apple Review Demo Shop"
- **Customer:** `appstore-customer@repairminder.com` — client tracking their repairs

**Zero iOS changes required.** All changes are backend-only.

---

## Security Audit (verified 2026-02-06)

| Check | Result |
|-------|--------|
| Bypass scope | **Exact-match only** — only `appstore-demo@` and `appstore-customer@` get bypass. NOT domain-wide. |
| Existing `@repairminder.com` accounts | 1 client found: `test-coords@repairminder.com` (company `4b63c1e6...`). **Not affected** by exact-match bypass. |
| ID collisions | None — `demo-` prefix doesn't exist in any production table. |
| Brute-force risk | Code `123456` is static but only works for 2 hardcoded emails. Rate limiting still applies. |
| Data isolation | Demo company `demo-company-001` is fully separate — no cross-tenant data leakage. |
| Cleanup | All demo IDs use `demo-` prefix — single DELETE cascade cleans everything. |
| `users.username` NOT NULL | Fixed — set to `appstore-demo.repairminder` (unique, not nullable). |
| `users.password` NOT NULL | Fixed — set to `''` (empty string, consistent with other magic-link-only users). |

---

## Part 1: Backend Code Changes (2 files) ✅

### 1A. Helper function — `isDemoAccount`

Add to both `email.js` and `customer-auth.js` (or extract to a shared util):

```javascript
const DEMO_ACCOUNTS = [
  'appstore-demo@repairminder.com',
  'appstore-customer@repairminder.com',
];

function isDemoAccount(email) {
  return email && DEMO_ACCOUNTS.includes(email.toLowerCase());
}
```

**Why exact-match, not domain-wide?** There is an existing client `test-coords@repairminder.com` in production (company `4b63c1e6...`). A domain-wide `@repairminder.com` check would let anyone log in as that client with code `123456`. Exact matching limits the bypass to only the two demo accounts.

> **Security note:** Verified against production D1 on 2026-02-06 — no user or client accounts with these exact emails exist.

---

### 1B. Staff magic link bypass — `worker/src/email.js`

**File:** `/Volumes/Riki Repos/repairminder/worker/src/email.js`
**Function:** `sendMagicLink()` (line 80)

**Insert at line 81** (top of the try block, before rate limiting):

```javascript
// Demo account bypass — static code, skip email delivery
if (isDemoAccount(email)) {
  const demoCode = '123456';
  const demoExpiry = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000); // 1 year
  const token = crypto.randomUUID();
  await this.updateMagicLinkToken(email, token, demoExpiry.toISOString(), demoCode);
  console.log(`[Demo] Magic code set for staff demo account: ${email}`);
  return { token, magicCode: demoCode, expiresAt: demoExpiry };
}
```

**What this does:**
- Stores code `123456` in the `users` table with a 1-year expiry
- Skips rate limit checks, email sending, and all email tracking
- Returns immediately — the normal verification flow works unchanged

**Why it works:** `database.js:verifyMagicLinkCode()` (line 1625) checks `WHERE email = ? AND magic_link_code = ? AND magic_link_expires > datetime('now')`. Since we stored `123456` with a far-future expiry, the standard verification passes.

---

### 1C. Customer magic link bypass — `worker/src/customer-auth.js`

**File:** `/Volumes/Riki Repos/repairminder/worker/src/customer-auth.js`
**Function:** `requestMagicLink()` (line 19)

**Insert at line 25** (after `effectiveCompanyId` is computed, before the client lookup):

```javascript
// Demo account bypass — static code, skip email delivery
if (isDemoAccount(email)) {
  // Still need to look up the client to store the code
  const clients = effectiveCompanyId
    ? [await this.db.getClientByEmailAndCompany(email, effectiveCompanyId)].filter(Boolean)
    : await this.db.getClientsByEmail(email);

  if (clients.length > 0) {
    const demoCode = '123456';
    const demoExpiry = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000); // 1 year
    await this.db.storeClientMagicCode(clients[0].id, demoCode, demoExpiry.toISOString());
    console.log(`[Demo] Magic code set for customer demo account: ${email}`);
  }
  // Always return same message (don't reveal if account exists)
  return { message: 'If an account exists, a login code has been sent' };
}
```

**What this does:**
- Looks up the client record and stores code `123456` with a 1-year expiry
- Skips email sending entirely
- The normal `verifyCode()` flow works unchanged since `verifyClientMagicCodeByEmail()` finds a valid code

---

### 1D. Summary of code changes

| File | Function | Change |
|------|----------|--------|
| `worker/src/email.js` | `sendMagicLink()` | Add `isDemoAccount()` + early return — store static code `123456`, skip email |
| `worker/src/customer-auth.js` | `requestMagicLink()` | Add `isDemoAccount()` + early return — store static code `123456`, skip email |

**Verification functions remain UNTOUCHED:**
- `database.js:verifyMagicLinkCode()` — works as-is (code matches, expiry is far-future)
- `database.js:verifyClientMagicCodeByEmail()` — works as-is (same reason)
- `auth.js:verifyMagicLinkCode()` — works as-is (calls database, issues tokens normally)
- `customer-auth.js:verifyCode()` — works as-is (calls database, issues tokens normally)

---

## Part 2: D1 SQL Seed Script ✅

Run this after deploying the code changes. Execute from `/Volumes/Riki Repos/repairminder`:

```bash
npx wrangler d1 execute repairminder_database --remote --file=worker/seeds/seed-demo-data.sql
```

### File: `worker/seeds/seed-demo-data.sql`

```sql
-- ============================================================
-- REPAIR MINDER — App Store Review Demo Data
-- ============================================================
-- Run: npx wrangler d1 execute repairminder_database --remote --file=worker/seeds/seed-demo-data.sql
--
-- Creates:
--   1 company ("Apple Review Demo Shop")
--   1 staff user (admin)
--   1 company location
--   5 clients (1 is the demo customer)
--   10 tickets (7 order tickets + 3 enquiry tickets)
--   7 orders with line items
--   8 devices across various statuses
--   3 enquiry tickets with message threads
--   Status logs for timeline history
--   Dashboard-meaningful data (revenue, counts)
-- ============================================================

-- ==================== COMPANY ====================

INSERT INTO companies (id, name, status, is_active, currency_code, vat_rate_repair, vat_rate_device_sale, vat_rate_accessory, vat_rate_device_purchase, terms_conditions, terms_conditions_updated_at, created_at, updated_at)
VALUES (
  'demo-company-001',
  'Apple Review Demo Shop',
  'active',
  1,
  'USD',
  0.0,   -- 0% VAT as specified
  0.0,
  0.0,
  0.0,
  'By signing below, you agree that Apple Review Demo Shop may carry out the repair or service described on this order. All repairs are guaranteed for 90 days from the date of collection. Devices left uncollected for 30 days after notification may be recycled or disposed of. We are not responsible for data loss — please ensure your device is backed up before drop-off. Payment is due upon collection unless otherwise agreed in writing.',
  datetime('now', '-90 days'),
  datetime('now', '-90 days'),
  datetime('now')
);

-- ==================== COMPANY LOCATION ====================

INSERT INTO company_locations (id, company_id, name, is_primary, country_code, address_line_1, city, county, postcode, phone, email, created_at, updated_at)
VALUES (
  'demo-location-001',
  'demo-company-001',
  'Main Store',
  1,
  'US',
  '123 Repair Street',
  'San Francisco',
  'CA',
  '94102',
  '+1 (415) 555-0199',
  'shop@demo.repairminder.com',
  datetime('now', '-90 days'),
  datetime('now')
);

-- ==================== TICKET SEQUENCE ====================

INSERT INTO company_ticket_sequences (company_id, next_ticket_number)
VALUES ('demo-company-001', 100000011);

-- ==================== STAFF USER ====================

INSERT INTO users (id, email, username, password, first_name, last_name, company_id, role, is_active, verified, magic_link_enabled, magic_link_code, magic_link_expires, phi_access_level, data_classification, created_at, updated_at)
VALUES (
  'demo-staff-001',
  'appstore-demo@repairminder.com',
  'appstore-demo.repairminder',   -- username NOT NULL, must be unique
  '',                               -- password NOT NULL, empty for magic-link-only
  'Demo',
  'Admin',
  'demo-company-001',
  'admin',
  1,
  1,
  1,
  '123456',
  datetime('now', '+365 days'),
  'full',
  'internal',
  datetime('now', '-90 days'),
  datetime('now')
);

-- Set company admin
UPDATE companies SET admin_user_id = 'demo-staff-001' WHERE id = 'demo-company-001';

-- ==================== CLIENTS ====================

-- Client 1: Demo customer (logs in via customer portal)
INSERT INTO clients (id, company_id, email, name, first_name, last_name, phone, address_line_1, city, county, postcode, country, magic_link_code, magic_link_expires, created_at, updated_at)
VALUES (
  'demo-client-001',
  'demo-company-001',
  'appstore-customer@repairminder.com',
  'Alex Thompson',
  'Alex',
  'Thompson',
  '+1 (000) 000-0001',
  '456 Market Street, Apt 7B',
  'San Francisco',
  'CA',
  '94105',
  'United States',
  '123456',
  datetime('now', '+365 days'),
  datetime('now', '-60 days'),
  datetime('now')
);

-- Client 2
INSERT INTO clients (id, company_id, email, name, first_name, last_name, phone, address_line_1, city, county, postcode, country, created_at, updated_at)
VALUES (
  'demo-client-002',
  'demo-company-001',
  'sarah.johnson@appledemo.repairminder.com',
  'Sarah Johnson',
  'Sarah',
  'Johnson',
  '+1 (000) 000-0002',
  '789 Valencia Street',
  'San Francisco',
  'CA',
  '94110',
  'United States',
  datetime('now', '-45 days'),
  datetime('now')
);

-- Client 3
INSERT INTO clients (id, company_id, email, name, first_name, last_name, phone, address_line_1, city, county, postcode, country, created_at, updated_at)
VALUES (
  'demo-client-003',
  'demo-company-001',
  'michael.chen@appledemo.repairminder.com',
  'Michael Chen',
  'Michael',
  'Chen',
  '+1 (000) 000-0003',
  '321 Broadway',
  'Oakland',
  'CA',
  '94607',
  'United States',
  datetime('now', '-30 days'),
  datetime('now')
);

-- Client 4
INSERT INTO clients (id, company_id, email, name, first_name, last_name, phone, address_line_1, city, county, postcode, country, created_at, updated_at)
VALUES (
  'demo-client-004',
  'demo-company-001',
  'emma.williams@appledemo.repairminder.com',
  'Emma Williams',
  'Emma',
  'Williams',
  '+1 (000) 000-0004',
  '555 University Avenue',
  'Palo Alto',
  'CA',
  '94301',
  'United States',
  datetime('now', '-20 days'),
  datetime('now')
);

-- Client 5
INSERT INTO clients (id, company_id, email, name, first_name, last_name, phone, address_line_1, city, county, postcode, country, created_at, updated_at)
VALUES (
  'demo-client-005',
  'demo-company-001',
  'david.brown@appledemo.repairminder.com',
  'David Brown',
  'David',
  'Brown',
  '+1 (000) 000-0005',
  '900 First Street',
  'San Jose',
  'CA',
  '95113',
  'United States',
  datetime('now', '-15 days'),
  datetime('now')
);

-- ==================== TICKETS (for orders) ====================

-- Ticket 1: Alex's active repair (iPhone 15 Pro)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-001', 'demo-company-001', 'demo-client-001', 100000001, 'iPhone 15 Pro — Screen Replacement', 'open', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-5 days'), datetime('now'));

-- Ticket 2: Alex's pending quote (iPad Air)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-002', 'demo-company-001', 'demo-client-001', 100000002, 'iPad Air — Battery Replacement', 'open', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-3 days'), datetime('now'));

-- Ticket 3: Alex's completed repair (MacBook Pro)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-003', 'demo-company-001', 'demo-client-001', 100000003, 'MacBook Pro 14" — Keyboard Repair', 'closed', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-30 days'), datetime('now', '-14 days'));

-- Ticket 4: Sarah's water damage (Samsung)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-004', 'demo-company-001', 'demo-client-002', 100000004, 'Samsung Galaxy S24 — Water Damage', 'open', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-2 days'), datetime('now'));

-- Ticket 5: Michael's back glass (iPhone 16 Pro Max)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-005', 'demo-company-001', 'demo-client-003', 100000005, 'iPhone 16 Pro Max — Back Glass Replacement', 'open', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-4 days'), datetime('now'));

-- Ticket 6: Emma's SSD upgrade (MacBook Air)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-006', 'demo-company-001', 'demo-client-004', 100000006, 'MacBook Air M2 — SSD Upgrade', 'open', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-7 days'), datetime('now'));

-- Ticket 7: David's screen crack (Pixel 8)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, assigned_user_id, location_id, created_at, updated_at)
VALUES ('demo-ticket-007', 'demo-company-001', 'demo-client-005', 100000007, 'Google Pixel 8 — Cracked Screen', 'open', 'order', 'demo-staff-001', 'demo-location-001', datetime('now', '-3 days'), datetime('now'));

-- ==================== TICKETS (enquiries) ====================

-- Enquiry 1: Sarah asks about water damage timeline (open)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, location_id, created_at, updated_at)
VALUES ('demo-ticket-enq-001', 'demo-company-001', 'demo-client-002', 100000008, 'How long will the water damage assessment take?', 'open', 'enquiry', 'demo-location-001', datetime('now', '-1 day'), datetime('now'));

-- Enquiry 2: Michael asks about parts availability (open)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, location_id, created_at, updated_at)
VALUES ('demo-ticket-enq-002', 'demo-company-001', 'demo-client-003', 100000009, 'Do you have the back glass in stock?', 'open', 'enquiry', 'demo-location-001', datetime('now', '-2 days'), datetime('now'));

-- Enquiry 3: Emma asks about collection (resolved)
INSERT INTO tickets (id, company_id, client_id, ticket_number, subject, status, ticket_type, location_id, created_at, updated_at)
VALUES ('demo-ticket-enq-003', 'demo-company-001', 'demo-client-004', 100000010, 'Is my MacBook ready for collection?', 'resolved', 'enquiry', 'demo-location-001', datetime('now', '-3 days'), datetime('now', '-1 day'));

-- ==================== ENQUIRY MESSAGES ====================

-- Enquiry 1 messages (Sarah — water damage)
INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-enq-001a', 'demo-ticket-enq-001', 'inbound', 'sarah.johnson@appledemo.repairminder.com', 'Sarah Johnson',
  'Hi, I dropped off my Samsung Galaxy S24 yesterday for water damage assessment. Could you let me know how long the diagnostic usually takes? I need my phone for work. Thanks!',
  datetime('now', '-1 day'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-enq-001b', 'demo-ticket-enq-001', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Hi Sarah, thanks for reaching out! Water damage diagnostics typically take 24-48 hours as we need to fully assess all internal components. We''ll have a detailed report ready for you by tomorrow afternoon. We''ll send you an update as soon as we know more.',
  'demo-staff-001',
  datetime('now', '-23 hours'));

-- Enquiry 2 messages (Michael — parts stock)
INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-enq-002a', 'demo-ticket-enq-002', 'inbound', 'michael.chen@appledemo.repairminder.com', 'Michael Chen',
  'Hello, I have an iPhone 16 Pro Max with a cracked back glass. Do you have the replacement part in stock, or will it need to be ordered? Just trying to plan ahead.',
  datetime('now', '-2 days'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-enq-002b', 'demo-ticket-enq-002', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Hi Michael! We''ve placed the order for the back glass panel — it''s a genuine OEM part. Expected delivery is within 2-3 business days. We''ll notify you as soon as it arrives and start the repair right away.',
  'demo-staff-001',
  datetime('now', '-1 day', '-12 hours'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-enq-002c', 'demo-ticket-enq-002', 'inbound', 'michael.chen@appledemo.repairminder.com', 'Michael Chen',
  'Great, thanks for the quick response! I appreciate you sourcing the OEM part.',
  datetime('now', '-1 day', '-6 hours'));

-- Enquiry 3 messages (Emma — collection, resolved)
INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-enq-003a', 'demo-ticket-enq-003', 'inbound', 'emma.williams@appledemo.repairminder.com', 'Emma Williams',
  'Hi there, just checking — is my MacBook Air ready for collection? I saw the status changed to "Repaired" but wasn''t sure if there was anything else needed before I pick it up.',
  datetime('now', '-3 days'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-enq-003b', 'demo-ticket-enq-003', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Hi Emma! Yes, your MacBook Air is all done and ready for pickup. The SSD upgrade went smoothly — you should notice a big improvement in speed. We''re open until 6 PM today and 9 AM - 5 PM tomorrow. See you soon!',
  'demo-staff-001',
  datetime('now', '-2 days', '-18 hours'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-enq-003c', 'demo-ticket-enq-003', 'inbound', 'emma.williams@appledemo.repairminder.com', 'Emma Williams',
  'Perfect, I''ll swing by this afternoon. Thanks for the fast turnaround!',
  datetime('now', '-2 days', '-12 hours'));

-- ==================== ORDERS ====================

-- Order 1: Alex — iPhone 15 Pro screen (in progress, device repairing)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, authorisation_type, created_at, updated_at, created_by)
VALUES ('demo-order-001', 'demo-company-001', 'demo-ticket-001', 'demo-client-001', 'demo-location-001', 'demo-staff-001', 'walk_in', 'in_progress', 'pre_approved', datetime('now', '-5 days'), datetime('now'), 'demo-staff-001');

-- Order 2: Alex — iPad Air battery (in progress, device awaiting authorisation — this is the quote for customer to approve)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, authorisation_type, quote_sent_at, created_at, updated_at, created_by)
VALUES ('demo-order-002', 'demo-company-001', 'demo-ticket-002', 'demo-client-001', 'demo-location-001', 'demo-staff-001', 'walk_in', 'in_progress', 'quote_required', datetime('now', '-1 day'), datetime('now', '-3 days'), datetime('now'), 'demo-staff-001');

-- Order 3: Alex — MacBook Pro keyboard (completed, collected)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, authorisation_type, authorised_at, service_completed_at, collected_at, created_at, updated_at, created_by)
VALUES ('demo-order-003', 'demo-company-001', 'demo-ticket-003', 'demo-client-001', 'demo-location-001', 'demo-staff-001', 'walk_in', 'collected_despatched', 'pre_approved', datetime('now', '-28 days'), datetime('now', '-18 days'), datetime('now', '-14 days'), datetime('now', '-30 days'), datetime('now', '-14 days'), 'demo-staff-001');

-- Order 4: Sarah — Samsung Galaxy S24 water damage (in progress, device just received)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, created_at, updated_at, created_by)
VALUES ('demo-order-004', 'demo-company-001', 'demo-ticket-004', 'demo-client-002', 'demo-location-001', 'demo-staff-001', 'walk_in', 'in_progress', datetime('now', '-2 days'), datetime('now'), 'demo-staff-001');

-- Order 5: Michael — iPhone 16 Pro Max back glass (in progress, awaiting parts)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, authorisation_type, authorised_at, created_at, updated_at, created_by)
VALUES ('demo-order-005', 'demo-company-001', 'demo-ticket-005', 'demo-client-003', 'demo-location-001', 'demo-staff-001', 'walk_in', 'in_progress', 'pre_approved', datetime('now', '-3 days'), datetime('now', '-4 days'), datetime('now'), 'demo-staff-001');

-- Order 6: Emma — MacBook Air SSD upgrade (service complete, ready for pickup)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, authorisation_type, authorised_at, service_completed_at, created_at, updated_at, created_by)
VALUES ('demo-order-006', 'demo-company-001', 'demo-ticket-006', 'demo-client-004', 'demo-location-001', 'demo-staff-001', 'walk_in', 'service_complete', 'pre_approved', datetime('now', '-6 days'), datetime('now', '-1 day'), datetime('now', '-7 days'), datetime('now'), 'demo-staff-001');

-- Order 7: David — Pixel 8 screen (in progress, repairing)
INSERT INTO orders (id, company_id, ticket_id, client_id, location_id, assigned_user_id, intake_method, status, authorisation_type, authorised_at, created_at, updated_at, created_by)
VALUES ('demo-order-007', 'demo-company-001', 'demo-ticket-007', 'demo-client-005', 'demo-location-001', 'demo-staff-001', 'walk_in', 'in_progress', 'pre_approved', datetime('now', '-2 days'), datetime('now', '-3 days'), datetime('now'), 'demo-staff-001');

-- ==================== DEVICES ====================

-- Device 1: Alex's iPhone 15 Pro (repairing — screen replacement)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, repair_notes, received_at, checked_in_at, diagnosis_started_at, diagnosis_completed_at, repair_started_at, created_by, created_at, updated_at)
VALUES ('demo-device-001', 'demo-order-001', 'Apple', 'iPhone 15 Pro', 'F2LZF1234567', 'Natural Titanium', '256GB', 'repairing', 'approved', 'demo-staff-001', 'normal',
  'Cracked screen — dropped on concrete. Touch still works but display has visible cracks across the top half.',
  'Display assembly damaged. LCD and digitizer need full replacement. No internal damage detected.',
  'OEM display installed. Calibrating True Tone...',
  datetime('now', '-5 days'), datetime('now', '-5 days'), datetime('now', '-4 days'), datetime('now', '-3 days'), datetime('now', '-2 days'),
  'demo-staff-001', datetime('now', '-5 days'), datetime('now'));

-- Device 2: Alex's iPad Air (awaiting_authorisation — the quote pending approval)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, received_at, checked_in_at, diagnosis_started_at, diagnosis_completed_at, report_sent_at, current_authorization_round, created_by, created_at, updated_at)
VALUES ('demo-device-002', 'demo-order-002', 'Apple', 'iPad Air (5th Gen)', 'DLXQ91234567', 'Space Gray', '64GB', 'awaiting_authorisation', 'pending', 'demo-staff-001', 'normal',
  'Battery drains very fast — goes from 100% to 0% in about 3 hours. Sometimes shuts off at 20%.',
  'Battery health at 71%. Cycle count 847. Recommend full battery replacement. No other issues found.',
  datetime('now', '-3 days'), datetime('now', '-3 days'), datetime('now', '-2 days'), datetime('now', '-1 day'), datetime('now', '-1 day'), 1,
  'demo-staff-001', datetime('now', '-3 days'), datetime('now'));

-- Device 3: Alex's MacBook Pro (collected — completed repair)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, repair_notes, received_at, checked_in_at, diagnosis_started_at, diagnosis_completed_at, repair_started_at, repair_completed_at, quality_checked_at, ready_for_collection_at, collected_at, created_by, created_at, updated_at)
VALUES ('demo-device-003', 'demo-order-003', 'Apple', 'MacBook Pro 14" (M3)', 'C02ZN1234567', 'Space Black', '512GB', 'collected', 'approved', 'demo-staff-001', 'normal',
  'Several keys are sticky and unresponsive — especially the spacebar and E key. Happened after a small coffee spill.',
  'Liquid damage to keyboard assembly. Top case replacement recommended (keyboard is integrated).',
  'Top case replaced with new keyboard assembly. All keys tested and functioning. Trackpad and speakers verified working.',
  datetime('now', '-30 days'), datetime('now', '-30 days'), datetime('now', '-29 days'), datetime('now', '-28 days'), datetime('now', '-25 days'), datetime('now', '-20 days'), datetime('now', '-19 days'), datetime('now', '-18 days'), datetime('now', '-14 days'),
  'demo-staff-001', datetime('now', '-30 days'), datetime('now', '-14 days'));

-- Device 4: Sarah's Samsung Galaxy S24 (device_received — just checked in)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, imei, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, received_at, checked_in_at, created_by, created_at, updated_at)
VALUES ('demo-device-004', 'demo-order-004', 'Samsung', 'Galaxy S24', 'R5CTA1234567', '354123456789012', 'Amber Yellow', '128GB', 'device_received', 'pending', 'demo-staff-001', 'high',
  'Phone fell into a pool. Was submerged for about 30 seconds. Screen flickers and speaker is muffled.',
  datetime('now', '-2 days'), datetime('now', '-2 days'),
  'demo-staff-001', datetime('now', '-2 days'), datetime('now'));

-- Device 5: Sarah's iPhone 14 (diagnosing — secondary device)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, received_at, checked_in_at, diagnosis_started_at, created_by, created_at, updated_at)
VALUES ('demo-device-005', 'demo-order-004', 'Apple', 'iPhone 14', 'F17YN1234567', 'Midnight', '128GB', 'diagnosing', 'pending', 'demo-staff-001', 'normal',
  'Won''t turn on at all. Was working fine yesterday, went to charge it overnight and it just won''t power up.',
  'Initial inspection: no visible damage. Checking charging port and battery connections...',
  datetime('now', '-2 days'), datetime('now', '-2 days'), datetime('now', '-1 day'),
  'demo-staff-001', datetime('now', '-2 days'), datetime('now'));

-- Device 6: Michael's iPhone 16 Pro Max (authorised_awaiting_parts)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, received_at, checked_in_at, diagnosis_started_at, diagnosis_completed_at, report_authorised_at, created_by, created_at, updated_at)
VALUES ('demo-device-006', 'demo-order-005', 'Apple', 'iPhone 16 Pro Max', 'GN8YQ1234567', 'Desert Titanium', '512GB', 'authorised_awaiting_parts', 'approved', 'demo-staff-001', 'normal',
  'Back glass is shattered. Phone still works perfectly, just cosmetic damage from a drop.',
  'Back panel cracked in multiple places. Frame has minor scuffing but no structural damage. All sensors and cameras functional.',
  datetime('now', '-4 days'), datetime('now', '-4 days'), datetime('now', '-3 days'), datetime('now', '-3 days'), datetime('now', '-2 days'),
  'demo-staff-001', datetime('now', '-4 days'), datetime('now'));

-- Device 7: Emma's MacBook Air (repaired_ready — ready for pickup)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, repair_notes, received_at, checked_in_at, diagnosis_started_at, diagnosis_completed_at, repair_started_at, repair_completed_at, quality_checked_at, ready_for_collection_at, created_by, created_at, updated_at)
VALUES ('demo-device-007', 'demo-order-006', 'Apple', 'MacBook Air 15" (M2)', 'FVFGH1234567', 'Midnight', '256GB', 'repaired_ready', 'approved', 'demo-staff-001', 'normal',
  'Running out of storage constantly. Would like to upgrade the SSD if possible.',
  'Current SSD: 256GB Apple module. Compatible with 512GB/1TB aftermarket NVMe modules. Recommend 1TB upgrade.',
  'Replaced 256GB module with 1TB NVMe SSD. macOS reinstalled from recovery. Migration assistant used to restore data. All benchmarks passing — read/write speeds excellent.',
  datetime('now', '-7 days'), datetime('now', '-7 days'), datetime('now', '-6 days'), datetime('now', '-6 days'), datetime('now', '-4 days'), datetime('now', '-2 days'), datetime('now', '-1 day'), datetime('now', '-1 day'),
  'demo-staff-001', datetime('now', '-7 days'), datetime('now'));

-- Device 8: David's Google Pixel 8 (repairing)
INSERT INTO order_devices (id, order_id, custom_brand, custom_model, serial_number, colour, storage_capacity, status, authorization_status, assigned_engineer_id, priority, customer_reported_issues, diagnosis_notes, repair_notes, received_at, checked_in_at, diagnosis_started_at, diagnosis_completed_at, repair_started_at, created_by, created_at, updated_at)
VALUES ('demo-device-008', 'demo-order-007', 'Google', 'Pixel 8', 'GA0A91234567', 'Obsidian', '128GB', 'repairing', 'approved', 'demo-staff-001', 'normal',
  'Dropped phone face-down. Screen is cracked from corner to corner. Touch works in some areas but not others.',
  'OLED panel cracked with dead zones in upper-right quadrant. Digitizer partially functional. Full display assembly replacement required.',
  'Removing old display assembly. Adhesive heating in progress...',
  datetime('now', '-3 days'), datetime('now', '-3 days'), datetime('now', '-2 days'), datetime('now', '-2 days'), datetime('now', '-1 day'),
  'demo-staff-001', datetime('now', '-3 days'), datetime('now'));

-- ==================== ORDER ITEMS (line items) ====================

-- Order 1: iPhone 15 Pro screen replacement
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, created_at, created_by)
VALUES
  ('demo-item-001a', 'demo-order-001', 'part', 'iPhone 15 Pro OLED Display Assembly (OEM)', 1, 189.00, 0.0, 'demo-device-001', 189.00, 0.00, 189.00, datetime('now', '-3 days'), 'demo-staff-001'),
  ('demo-item-001b', 'demo-order-001', 'labour', 'Screen Replacement Labour', 1, 45.00, 0.0, 'demo-device-001', 45.00, 0.00, 45.00, datetime('now', '-3 days'), 'demo-staff-001');

-- Order 2: iPad Air battery replacement (the quote)
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, authorization_round, created_at, created_by)
VALUES
  ('demo-item-002a', 'demo-order-002', 'part', 'iPad Air Battery Cell (OEM Compatible)', 1, 65.00, 0.0, 'demo-device-002', 65.00, 0.00, 65.00, 1, datetime('now', '-1 day'), 'demo-staff-001'),
  ('demo-item-002b', 'demo-order-002', 'labour', 'Battery Replacement Labour', 1, 35.00, 0.0, 'demo-device-002', 35.00, 0.00, 35.00, 1, datetime('now', '-1 day'), 'demo-staff-001');

-- Order 3: MacBook Pro keyboard (completed)
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, created_at, created_by)
VALUES
  ('demo-item-003a', 'demo-order-003', 'part', 'MacBook Pro 14" Top Case with Keyboard (M3)', 1, 299.00, 0.0, 'demo-device-003', 299.00, 0.00, 299.00, datetime('now', '-25 days'), 'demo-staff-001'),
  ('demo-item-003b', 'demo-order-003', 'labour', 'Top Case Replacement Labour', 1, 80.00, 0.0, 'demo-device-003', 80.00, 0.00, 80.00, datetime('now', '-25 days'), 'demo-staff-001');

-- Order 4: Samsung water damage diagnostic + iPhone 14 diagnostic
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, created_at, created_by)
VALUES
  ('demo-item-004a', 'demo-order-004', 'labour', 'Water Damage Diagnostic Fee', 1, 30.00, 0.0, 'demo-device-004', 30.00, 0.00, 30.00, datetime('now', '-2 days'), 'demo-staff-001'),
  ('demo-item-004b', 'demo-order-004', 'labour', 'No-Power Diagnostic Fee', 1, 25.00, 0.0, 'demo-device-005', 25.00, 0.00, 25.00, datetime('now', '-2 days'), 'demo-staff-001');

-- Order 5: iPhone 16 Pro Max back glass
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, created_at, created_by)
VALUES
  ('demo-item-005a', 'demo-order-005', 'part', 'iPhone 16 Pro Max Rear Glass Panel (OEM)', 1, 79.00, 0.0, 'demo-device-006', 79.00, 0.00, 79.00, datetime('now', '-3 days'), 'demo-staff-001'),
  ('demo-item-005b', 'demo-order-005', 'labour', 'Back Glass Replacement Labour', 1, 40.00, 0.0, 'demo-device-006', 40.00, 0.00, 40.00, datetime('now', '-3 days'), 'demo-staff-001');

-- Order 6: MacBook Air SSD upgrade
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, created_at, created_by)
VALUES
  ('demo-item-006a', 'demo-order-006', 'part', '1TB NVMe SSD Module (MacBook Air Compatible)', 1, 149.00, 0.0, 'demo-device-007', 149.00, 0.00, 149.00, datetime('now', '-4 days'), 'demo-staff-001'),
  ('demo-item-006b', 'demo-order-006', 'labour', 'SSD Upgrade + macOS Reinstall + Data Migration', 1, 60.00, 0.0, 'demo-device-007', 60.00, 0.00, 60.00, datetime('now', '-4 days'), 'demo-staff-001');

-- Order 7: Pixel 8 screen replacement
INSERT INTO order_items (id, order_id, item_type, description, quantity, unit_price, vat_rate, device_id, line_total, vat_amount, line_total_inc_vat, created_at, created_by)
VALUES
  ('demo-item-007a', 'demo-order-007', 'part', 'Google Pixel 8 OLED Display Assembly', 1, 129.00, 0.0, 'demo-device-008', 129.00, 0.00, 129.00, datetime('now', '-2 days'), 'demo-staff-001'),
  ('demo-item-007b', 'demo-order-007', 'labour', 'Screen Replacement Labour', 1, 35.00, 0.0, 'demo-device-008', 35.00, 0.00, 35.00, datetime('now', '-2 days'), 'demo-staff-001');

-- ==================== ORDER PAYMENTS (for completed order) ====================

INSERT INTO order_payments (id, order_id, amount, payment_method, payment_date, notes, recorded_by, created_at)
VALUES ('demo-payment-001', 'demo-order-003', 379.00, 'card', datetime('now', '-14 days'), 'Visa ending 4242', 'demo-staff-001', datetime('now', '-14 days'));

-- ==================== ORDER STATUS LOG (timeline for customer view) ====================

-- Order 1 (Alex iPhone) status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-001a', 'demo-order-001', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-5 days'));

-- Order 2 (Alex iPad) status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-002a', 'demo-order-002', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-3 days'));

-- Order 3 (Alex MacBook) full status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-003a', 'demo-order-003', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-30 days')),
  ('demo-osl-003b', 'demo-order-003', 'in_progress', 'service_complete', 'demo-staff-001', datetime('now', '-18 days')),
  ('demo-osl-003c', 'demo-order-003', 'service_complete', 'awaiting_collection', 'demo-staff-001', datetime('now', '-18 days')),
  ('demo-osl-003d', 'demo-order-003', 'awaiting_collection', 'collected_despatched', 'demo-staff-001', datetime('now', '-14 days'));

-- Order 4 (Sarah Samsung) status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-004a', 'demo-order-004', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-2 days'));

-- Order 5 (Michael iPhone 16 Pro Max) status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-005a', 'demo-order-005', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-4 days'));

-- Order 6 (Emma MacBook Air) status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-006a', 'demo-order-006', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-7 days')),
  ('demo-osl-006b', 'demo-order-006', 'in_progress', 'service_complete', 'demo-staff-001', datetime('now', '-1 day'));

-- Order 7 (David Pixel 8) status history
INSERT INTO order_status_log (id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-osl-007a', 'demo-order-007', NULL, 'in_progress', 'demo-staff-001', datetime('now', '-3 days'));

-- ==================== DEVICE STATUS LOG (timeline for customer view) ====================

-- Device 1 (Alex iPhone 15 Pro) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-001a', 'demo-device-001', 'demo-order-001', NULL, 'device_received', 'demo-staff-001', datetime('now', '-5 days')),
  ('demo-dsl-001b', 'demo-device-001', 'demo-order-001', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-4 days')),
  ('demo-dsl-001c', 'demo-device-001', 'demo-order-001', 'diagnosing', 'ready_to_repair', 'demo-staff-001', datetime('now', '-3 days')),
  ('demo-dsl-001d', 'demo-device-001', 'demo-order-001', 'ready_to_repair', 'repairing', 'demo-staff-001', datetime('now', '-2 days'));

-- Device 2 (Alex iPad Air) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-002a', 'demo-device-002', 'demo-order-002', NULL, 'device_received', 'demo-staff-001', datetime('now', '-3 days')),
  ('demo-dsl-002b', 'demo-device-002', 'demo-order-002', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-2 days')),
  ('demo-dsl-002c', 'demo-device-002', 'demo-order-002', 'diagnosing', 'awaiting_authorisation', 'demo-staff-001', datetime('now', '-1 day'));

-- Device 3 (Alex MacBook Pro) full history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-003a', 'demo-device-003', 'demo-order-003', NULL, 'device_received', 'demo-staff-001', datetime('now', '-30 days')),
  ('demo-dsl-003b', 'demo-device-003', 'demo-order-003', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-29 days')),
  ('demo-dsl-003c', 'demo-device-003', 'demo-order-003', 'diagnosing', 'ready_to_repair', 'demo-staff-001', datetime('now', '-28 days')),
  ('demo-dsl-003d', 'demo-device-003', 'demo-order-003', 'ready_to_repair', 'repairing', 'demo-staff-001', datetime('now', '-25 days')),
  ('demo-dsl-003e', 'demo-device-003', 'demo-order-003', 'repairing', 'repaired_qc', 'demo-staff-001', datetime('now', '-20 days')),
  ('demo-dsl-003f', 'demo-device-003', 'demo-order-003', 'repaired_qc', 'repaired_ready', 'demo-staff-001', datetime('now', '-19 days')),
  ('demo-dsl-003g', 'demo-device-003', 'demo-order-003', 'repaired_ready', 'collected', 'demo-staff-001', datetime('now', '-14 days'));

-- Device 4 (Sarah Samsung) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-004a', 'demo-device-004', 'demo-order-004', NULL, 'device_received', 'demo-staff-001', datetime('now', '-2 days'));

-- Device 5 (Sarah iPhone 14) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-005a', 'demo-device-005', 'demo-order-004', NULL, 'device_received', 'demo-staff-001', datetime('now', '-2 days')),
  ('demo-dsl-005b', 'demo-device-005', 'demo-order-004', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-1 day'));

-- Device 6 (Michael iPhone 16 Pro Max) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-006a', 'demo-device-006', 'demo-order-005', NULL, 'device_received', 'demo-staff-001', datetime('now', '-4 days')),
  ('demo-dsl-006b', 'demo-device-006', 'demo-order-005', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-3 days')),
  ('demo-dsl-006c', 'demo-device-006', 'demo-order-005', 'diagnosing', 'authorised_awaiting_parts', 'demo-staff-001', datetime('now', '-2 days'));

-- Device 7 (Emma MacBook Air) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-007a', 'demo-device-007', 'demo-order-006', NULL, 'device_received', 'demo-staff-001', datetime('now', '-7 days')),
  ('demo-dsl-007b', 'demo-device-007', 'demo-order-006', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-6 days')),
  ('demo-dsl-007c', 'demo-device-007', 'demo-order-006', 'diagnosing', 'ready_to_repair', 'demo-staff-001', datetime('now', '-6 days')),
  ('demo-dsl-007d', 'demo-device-007', 'demo-order-006', 'ready_to_repair', 'repairing', 'demo-staff-001', datetime('now', '-4 days')),
  ('demo-dsl-007e', 'demo-device-007', 'demo-order-006', 'repairing', 'repaired_qc', 'demo-staff-001', datetime('now', '-2 days')),
  ('demo-dsl-007f', 'demo-device-007', 'demo-order-006', 'repaired_qc', 'repaired_ready', 'demo-staff-001', datetime('now', '-1 day'));

-- Device 8 (David Pixel 8) history
INSERT INTO device_status_log (id, device_id, order_id, old_status, new_status, changed_by, created_at)
VALUES
  ('demo-dsl-008a', 'demo-device-008', 'demo-order-007', NULL, 'device_received', 'demo-staff-001', datetime('now', '-3 days')),
  ('demo-dsl-008b', 'demo-device-008', 'demo-order-007', 'device_received', 'diagnosing', 'demo-staff-001', datetime('now', '-2 days')),
  ('demo-dsl-008c', 'demo-device-008', 'demo-order-007', 'diagnosing', 'ready_to_repair', 'demo-staff-001', datetime('now', '-2 days')),
  ('demo-dsl-008d', 'demo-device-008', 'demo-order-007', 'ready_to_repair', 'repairing', 'demo-staff-001', datetime('now', '-1 day'));

-- ==================== CUSTOMER-FACING MESSAGES (on order tickets) ====================

-- Messages on Alex's iPhone order (Order 1)
INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-ord-001a', 'demo-ticket-001', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Hi Alex, we''ve received your iPhone 15 Pro and started the diagnostic. We''ll have an update for you shortly.',
  'demo-staff-001', datetime('now', '-5 days'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-ord-001b', 'demo-ticket-001', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Good news — the screen replacement part has arrived and we''ve started the repair. Should be done within 24 hours!',
  'demo-staff-001', datetime('now', '-2 days'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-ord-001c', 'demo-ticket-001', 'inbound', 'appstore-customer@repairminder.com', 'Alex Thompson',
  'Thanks for the update! Looking forward to getting it back.',
  datetime('now', '-1 day', '-18 hours'));

-- Messages on Alex's iPad quote (Order 2)
INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-ord-002a', 'demo-ticket-002', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Hi Alex, we''ve completed the diagnostic on your iPad Air. The battery health is at 71% with 847 charge cycles — definitely time for a replacement. We''ve sent you a quote for your approval.',
  'demo-staff-001', datetime('now', '-1 day'));

-- Messages on Alex's completed MacBook order (Order 3)
INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_by_user_id, created_at)
VALUES ('demo-msg-ord-003a', 'demo-ticket-003', 'outbound', 'shop@demo.repairminder.com', 'Apple Review Demo Shop',
  'Hi Alex, your MacBook Pro is ready for collection! The keyboard has been fully replaced and all keys are working perfectly. We''re open until 6 PM today.',
  'demo-staff-001', datetime('now', '-18 days'));

INSERT INTO ticket_messages (id, ticket_id, type, from_email, from_name, body_text, created_at)
VALUES ('demo-msg-ord-003b', 'demo-ticket-003', 'inbound', 'appstore-customer@repairminder.com', 'Alex Thompson',
  'Great, I''ll come by this afternoon to pick it up. Thanks!',
  datetime('now', '-17 days'));

-- ============================================================
-- VERIFICATION QUERIES (run after seeding to confirm)
-- ============================================================
-- SELECT COUNT(*) as clients FROM clients WHERE company_id = 'demo-company-001';
-- SELECT COUNT(*) as orders FROM orders WHERE company_id = 'demo-company-001';
-- SELECT COUNT(*) as devices FROM order_devices WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
-- SELECT status, COUNT(*) FROM order_devices WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001') GROUP BY status;
-- SELECT COUNT(*) as enquiries FROM tickets WHERE company_id = 'demo-company-001' AND ticket_type = 'enquiry';
-- SELECT COUNT(*) as messages FROM ticket_messages WHERE ticket_id IN (SELECT id FROM tickets WHERE company_id = 'demo-company-001');
```

---

## Part 3: Execution Steps

### Step 1: Create the seed SQL file

Save the SQL above to: `worker/seeds/seed-demo-data.sql`

### Step 2: Add the code bypass to email.js

**File:** `worker/src/email.js`, function `sendMagicLink()` (line 80)

Add the helper constant near the top of the file (after imports), then add the bypass inside `sendMagicLink()`:

```javascript
// Near top of file, after imports
const DEMO_ACCOUNTS = ['appstore-demo@repairminder.com', 'appstore-customer@repairminder.com'];
function isDemoAccount(email) {
  return email && DEMO_ACCOUNTS.includes(email.toLowerCase());
}

// Inside sendMagicLink(), first thing in the try block:
async sendMagicLink(email, firstName, companyId, ipAddress = 'unknown') {
    try {
      // Demo account bypass — static code, skip email delivery
      if (isDemoAccount(email)) {
        const demoCode = '123456';
        const demoExpiry = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
        const token = crypto.randomUUID();
        await this.updateMagicLinkToken(email, token, demoExpiry.toISOString(), demoCode);
        console.log(`[Demo] Magic code set for staff demo account: ${email}`);
        return { token, magicCode: demoCode, expiresAt: demoExpiry };
      }

      // Check if user can receive emails (not archived)
      // ... rest of existing code unchanged
```

### Step 3: Add the code bypass to customer-auth.js

**File:** `worker/src/customer-auth.js`, function `requestMagicLink()` (line 19)

Add the helper constant near the top of the file (after imports), then add the bypass inside `requestMagicLink()`:

```javascript
// Near top of file, after imports
const DEMO_ACCOUNTS = ['appstore-demo@repairminder.com', 'appstore-customer@repairminder.com'];
function isDemoAccount(email) {
  return email && DEMO_ACCOUNTS.includes(email.toLowerCase());
}

// Inside requestMagicLink(), after effectiveCompanyId:
async requestMagicLink(email, companyId = null, request = null, domainCompanyId = null) {
    let clients;

    // If on custom domain, enforce domain's company
    const effectiveCompanyId = domainCompanyId || companyId;

    // Demo account bypass — static code, skip email delivery
    if (isDemoAccount(email)) {
      const demoClients = effectiveCompanyId
        ? [await this.db.getClientByEmailAndCompany(email, effectiveCompanyId)].filter(Boolean)
        : await this.db.getClientsByEmail(email);

      if (demoClients.length > 0) {
        const demoCode = '123456';
        const demoExpiry = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
        await this.db.storeClientMagicCode(demoClients[0].id, demoCode, demoExpiry.toISOString());
        console.log(`[Demo] Magic code set for customer demo account: ${email}`);
      }
      return { message: 'If an account exists, a login code has been sent' };
    }

    if (effectiveCompanyId) {
      // ... rest of existing code unchanged
```

### Step 4: Deploy backend

```bash
cd /Volumes/Riki\ Repos/repairminder/worker
npm run deploy
```

### Step 5: Run seed script

```bash
cd /Volumes/Riki\ Repos/repairminder
npx wrangler d1 execute repairminder_database --remote --file=worker/seeds/seed-demo-data.sql
```

### Step 6: Verify

```bash
# Verify seed data counts
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT 'company' as type, COUNT(*) as count FROM companies WHERE id = 'demo-company-001' UNION ALL SELECT 'clients', COUNT(*) FROM clients WHERE company_id = 'demo-company-001' UNION ALL SELECT 'orders', COUNT(*) FROM orders WHERE company_id = 'demo-company-001' UNION ALL SELECT 'devices', COUNT(*) FROM order_devices WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001') UNION ALL SELECT 'enquiries', COUNT(*) FROM tickets WHERE company_id = 'demo-company-001' AND ticket_type = 'enquiry'"
```

Expected output:
| type | count |
|------|-------|
| company | 1 |
| clients | 5 |
| orders | 7 |
| devices | 8 |
| enquiries | 3 |

### Step 7: Test in app

1. **Staff login:** Open app → Staff Login → `appstore-demo@repairminder.com` → Sign in with Magic Link → Enter `123456`
2. **Customer login:** Open app → Track My Repair → `appstore-customer@repairminder.com` → Sign in with Magic Link → Enter `123456`

---

## Part 4: App Store Connect — Review Information (Guideline 2.3.1a)

**Where:** App Store Connect → App Review Information → Notes for Review
**Review Detail ID:** `90917811-38d9-4a71-b8b2-781d79f0acfb`

### Demo Account Credentials

- **Username:** `appstore-demo@repairminder.com`
- **Password:** `123456`

### Notes for Review

```
Repair Minder is a repair shop management app with two user roles: Staff and Customer. Both use magic link (email code) authentication — no passwords.

== STAFF LOGIN ==
1. Tap "Staff Login"
2. Enter: appstore-demo@repairminder.com
3. Tap "Sign in with Magic Link"
4. Enter code: 123456

This gives admin access to "Apple Review Demo Shop" with pre-loaded demo data.

Staff features to test:
- Dashboard: Overview of open orders, device statuses, and enquiries
- My Queue: Devices assigned to the logged-in technician, filterable by status
- Orders: 7 orders across various statuses (in progress, service complete, collected). Tap any order to see devices, line items, messages, and timeline
- Devices: 8 devices across all workflow stages (received → diagnosing → repairing → ready → collected). Tap any device for full detail with status history
- Enquiries: 3 customer enquiry threads (2 open, 1 resolved) with message history. Staff can reply to open enquiries
- Clients: 5 client records with contact details and order history
- Settings: Company settings, location management

== CUSTOMER LOGIN ==
1. Tap "Track My Repair"
2. Enter: appstore-customer@repairminder.com
3. Tap "Sign in with Magic Link"
4. Enter code: 123456

This shows the customer portal for "Alex Thompson" with 3 orders:
- Order #100000001: iPhone 15 Pro screen repair (in progress) — view timeline and messages
- Order #100000002: iPad Air battery replacement (quote pending) — approve or reject the $100 quote
- Order #100000003: MacBook Pro keyboard repair (completed) — view full repair history and timeline

Customer features to test:
- Order list with status indicators
- Order detail with device info, repair timeline, and message thread
- Quote approval/rejection flow (Order #100000002)
- Message history between customer and shop

== NOTES ==
- Both accounts use a static demo code (123456) — no real email is sent
- All demo data is isolated to the "Apple Review Demo Shop" company
- The app requires an internet connection to communicate with the backend API
```

---

## Part 5: Data Summary

### Staff View (what the reviewer sees)

| Category | Count | Details |
|----------|-------|---------|
| Clients | 5 | Alex Thompson, Sarah Johnson, Michael Chen, Emma Williams, David Brown |
| Active orders | 5 | iPhone screen, iPad battery, Samsung water damage, iPhone back glass, Pixel screen |
| Completed orders | 1 | MacBook Pro keyboard (collected, paid $379) |
| Service complete | 1 | MacBook Air SSD (ready for pickup, $209) |
| Devices | 8 | Across 6 different status stages |
| Enquiries (open) | 2 | Water damage timeline, parts availability |
| Enquiries (resolved) | 1 | Collection readiness |
| Revenue (completed) | $379 | From MacBook keyboard repair |

### Device Status Breakdown

| Status | Count | Device |
|--------|-------|--------|
| device_received | 1 | Samsung Galaxy S24 (water damage) |
| diagnosing | 1 | iPhone 14 (no power) |
| awaiting_authorisation | 1 | iPad Air (battery — quote pending) |
| authorised_awaiting_parts | 1 | iPhone 16 Pro Max (back glass) |
| repairing | 2 | iPhone 15 Pro (screen), Pixel 8 (screen) |
| repaired_ready | 1 | MacBook Air (SSD upgrade) |
| collected | 1 | MacBook Pro (keyboard — completed) |

### Customer View (what the reviewer sees as Alex Thompson)

| Order | Device | Status | Action Available |
|-------|--------|--------|-----------------|
| #100000001 | iPhone 15 Pro | In Repair (repairing) | View timeline, messages |
| #100000002 | iPad Air | Quote Pending (awaiting_authorisation) | **Approve/reject quote** ($100) |
| #100000003 | MacBook Pro 14" | Completed (collected) | View history, timeline |

### Cleanup Script (if needed)

```sql
-- Remove ALL demo data (including any bookings created by reviewer)
DELETE FROM device_signatures WHERE device_id IN (SELECT id FROM order_devices WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001'));
DELETE FROM order_signatures WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
DELETE FROM device_status_log WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
DELETE FROM order_status_log WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
DELETE FROM order_payments WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
DELETE FROM order_devices WHERE order_id IN (SELECT id FROM orders WHERE company_id = 'demo-company-001');
DELETE FROM ticket_messages WHERE ticket_id IN (SELECT id FROM tickets WHERE company_id = 'demo-company-001');
DELETE FROM orders WHERE company_id = 'demo-company-001';
DELETE FROM tickets WHERE company_id = 'demo-company-001';
DELETE FROM clients WHERE company_id = 'demo-company-001';
UPDATE companies SET admin_user_id = NULL WHERE id = 'demo-company-001';
DELETE FROM users WHERE id = 'demo-staff-001';
DELETE FROM company_ticket_sequences WHERE company_id = 'demo-company-001';
DELETE FROM company_available_pages WHERE client_company_id = 'demo-company-001';
DELETE FROM company_subscriptions WHERE company_id = 'demo-company-001';
DELETE FROM company_locations WHERE company_id = 'demo-company-001';
DELETE FROM companies WHERE id = 'demo-company-001';
```
