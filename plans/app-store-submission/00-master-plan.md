# App Store Submission - Master Plan

## Overview

This document outlines all tasks required to submit **Repair Minder** (iOS) and **Repair Minder Support** (Customer app) to the App Store.

### App Details

| App | Bundle ID | App ID | Status |
|-----|-----------|--------|--------|
| Repair Minder (Staff) | `com.mendmyi.repairminder` | 6758684092 | PREPARE_FOR_SUBMISSION |
| Repair Minder Support (Customer) | `com.mendmyi.repairmindersupport` | 6758687116 | PREPARE_FOR_SUBMISSION |

### CLI Tool

Using [App Store Connect CLI](https://github.com/rudrankriyam/App-Store-Connect-CLI) for automation.

```bash
# CLI location
~/.local/bin/asc

# Config location
~/.asc/config.json
```

---

## Stage 1: App Metadata Setup

**Goal:** Configure basic app information in App Store Connect

### Tasks

- [ ] **1.1** Set primary category for Repair Minder → `BUSINESS`
- [ ] **1.2** Set secondary category (optional) → `UTILITIES`
- [ ] **1.3** Set primary category for Repair Minder Support → `BUSINESS`
- [ ] **1.4** Complete age rating declaration (both apps)
- [ ] **1.5** Set content rights declaration

### CLI Commands

```bash
# Set category for Staff app
asc app-info update --app 6758684092 --primary-category BUSINESS --secondary-category UTILITIES

# Set category for Customer app
asc app-info update --app 6758687116 --primary-category BUSINESS

# Age rating (answer NONE to all violent/adult content questions)
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

- [ ] **2.1** Write app description for Repair Minder (Staff)
- [ ] **2.2** Write app description for Repair Minder Support (Customer)
- [ ] **2.3** Define keywords (100 chars max each)
- [ ] **2.4** Write "What's New" for v1.0
- [ ] **2.5** Set promotional text (optional, 170 chars)
- [ ] **2.6** Set subtitle (30 chars max)

### Content Requirements

#### Repair Minder (Staff App)

**Subtitle (30 chars):**
```
Repair Shop Management
```

**Keywords (100 chars):**
```
repair,shop,management,technician,workflow,device,tracking,ticket,order,service,business,queue
```

**Description:**
```
Repair Minder is a complete repair shop management solution designed for technicians and shop owners.
Streamline your workflow, track device repairs, and manage your business efficiently.

KEY FEATURES:

• Dashboard & Queue Management
  - View daily stats and revenue at a glance
  - Personal work queue with priority sorting
  - Quick access to pending repairs

• Device Tracking
  - Barcode/QR code scanning for fast device lookup
  - Complete repair history per device
  - Status updates with workflow automation

• Order Management
  - Create and manage repair orders
  - Track order progress through stages
  - Payment and invoice tracking

• Client Management
  - Customer database with contact details
  - Order history per client
  - Quick communication options

• Real-time Notifications
  - Push notifications for new assignments
  - Status change alerts
  - Team collaboration updates

Perfect for:
- Phone repair shops
- Computer repair businesses
- Electronics service centers
- Any repair-based business

Requires a Repair Minder business account. Contact support@repairminder.com for setup.
```

#### Repair Minder Support (Customer App)

**Subtitle (30 chars):**
```
Track Your Repairs
```

**Keywords (100 chars):**
```
repair,tracking,order,status,device,service,support,phone,fix,progress,quote,customer,notification
```

**Description:**
```
Repair Minder Support lets you track your device repairs in real-time. Stay updated on your repair status,
approve quotes, and communicate with your repair shop - all from your phone.

KEY FEATURES:

• Real-time Repair Tracking
  - Live status updates on your repairs
  - Timeline view of repair progress
  - Estimated completion notifications

• Quote Approval
  - Review repair quotes instantly
  - Approve or request changes
  - Clear pricing breakdown

• Order History
  - View all past and current repairs
  - Access repair details anytime
  - Download invoices and receipts

• Push Notifications
  - Instant alerts when status changes
  - Quote ready notifications
  - Pickup reminders

• Easy Communication
  - Message your repair shop directly
  - Share additional photos or info
  - Get answers quickly

To use this app, you need an active repair order at a participating Repair Minder shop.
Your shop will provide login credentials when you drop off your device.
```

### CLI Commands

```bash
# iOS Version ID for Repair Minder: c91f17f4-db01-4782-9634-7dfd69c66bbd

# Create/update localization
asc localizations update \
  --version c91f17f4-db01-4782-9634-7dfd69c66bbd \
  --locale en-US \
  --description "..." \
  --keywords "repair,shop,management..." \
  --whats-new "Initial release of Repair Minder" \
  --promotional-text "The complete repair shop management solution" \
  --support-url "https://repairminder.com/support" \
  --marketing-url "https://repairminder.com"
```

---

## Stage 3: Visual Assets

**Goal:** Create and upload all required screenshots and app previews

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
- [ ] **3.2** Capture Dashboard screen
- [ ] **3.3** Capture Device List screen
- [ ] **3.4** Capture Device Detail screen
- [ ] **3.5** Capture Order List screen
- [ ] **3.6** Capture Scanner screen
- [ ] **3.7** Export for all required sizes
- [ ] **3.8** Upload screenshots via CLI
- [ ] **3.9** Repeat for Customer app

### CLI Commands

```bash
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

**Goal:** Create test accounts and demo data for App Store Review team

> **IMPORTANT:** Apple requires a fully functional demo account with realistic data to test your app.
> The reviewer must be able to test ALL features without creating their own account.

### Tasks

- [ ] **4.1** Create demo company in production database
- [ ] **4.2** Create demo staff user (for Staff app)
- [ ] **4.3** Create demo customer user (for Customer app)
- [ ] **4.4** Populate demo data (orders, devices, clients)
- [ ] **4.5** Test demo login flow works correctly
- [ ] **4.6** Document demo account usage in review notes

### Demo Company Setup

Create a dedicated demo company that the App Review team can access:

```sql
-- Create demo company
INSERT INTO companies (name, status, currency_code, vat_rate_repair)
VALUES ('Apple Review Demo Shop', 'active', 'USD', 0);

-- Get the company_id for next steps
```

### Authentication Bypass for Demo Accounts

> **CRITICAL:** Apple reviewers cannot receive magic link codes or 2FA codes.
> We need to implement a password-based login bypass for demo accounts only.

**Options:**

1. **Option A: Static Magic Code** - Demo accounts always accept code `123456`
2. **Option B: Password Login** - Demo accounts can login with email + password (no magic link)
3. **Option C: Auto-approve** - Backend auto-approves magic link for demo emails

**Recommended: Option B** - Add password field that only works for demo accounts.

**Backend Changes Required:**
```typescript
// In auth endpoint, check for demo account
if (email === 'appstore-demo@repairminder.com' && password === 'AppReview2026!') {
  // Bypass magic link, return auth token directly
  return generateAuthToken(demoUser);
}
```

**iOS Changes Required:**
- Add password field to login screen (can be hidden/shown based on config)
- Or: Add "Demo Login" button that uses hardcoded credentials

### Demo Staff Account (for Repair Minder Staff App)

| Field | Value |
|-------|-------|
| Email | `appstore-demo@repairminder.com` |
| Password | `AppReview2026!` |
| Role | `admin` |
| Company | Apple Review Demo Shop |
| Auth Method | Password (no magic link) |

**Required Demo Data for Staff App:**

- [ ] 3-5 sample clients with contact info
- [ ] 5-10 devices in various repair stages:
  - 2 devices in "Checked In" status
  - 2 devices in "Diagnosing" status
  - 2 devices in "Awaiting Parts" status
  - 2 devices in "Repaired" status
  - 1 device in "Ready for Pickup" status
- [ ] 3-5 active orders with line items
- [ ] 1-2 completed orders (for history)
- [ ] Dashboard should show realistic stats

### Demo Customer Account (for Repair Minder Support App)

| Field | Value |
|-------|-------|
| Email | `appstore-customer@repairminder.com` |
| Password | `AppReview2026!` |
| Company | Apple Review Demo Shop |

**Required Demo Data for Customer App:**

- [ ] 1 active order with device in repair
- [ ] 1 pending quote (to test quote approval flow)
- [ ] 1 completed order (for history)
- [ ] Order timeline with status updates
- [ ] Messages/communication history

### Database Setup Script

```sql
-- Run this after creating demo company (replace COMPANY_ID)

-- Create demo staff user
INSERT INTO users (email, first_name, last_name, company_id, role, is_active)
VALUES ('appstore-demo@repairminder.com', 'Demo', 'Technician', COMPANY_ID, 'admin', 1);

-- Create demo customer
INSERT INTO clients (company_id, first_name, last_name, email, phone)
VALUES (COMPANY_ID, 'Demo', 'Customer', 'appstore-customer@repairminder.com', '+1555123456');

-- Create sample devices, orders, etc.
-- [Additional INSERT statements for demo data]
```

### Testing Checklist

Before submission, verify the demo accounts work:

- [ ] Staff app: Login with demo credentials
- [ ] Staff app: Dashboard loads with stats
- [ ] Staff app: Can view device list
- [ ] Staff app: Can view device detail
- [ ] Staff app: Scanner works (can scan or manual entry)
- [ ] Staff app: Can view orders
- [ ] Staff app: Can view clients
- [ ] Customer app: Login with demo credentials
- [ ] Customer app: Can see active orders
- [ ] Customer app: Can view order detail
- [ ] Customer app: Quote approval visible (if pending)
- [ ] Customer app: Can view order history

---

## Stage 5: App Review Preparation

**Goal:** Set up all information needed for App Store Review

### Tasks

- [ ] **5.1** Create Privacy Policy page (if not exists)
- [ ] **5.2** Create Support page/URL
- [ ] **5.3** Write detailed review notes explaining app functionality
- [ ] **5.4** Configure App Store Review contact info
- [ ] **5.5** Answer export compliance questions

### Required URLs

| URL | Purpose | Value |
|-----|---------|-------|
| Privacy Policy | Required | `https://repairminder.com/privacy` |
| Support URL | Required | `https://repairminder.com/support` |
| Marketing URL | Optional | `https://repairminder.com` |

### Review Notes Template

**For Staff App:**
```
DEMO ACCOUNT CREDENTIALS:
Email: appstore-demo@repairminder.com
Password: AppReview2026!

HOW TO TEST:
1. Open the app and tap "Staff Login"
2. Enter the demo email address
3. Enter the demo password (password login enabled for demo accounts)
4. Once logged in, you'll see the Dashboard with sample repair data

FEATURES TO TEST:
- Dashboard: Shows daily stats, revenue, and work queue
- Devices: List of devices being repaired, tap any to see details
- Orders: Active repair orders with status tracking
- Scanner: Scan QR codes or enter ticket numbers manually
- Clients: Customer database with order history

NOTE: This app is for repair shop staff/technicians. The customer-facing app
is "Repair Minder Support" (separate app).
```

**For Customer App:**
```
DEMO ACCOUNT CREDENTIALS:
Email: appstore-customer@repairminder.com
Password: AppReview2026!

HOW TO TEST:
1. Open the app and tap "Track My Repair"
2. Enter the demo email address
3. Enter the demo password (password login enabled for demo accounts)

FEATURES TO TEST:
- Order List: View active and past repair orders
- Order Detail: See repair status, timeline, and device info
- Quote Approval: If a quote is pending, you can approve/decline
- Messages: View communication with repair shop

NOTE: This app requires an active repair order at a participating shop.
Real customers receive login credentials when they drop off their device.
```

### CLI Commands

```bash
# Set review information for Staff app
asc review update \
  --version c91f17f4-db01-4782-9634-7dfd69c66bbd \
  --contact-first-name "Riki" \
  --contact-last-name "Baker" \
  --contact-email "support@repairminder.com" \
  --contact-phone "+447..." \
  --demo-account-name "appstore-demo@repairminder.com" \
  --demo-account-password "AppReview2026!" \
  --notes "See review notes above..."
```

---

## Stage 6: Build & Upload

**Goal:** Create release build and upload to App Store Connect

### Tasks

- [ ] **6.1** Increment build number in Xcode
- [ ] **6.2** Update version string if needed (currently 1.0)
- [ ] **6.3** Archive app for distribution
- [ ] **6.4** Upload via Xcode or xcodebuild
- [ ] **6.5** Wait for build processing
- [ ] **6.6** Attach build to App Store version

### Commands

```bash
# Archive and upload (using xcodebuild)
xcodebuild -workspace "Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -archivePath ./build/RepairMinder.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath ./build/RepairMinder.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist

# Or use Xcode: Product → Archive → Distribute App

# Attach build to version
asc versions build set \
  --version c91f17f4-db01-4782-9634-7dfd69c66bbd \
  --build BUILD_ID
```

---

## Stage 7: Pricing & Availability

**Goal:** Configure app pricing and regional availability

### Tasks

- [ ] **7.1** Set price tier (Free or Paid)
- [ ] **7.2** Configure territory availability
- [ ] **7.3** Set pre-order if desired (optional)

### CLI Commands

```bash
# Check current pricing
asc pricing get --app 6758684092

# Set as free app
asc pricing update --app 6758684092 --price-tier 0

# Set territory availability (all territories)
asc pricing availability update --app 6758684092 --available-in-new-territories true
```

---

## Stage 8: Final Review & Submit

**Goal:** Final checks and submission

### Pre-submission Checklist

- [ ] **8.1** All metadata complete
- [ ] **8.2** All screenshots uploaded
- [ ] **8.3** Build attached to version
- [ ] **8.4** Privacy policy URL working
- [ ] **8.5** Support URL working
- [ ] **8.6** Demo account working (password login tested!)
- [ ] **8.7** Age rating complete
- [ ] **8.8** Export compliance answered
- [ ] **8.9** Content rights confirmed

### CLI Commands

```bash
# Validate submission readiness
asc submit validate --app 6758684092

# Submit for review
asc submit --app 6758684092 --version c91f17f4-db01-4782-9634-7dfd69c66bbd

# Check submission status
asc versions list --app 6758684092
```

---

## Stage 9: Post-Submission

**Goal:** Monitor review and respond to any issues

### Tasks

- [ ] **9.1** Monitor review status
- [ ] **9.2** Respond to any reviewer questions
- [ ] **9.3** Address any rejection reasons
- [ ] **9.4** Celebrate approval!

### CLI Commands

```bash
# Check app status
asc apps get --app 6758684092

# Check review submissions
asc review submissions list --app 6758684092

# Check for any messages from review team
asc review messages list --app 6758684092
```

---

## Quick Reference

### App IDs

| App | ID |
|-----|-----|
| Repair Minder (Staff) | 6758684092 |
| Repair Minder Support (Customer) | 6758687116 |

### Version IDs

| App | Platform | Version ID |
|-----|----------|------------|
| Repair Minder | iOS | c91f17f4-db01-4782-9634-7dfd69c66bbd |
| Repair Minder | macOS | 8b69294e-154f-4c54-9354-0b886b218a9b |

### Build IDs

| Version | Build ID | Status |
|---------|----------|--------|
| 3 | 5e55a5e3-b222-41cd-961e-df697c4bd86b | Valid (expires May 2026) |

---

## Progress Tracking

| Stage | Status | Notes |
|-------|--------|-------|
| Stage 1: App Metadata | ⬜ Not Started | Categories, age rating |
| Stage 2: Localizations | ⬜ Not Started | Description, keywords |
| Stage 3: Visual Assets | ⬜ Not Started | Screenshots for all sizes |
| Stage 4: Demo Environment | ⬜ Not Started | **CRITICAL:** Demo accounts + password auth bypass |
| Stage 5: Review Prep | ⬜ Not Started | Privacy policy, support URL, review notes |
| Stage 6: Build & Upload | ⬜ Not Started | Build 3 already uploaded |
| Stage 7: Pricing | ⬜ Not Started | Free app |
| Stage 8: Final Review | ⬜ Not Started | Pre-submission checklist |
| Stage 9: Post-Submit | ⬜ Not Started | Monitor and respond |
