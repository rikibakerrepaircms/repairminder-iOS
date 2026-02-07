# App Store Submission - Master Plan

## Overview

This document outlines all tasks required to submit **Repair Minder** to the App Store. This is a single combined app serving both **staff** (technicians/shop owners) and **customers** (tracking their repairs).

### App Details

| Field | Value |
|-------|-------|
| App Name | Repair Minder |
| Bundle ID | `com.mendmyi.repairminder` |
| App ID | `6758684092` |
| iOS Version | 1.0 (`PREPARE_FOR_SUBMISSION`) |
| macOS Version | 1.0 (`PREPARE_FOR_SUBMISSION`) — iOS only for initial submission |

### CLI Tool

Using [App Store Connect CLI](https://github.com/rudrankriyam/App-Store-Connect-CLI) (`v0.24.2`) for automation.

```bash
# CLI location
~/.local/bin/asc

# Config location
~/.asc/config.json

# API Key: 2RBJ2HRZQP
# Note: Pricing endpoints are restricted — use App Store Connect web UI for pricing.
```

---

## Stage 1: App Metadata Setup

**Goal:** Configure basic app information in App Store Connect

### Tasks

- [ ] **1.1** Set primary category → `BUSINESS`
- [ ] **1.2** Set secondary category → `UTILITIES`
- [ ] **1.3** Complete age rating declaration
- [ ] **1.4** Set content rights declaration

### CLI Commands

```bash
# Set categories
asc app-info update --app 6758684092 --primary-category BUSINESS --secondary-category UTILITIES

# Age rating (no violent/adult/gambling content)
asc age-rating update --app 6758684092 \
  --violence-cartoon NONE \
  --violence-realistic NONE \
  --violence-prolonged-or-intense false \
  --sexual-content-or-nudity NONE \
  --profanity-or-crude-humor NONE \
  --mature-or-suggestive-themes NONE \
  --horror-or-fear-themes NONE \
  --medical-or-treatment-information false \
  --alcohol-tobacco-or-drug-use NONE \
  --gambling false \
  --contests false \
  --unrestricted-web-access false
```

---

## Stage 2: Localizations (App Store Listing)

**Goal:** Create compelling App Store listing content

### Tasks

- [ ] **2.1** Write app description
- [ ] **2.2** Define keywords (100 chars max)
- [ ] **2.3** Write "What's New" for v1.0
- [ ] **2.4** Set promotional text (170 chars max)
- [ ] **2.5** Set subtitle (30 chars max)

### Content

**Subtitle (30 chars):**
```
Repair Shop Management
```

**Keywords (100 chars):**
```
repair,shop,management,technician,workflow,device,tracking,order,service,business,queue,customer
```

**Description:**
```
Repair Minder is a complete repair shop management solution — for both shop staff and their customers.

FOR REPAIR SHOP STAFF:

• Dashboard & Work Queue
  - Daily stats, revenue, and active repairs at a glance
  - Personal work queue with priority sorting
  - Period comparisons and lifecycle benchmarks

• Device Tracking
  - Barcode/QR code scanning for fast device lookup
  - Complete repair history and status per device
  - Workflow automation with status updates

• Order Management
  - Create and manage repair orders with line items
  - Track progress through repair stages
  - Payment tracking and customer signatures

• Enquiries & Messaging
  - Manage customer support tickets
  - Reply with macros and automated workflows
  - Bulk actions for efficient queue management

• Client Management
  - Customer database with contact details and addresses
  - Full order history per client

FOR CUSTOMERS:

• Real-time Repair Tracking
  - Live status updates on your repairs
  - View device details and repair progress

• Quote & Pre-authorisation Approval
  - Review and approve repair quotes instantly
  - Clear pricing breakdown with VAT

• Communication
  - Message your repair shop directly
  - Get notified when status changes

• Order History
  - View all past and current repairs
  - Signature capture for device collection

SHARED FEATURES:
- Push notifications for status changes and assignments
- Passcode lock with biometric (Face ID/Touch ID) support
- Dark mode support

Staff accounts require a Repair Minder business subscription.
Customers receive login credentials when dropping off their device.
Contact support@repairminder.com for business setup.
```

**Promotional Text (170 chars):**
```
The all-in-one repair shop app. Staff manage repairs, track devices, and handle enquiries. Customers track orders, approve quotes, and stay informed — all in one place.
```

**What's New:**
```
Initial release of Repair Minder.
```

### CLI Commands

```bash
# iOS Version ID: c91f17f4-db01-4782-9634-7dfd69c66bbd
# iOS Localization ID: da8f2280-f542-4d31-937e-45244629b328

# List current localizations
asc localizations list --version c91f17f4-db01-4782-9634-7dfd69c66bbd

# Upload localizations from files (preferred method)
asc localizations upload --version c91f17f4-db01-4782-9634-7dfd69c66bbd --path ./localizations

# Or download current, edit, and re-upload
asc localizations download --version c91f17f4-db01-4782-9634-7dfd69c66bbd --path ./localizations
```

---

## Stage 3: Visual Assets

**Goal:** Create and upload all required screenshots

### Required Screenshots

| Device | Size | Required |
|--------|------|----------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | Yes |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688 | Yes |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | Optional |
| iPad Pro 12.9" | 2048 x 2732 | If supporting iPad |
| iPad Pro 11" | 1668 x 2388 | If supporting iPad |

### Tasks

- [ ] **3.1** Design screenshot templates (branded frames)
- [ ] **3.2** Capture Staff Dashboard screen
- [ ] **3.3** Capture Staff My Queue screen
- [ ] **3.4** Capture Staff Order Detail screen
- [ ] **3.5** Capture Staff Enquiries screen
- [ ] **3.6** Capture Scanner / Device List screen
- [ ] **3.7** Capture Customer Order List screen
- [ ] **3.8** Capture Customer Order Detail / Quote Approval screen
- [ ] **3.9** Export for all required sizes (6.7" + 6.5" minimum)
- [ ] **3.10** Upload screenshots via CLI

### CLI Commands

```bash
# iOS Localization ID: da8f2280-f542-4d31-937e-45244629b328

# List existing screenshot sets
asc localizations screenshot-sets list --localization-id da8f2280-f542-4d31-937e-45244629b328

# Upload screenshot
asc assets upload \
  --version c91f17f4-db01-4782-9634-7dfd69c66bbd \
  --locale en-US \
  --type APP_IPHONE_67 \
  --file /path/to/screenshot_67.png

# Screenshot types:
# APP_IPHONE_67 - iPhone 6.7"
# APP_IPHONE_65 - iPhone 6.5"
# APP_IPHONE_55 - iPhone 5.5"
# APP_IPAD_PRO_129 - iPad Pro 12.9"
# APP_IPAD_PRO_3GEN_11 - iPad Pro 11"
```

---

## Stage 4: Demo Environment Setup

**Goal:** Create test accounts and demo data for Apple's App Review team

> **IMPORTANT:** Apple requires a fully functional demo account with realistic data.
> The reviewer must be able to test ALL features without creating their own account.

### Tasks

- [ ] **4.1** Create demo company in production database
- [ ] **4.2** Create demo staff user (admin role)
- [ ] **4.3** Create demo customer user (linked to demo company)
- [ ] **4.4** Populate demo data (orders, devices, clients, enquiries)
- [ ] **4.5** Implement auth bypass for demo accounts (backend)
- [ ] **4.6** Test both login flows (staff + customer) with demo credentials
- [ ] **4.7** Document demo account usage in review notes

### Authentication Bypass for Demo Accounts

> **CRITICAL:** Apple reviewers cannot receive magic link codes or 2FA codes.
> We need a static magic code or password bypass for demo accounts only.

**Recommended: Option A — Static Magic Code**
Demo accounts always accept code `123456`. Simplest to implement, no iOS changes needed.

**Backend Change:**
```typescript
// In magic link verification endpoint
if (isDemoAccount(email) && code === '123456') {
  return generateAuthToken(demoUser);
}
```

### Demo Staff Account

| Field | Value |
|-------|-------|
| Email | `appstore-demo@repairminder.com` |
| Magic Code | `123456` (static, always valid) |
| Role | `admin` |
| Company | Apple Review Demo Shop |

**Required Demo Data (Staff):**

- [ ] 3-5 sample clients with contact info
- [ ] 5-10 devices in various repair stages:
  - 2 devices in "Checked In" status
  - 2 devices in "Diagnosing" status
  - 2 devices in "Awaiting Parts" status
  - 2 devices in "Repaired" status
  - 1 device in "Ready for Pickup" status
- [ ] 3-5 active orders with line items
- [ ] 1-2 completed orders (for history)
- [ ] 2-3 enquiries (open + resolved) with message threads
- [ ] Dashboard should show realistic stats

### Demo Customer Account

| Field | Value |
|-------|-------|
| Email | `appstore-customer@repairminder.com` |
| Magic Code | `123456` (static, always valid) |
| Company | Apple Review Demo Shop |

**Required Demo Data (Customer):**

- [ ] 1 active order with device in repair
- [ ] 1 pending pre-authorisation/quote (to test approval flow)
- [ ] 1 completed order (for history)
- [ ] Order timeline with status updates
- [ ] Messages/communication history

### Testing Checklist

Before submission, verify both demo accounts work within the single app:

**Staff Login:**
- [ ] Login with staff demo email + magic code `123456`
- [ ] Dashboard loads with stats
- [ ] My Queue shows assigned devices
- [ ] Can view device list and detail
- [ ] Scanner works (scan or manual entry)
- [ ] Can view orders and order detail
- [ ] Can view and reply to enquiries
- [ ] Can view clients

**Customer Login:**
- [ ] Login with customer demo email + magic code `123456`
- [ ] Order list shows grouped orders (action required, in progress, etc.)
- [ ] Can view order detail with device info
- [ ] Pre-authorisation/quote approval visible and functional
- [ ] Can view order history

---

## Stage 5: App Review Preparation

**Goal:** Set up all information needed for App Store Review

### Tasks

- [ ] **5.1** Create/verify Privacy Policy page at `https://repairminder.com/privacy`
- [ ] **5.2** Create/verify Support page at `https://repairminder.com/support`
- [ ] **5.3** Write detailed review notes
- [ ] **5.4** Configure review contact info
- [ ] **5.5** Create encryption declaration (app uses HTTPS/TLS only → exempt)

### Required URLs

| URL | Purpose | Value |
|-----|---------|-------|
| Privacy Policy | Required | `https://repairminder.com/privacy` |
| Support URL | Required | `https://repairminder.com/support` |
| Marketing URL | Optional | `https://repairminder.com` |

### Review Notes

```
DEMO ACCOUNT CREDENTIALS:

This app supports two user types — Staff and Customer. Please test both.

--- STAFF LOGIN ---
1. Open the app and tap "Staff Login"
2. Enter email: appstore-demo@repairminder.com
3. Tap "Send Magic Link"
4. Enter code: 123456
5. You'll see the Staff Dashboard with sample repair data

Staff features to test:
- Dashboard: Daily stats, revenue, active repairs
- My Queue: Personal work queue with assigned devices
- Orders: Repair orders with line items and status tracking
- Enquiries: Customer support tickets with messaging
- More > Devices: Full device inventory with search
- More > Clients: Customer database
- More > Scanner: QR/barcode scanning for device lookup

--- CUSTOMER LOGIN ---
1. Go back to the login screen (logout from staff first)
2. Tap "Track My Repair"
3. Enter email: appstore-customer@repairminder.com
4. Tap "Send Magic Link"
5. Enter code: 123456

Customer features to test:
- Order List: Active and past repairs grouped by status
- Order Detail: Device info, repair timeline, pricing
- Quote/Pre-authorisation Approval: Review and approve pending quotes
- Order History: Completed repairs

NOTE: Staff accounts require a business subscription. Customer accounts are
created automatically when a device is dropped off at a participating shop.
```

### CLI Commands

```bash
# Create review details for iOS version
asc review details-create \
  --version-id c91f17f4-db01-4782-9634-7dfd69c66bbd \
  --contact-first-name "Riki" \
  --contact-last-name "Baker" \
  --contact-email "support@repairminder.com" \
  --contact-phone "+447..." \
  --demo-account-name "appstore-demo@repairminder.com" \
  --demo-account-password "123456" \
  --notes "See review notes..."

# Or update existing review details
# First get the detail ID:
asc review details-for-version --version-id c91f17f4-db01-4782-9634-7dfd69c66bbd
# Then update:
asc review details-update --id DETAIL_ID --notes "..."

# Create encryption declaration (HTTPS only, exempt)
asc encryption declarations create \
  --app 6758684092 \
  --app-description "Uses HTTPS/TLS for API communication only" \
  --contains-proprietary-cryptography=false \
  --contains-third-party-cryptography=false \
  --available-on-french-store=true

# Assign declaration to build
asc encryption declarations assign-builds --id DECL_ID --build BUILD_ID
```

---

## Stage 6: Build & Upload

**Goal:** Create release build and upload to App Store Connect

### Current Build Status

| Build | Uploaded | Status | Expired |
|-------|----------|--------|---------|
| 10 | 2026-02-05 | VALID | No |
| 9 | 2026-02-05 | VALID | Yes |
| 1-8 | 2026-02-03/04 | VALID | Yes |

> Build 10 is the latest valid build. Only non-expired builds can be attached to a version.

### Tasks

- [ ] **6.1** Ensure latest code changes are in the build (or upload new build)
- [ ] **6.2** Verify build 10 is the correct version to submit (or archive new)
- [ ] **6.3** Attach build to iOS App Store version

### Commands

```bash
# List current builds
asc builds list --app 6758684092 --output table --limit 5

# Archive and upload a new build (if needed)
# Use Xcode: Product → Archive → Distribute App → App Store Connect

# Attach build to iOS version
asc versions build set \
  --version c91f17f4-db01-4782-9634-7dfd69c66bbd \
  --build BUILD_ID
```

---

## Stage 7: Pricing & Availability

**Goal:** Configure app pricing and regional availability

> **Note:** The API key lacks pricing permissions. Use App Store Connect web UI for pricing setup.

### Tasks

- [ ] **7.1** Set as free app (App Store Connect web UI)
- [ ] **7.2** Configure territory availability (all territories)

### Web UI Steps

1. Go to App Store Connect → Repair Minder → Pricing and Availability
2. Set price to "Free"
3. Under Availability, ensure "Available in all territories" is selected

### CLI Commands (if permissions are updated)

```bash
# Check pricing schedule
asc pricing schedule get --app 6758684092

# Check availability
asc pricing availability get --app 6758684092
```

---

## Stage 8: Final Review & Submit

**Goal:** Final checks and submission

### Pre-submission Checklist

- [ ] **8.1** All metadata complete (description, keywords, subtitle)
- [ ] **8.2** All screenshots uploaded (6.7" + 6.5" minimum)
- [ ] **8.3** Build attached to iOS version
- [ ] **8.4** Privacy policy URL working (`https://repairminder.com/privacy`)
- [ ] **8.5** Support URL working (`https://repairminder.com/support`)
- [ ] **8.6** Demo accounts working (staff + customer, magic code 123456)
- [ ] **8.7** Age rating complete
- [ ] **8.8** Encryption declaration created and assigned to build
- [ ] **8.9** Content rights confirmed
- [ ] **8.10** Pricing set (free)

### CLI Commands

```bash
# Create a review submission
asc review submissions-create --app 6758684092 --platform IOS

# Add the iOS version to the submission
asc review items-add \
  --submission SUBMISSION_ID \
  --item-type appStoreVersions \
  --item-id c91f17f4-db01-4782-9634-7dfd69c66bbd

# Mark item as ready
asc review items-update --id ITEM_ID --state READY_FOR_REVIEW

# Submit for review
asc review submissions-submit --id SUBMISSION_ID --confirm

# Check submission status
asc review submissions-list --app 6758684092
```

---

## Stage 9: Post-Submission

**Goal:** Monitor review and respond to any issues

### Tasks

- [ ] **9.1** Monitor review status
- [ ] **9.2** Respond to any reviewer questions
- [ ] **9.3** Address any rejection reasons
- [ ] **9.4** Release after approval

### CLI Commands

```bash
# Check app versions and status
asc versions list --app 6758684092

# Check review submissions
asc review submissions-list --app 6758684092
```

---

## Quick Reference

### IDs

| Resource | ID |
|----------|-----|
| App ID | `6758684092` |
| iOS Version ID | `c91f17f4-db01-4782-9634-7dfd69c66bbd` |
| macOS Version ID | `8b69294e-154f-4c54-9354-0b886b218a9b` (not submitting initially) |
| iOS Localization ID | `da8f2280-f542-4d31-937e-45244629b328` |
| App Info ID | `c06e7f43-118a-4b6f-b6e3-68b06abd3deb` |
| App Info Localization ID | `136bfd12-3414-43d5-ab29-1564ce9c6d8b` |
| Review Detail ID | `90917811-38d9-4a71-b8b2-781d79f0acfb` |
| Encryption Declaration ID | `ba4bb1ff-18ce-4f0a-ba48-1d0cb1a5828c` |
| Attached Build | 10 — `de8c8d5d-aa74-4f9a-bc6f-fcc145f1e21a` |

---

## Progress Tracking

| Stage | Status | Notes |
|-------|--------|-------|
| Stage 1: App Metadata | ✅ Complete | Categories (BUSINESS/UTILITIES), age rating (all NONE, messaging=true) |
| Stage 2: Localizations | ✅ Complete | Description, keywords, subtitle, promo text, URLs. "What's New" N/A for v1.0 |
| Stage 3: Visual Assets | ⬜ Riki | Screenshots (6.7" + 6.5" minimum) — design, capture, upload |
| Stage 4: Demo Environment | ✅ Complete | Backend code bypass (Part 1) + seed data (Part 2) deployed & verified |
| Stage 5: Review Prep | ✅ Complete | Review details created, encryption declared, privacy/support URLs set |
| Stage 6: Build & Upload | ✅ Complete | Build 10 attached to iOS version |
| Stage 7: Pricing | ✅ Complete | Free (USD base, all territories) |
| Stage 8: Final Review | ⏳ Blocked | Waiting on: screenshots, demo environment, live URLs |
| Stage 9: Post-Submit | ⬜ Not Started | Monitor and respond |
