# App Store Screenshot Plan

## Overview

10 slides total. Each slide has:
- A headline with 1-2 words highlighted in accent **blue**
- A device screenshot from the Xcode simulator with demo data

**Positioning:** Repair Minder is a complete CRM / POS / management platform for repair shops — not just repair tracking. The slides should communicate breadth: repairs, buybacks, accessories, lead management, AI assistance, customer self-service, financials, and security.

Screenshots are needed for **4 device sizes**:

| Device Class | Resolution | Simulator to Use |
|---|---|---|
| iPhone 6.5" | 1242x2688 | iPhone 11 Pro Max |
| iPhone 6.9" (Island) | 1290x2796 | iPhone 16 Pro Max |
| iPad Pro 12.9" (2nd) | 2048x2732 | iPad Pro 12.9" (2nd generation) |
| iPad 13" | 2048x2732 | iPad Pro 13-inch (M4) |

## File Naming Convention

```
screenshots/
├── slide-01-dashboard/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-02-service-types/
│   └── ...
├── slide-03-queue/
│   └── ...
└── ...
```

## Login Credentials

| Portal | Email | Code |
|---|---|---|
| Staff | `appstore-demo@repairminder.com` | `123456` |
| Customer | `appstore-customer@repairminder.com` | `123456` |

---

## Slide 1: Dashboard (Hero)

### Headline Text
> Your complete **repair business** in one app

**Highlighted words:** "repair business" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** Dashboard tab (first tab)
- **State:** "This Week" period selected, "My" scope
- **What should be visible:**
  - Period selector tabs at top (Today / This Week / This Month etc.)
  - Active Work section showing devices in progress
  - Stats grid: Devices, Revenue, Clients, New Clients — all with comparison arrows
  - Turnaround time comparison (Your avg vs Company avg)
  - Enquiry stats at bottom (Leads, First Replies, Response Time)
- **Navigation:** Login as staff → Dashboard is the default tab
- **Folder:** `slide-01-dashboard/`

---

## Slide 2: Service Type Selection (Breadth)

### Headline Text
> Repairs, buybacks **and more**

**Highlighted words:** "and more" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** New Booking → Service Type Selection (BookingView)
- **State:** The 4 service type cards displayed
- **What should be visible:**
  - Clean heading: "New Booking" or similar
  - 4 service type cards with icons:
    - **Repair** — device repair bookings
    - **Buyback** — trade-in / purchase from customer
    - **Accessories** — accessory sales
    - **Device Sale** — sell refurbished devices
  - Each card with an icon, title, and brief description
  - This single screen communicates the full breadth of the platform
- **Navigation:** Login as staff → tap blue "New Booking" FAB
- **Folder:** `slide-02-service-types/`
- **NOTE:** Booking feature must be built first (see plans/new-booking-feature/)

---

## Slide 3: My Queue (Workflow)

### Headline Text
> Your daily **workflow** sorted

**Highlighted words:** "workflow" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** My Queue tab (second tab)
- **State:** "All" category selected, showing multiple devices
- **What should be visible:**
  - Search bar at top
  - Category tabs (All / Repair / Buyback) with counts — shows multi-service
  - Device rows showing:
    - Device name (iPhone 15 Pro, iPad Air, Samsung Galaxy S24, etc.)
    - Client name
    - Status badge (Repairing, Awaiting Authorisation, Diagnosing, etc.)
    - Coloured status indicators
  - Multiple rows visible (aim for 4-6 devices on screen)
- **Navigation:** Login as staff → tap "My Queue" tab
- **Folder:** `slide-03-queue/`

---

## Slide 4: Enquiry List (Lead Management)

### Headline Text
> Turn **leads** into customers

**Highlighted words:** "leads" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** Enquiries tab (fourth tab) — list view
- **State:** Showing all enquiry tickets, mix of open and resolved
- **What should be visible:**
  - Enquiry list header with filter/sort options
  - Ticket rows showing:
    - Ticket number (#100000008, #100000009, #100000010)
    - Subject line (the customer's question)
    - Status badge (Open, Resolved) with colours
    - Customer name (Sarah Johnson, Michael Chen, Emma Williams)
    - Last message preview text
    - Timestamp
  - Visual indicator of unread/needs-response tickets
  - Shows the CRM side — leads captured automatically, nothing falls through
- **Navigation:** Login as staff → tap "Enquiries" tab
- **Folder:** `slide-04-leads/`

---

## Slide 5: Enquiry Detail + AI (Smart Replies)

### Headline Text
> Reply smarter with **AI**

**Highlighted words:** "AI" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** Enquiry Detail view — message thread with AI assist visible
- **State:** Show Michael's parts enquiry (demo-ticket-enq-002) — has 3 messages and a nice conversation flow
- **What should be visible:**
  - Ticket header with number and "Open" status
  - Message thread showing:
    - Michael's inbound message (asking about back glass availability)
    - Shop's outbound reply (part ordered, 2-3 days)
    - Michael's follow-up thank you
  - Message bubbles with clear inbound/outbound styling
  - Reply input area at bottom
  - AI assist button / macro picker visible — shows the AI-powered reply capability
  - **Ideal:** If possible, show the AI suggestion overlay or the macro picker sheet open
- **Navigation:** Login as staff → Enquiries tab → tap Michael's "Do you have the back glass in stock?" enquiry
- **Folder:** `slide-05-ai-replies/`

---

## Slide 6: Order Detail (Financials)

### Headline Text
> **Orders** and finances in one place

**Highlighted words:** "Orders" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** Order Detail view — Alex's iPhone 15 Pro order (demo-order-001)
- **State:** Showing full order with line items, pricing, and client info
- **What should be visible:**
  - Order header: Order #100000001, status "In Progress"
  - Client section: Alex Thompson with contact info
  - Device: iPhone 15 Pro with status badge
  - Line items section:
    - iPhone 15 Pro OLED Display Assembly (OEM) — $189.00
    - Screen Replacement Labour — $45.00
  - Order totals: Subtotal, Tax (0% in demo), Grand Total $234.00
  - Payment status
  - This shows the POS / financial side — parts, labour, tax handling, totals
- **Navigation:** Login as staff → Orders tab → tap first order (#100000001)
- **Folder:** `slide-06-order-detail/`

---

## Slide 7: Customer Portal (Self-Service)

### Headline Text
> Customers track their **orders**

**Highlighted words:** "orders" (in accent blue)

### Screenshot Instructions
- **Portal:** Customer
- **Screen:** Customer Order List
- **State:** Logged in as Alex Thompson — has 3 orders in different sections
- **What should be visible:**
  - "Action Required" section (orange): iPad Air order with pending quote
  - "In Progress" section: iPhone 15 Pro order (being repaired)
  - "Completed" section: MacBook Pro order (collected)
  - Each order card showing:
    - Order reference number
    - Status badge with colour
    - Device name(s) with icon
    - Date and total amount
  - Profile button in nav bar
  - Shows that customers get their own portal — reduces support queries
- **Navigation:** Login as customer → this is the default screen
- **Folder:** `slide-07-customer-portal/`

---

## Slide 8: Quote Approval + Signature (Digital Workflow)

### Headline Text
> Get **quotes approved** digitally

**Highlighted words:** "quotes approved" (in accent blue)

### Screenshot Instructions
- **Portal:** Customer
- **Screen:** Customer Order Detail — iPad Air order (demo-order-002)
- **State:** Showing the pending quote with approval banner
- **What should be visible:**
  - Order header with reference number and "In Progress" status
  - "Action Required" banner (orange) indicating quote needs approval
  - Device card: "iPad Air (5th Gen)" with:
    - Status: "Awaiting Authorisation"
    - Progress bar showing lifecycle position
    - Line items: Battery Cell $65 + Labour $35
    - "Approve" button (prominent)
  - Order totals section: $100.00
  - Shows the digital approval workflow — no phone calls or emails needed
- **Navigation:** Login as customer → tap the "Action Required" order (iPad Air)
- **Folder:** `slide-08-approval/`

---

## Slide 9: Device Detail (Tracking)

### Headline Text
> Track every **device** step by step

**Highlighted words:** "device" (in accent blue)

### Screenshot Instructions
- **Portal:** Staff
- **Screen:** Device Detail view
- **State:** Show Alex's iPhone 15 Pro (demo-device-001) — richest status history
- **What should be visible:**
  - Device header: "Apple iPhone 15 Pro" with status badge "Repairing"
  - Device info: Serial, colour (Natural Titanium), storage (256GB)
  - Customer reported issues text
  - Diagnosis notes
  - Repair notes (in progress)
  - Status timeline showing: Received → Diagnosing → Ready to Repair → Repairing
  - Line items: OLED Display Assembly $189 + Labour $45
  - Shows deep per-device tracking with full audit trail
- **Navigation:** Login as staff → My Queue → tap "iPhone 15 Pro" row
- **Folder:** `slide-09-device-detail/`

---

## Slide 10: Security (Trust)

### Headline Text
> Your data stays **secure**

**Highlighted words:** "secure" (in accent blue)

### Screenshot Instructions
- **Portal:** Either (passcode screen appears on app launch)
- **Screen:** Passcode Lock screen
- **State:** Fresh lock screen prompting for passcode/biometric
- **What should be visible:**
  - Lock/shield icon at top
  - "Enter Passcode" heading
  - PIN dots (empty, waiting for input)
  - Number pad (0-9 with delete)
  - Face ID / biometric button
  - Clean, secure-feeling design
- **Navigation:** Set up a passcode in Settings first, then lock the app (background → foreground, or set timeout to "On Close")
- **Folder:** `slide-10-security/`

---

## Execution Checklist

### Pre-requisites
- [ ] Booking feature built and working (slide 2 depends on this)
- [ ] Demo data seeded on the backend
- [ ] All 4 simulators available and booted

### Capture Order (most efficient)

**Staff session (slides 1, 2, 3, 4, 5, 6, 9):**
1. Boot simulator for target device
2. Build and run app
3. Login as staff (`appstore-demo@repairminder.com` / `123456`)
4. **Slide 1:** Dashboard (default screen) → screenshot
5. **Slide 3:** Tap My Queue tab → screenshot
6. **Slide 9:** Tap iPhone 15 Pro row → Device Detail → screenshot
7. Back to tabs
8. **Slide 6:** Tap Orders tab → tap first order → Order Detail → screenshot
9. Back to tabs
10. **Slide 4:** Tap Enquiries tab → screenshot (list view)
11. **Slide 5:** Tap Michael's enquiry → Enquiry Detail → screenshot
12. **Slide 2:** Tap New Booking FAB → Service Type Selection → screenshot
13. **Slide 10:** Settings → set passcode → lock app → screenshot

**Customer session (slides 7, 8):**
14. Logout → login as customer (`appstore-customer@repairminder.com` / `123456`)
15. **Slide 7:** Customer Order List (default screen) → screenshot
16. **Slide 8:** Tap iPad Air order (Action Required) → screenshot

**Repeat for each of the 4 device sizes.**

---

## Summary Table

| Slide | Headline | Blue Words | Screen | Portal | Selling Point |
|---|---|---|---|---|---|
| 1 | Your complete **repair business** in one app | repair business | Dashboard | Staff | Business intelligence at a glance |
| 2 | Repairs, buybacks **and more** | and more | Service Type Selection | Staff | Platform breadth — not just repairs |
| 3 | Your daily **workflow** sorted | workflow | My Queue | Staff | Daily task management |
| 4 | Turn **leads** into customers | leads | Enquiry List | Staff | CRM / automatic lead capture |
| 5 | Reply smarter with **AI** | AI | Enquiry Detail + AI | Staff | AI-powered assistance |
| 6 | **Orders** and finances in one place | Orders | Order Detail | Staff | POS / financials / tax |
| 7 | Customers track their **orders** | orders | Customer Order List | Customer | Self-service reduces support |
| 8 | Get **quotes approved** digitally | quotes approved | Customer Approval | Customer | Digital workflow / signatures |
| 9 | Track every **device** step by step | device | Device Detail | Staff | Deep per-device audit trail |
| 10 | Your data stays **secure** | secure | Passcode Lock | Either | Trust / compliance |

## Narrative Arc

1-2: **"Here's the full platform"** — dashboard overview + service breadth
3: **"Manage your day"** — daily workflow queue
4-5: **"Never lose a lead"** — CRM + AI replies
6: **"Financials sorted"** — orders, parts, labour, tax
7-8: **"Your customers love it"** — self-service portal + digital approvals
9: **"Deep tracking"** — per-device lifecycle
10: **"Trust closer"** — security and data protection
