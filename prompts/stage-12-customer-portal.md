# RepairMinder iOS - Stage 12: Customer Portal

You are implementing Stage 12 of the RepairMinder iOS app.

---

## CONFIGURATION

**Master Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Stage Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/12-customer-portal.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## TASK OVERVIEW

Build a separate customer-facing app target for tracking repair orders, viewing status, communicating with the repair shop, approving/rejecting quotes, and submitting new repair enquiries.

**Architecture Decision:** Create a **separate target** (Repair Minder Customer) sharing code with the staff app.

---

## FILES TO CREATE

### New Target Structure: Customer/

| File | Purpose |
|------|---------|
| `Customer/CustomerApp.swift` | Customer app entry point with @main |
| `Customer/CustomerContentView.swift` | Main customer interface with tab navigation |
| `Customer/Auth/CustomerLoginView.swift` | Customer login (email lookup + magic link) |
| `Customer/Auth/CustomerAuthManager.swift` | Customer-specific auth (magic link/OTP) |
| `Customer/Orders/CustomerOrderListView.swift` | Customer's orders list |
| `Customer/Orders/CustomerOrderListViewModel.swift` | Orders list state management |
| `Customer/Orders/CustomerOrderDetailView.swift` | Order tracking view with timeline |
| `Customer/Orders/CustomerOrderDetailViewModel.swift` | Order detail logic |
| `Customer/Orders/Components/OrderTrackingHeader.swift` | Status header with icon |
| `Customer/Orders/Components/OrderTimeline.swift` | Timeline visualization |
| `Customer/Orders/Components/DevicesStatusSection.swift` | Device status cards |
| `Customer/Orders/Components/PaymentDueCard.swift` | Balance due display |
| `Customer/Orders/Components/CustomerOrderStatusBadge.swift` | Customer-friendly status badge |
| `Customer/Orders/QuoteApprovalView.swift` | Full quote review screen |
| `Customer/Orders/QuoteApprovalCard.swift` | Inline quote approval card |
| `Customer/Orders/Components/QuoteBreakdownCard.swift` | Quote line items |
| `Customer/Orders/Components/QuoteTotalCard.swift` | Quote totals with deposit |
| `Customer/Orders/Components/QuoteActionButtons.swift` | Approve/Reject buttons |
| `Customer/Orders/RejectReasonSheet.swift` | Decline reason input |
| `Customer/Enquiries/NewEnquiryView.swift` | Submit new repair enquiry form |
| `Customer/Enquiries/NewEnquiryViewModel.swift` | Enquiry submission logic |
| `Customer/Enquiries/ShopPickerView.swift` | Select from previous shops |
| `Customer/Enquiries/ShopPickerViewModel.swift` | Shop list logic |
| `Customer/Enquiries/EnquiryListView.swift` | Customer's enquiry history |
| `Customer/Enquiries/EnquiryDetailView.swift` | View enquiry status/replies |
| `Customer/Messages/CustomerMessagesListView.swift` | Conversations list |
| `Customer/Messages/ConversationView.swift` | Chat with repair shop |
| `Customer/Profile/CustomerProfileView.swift` | Customer profile/settings |
| `Core/Models/CustomerOrder.swift` | Customer-specific order model |
| `Core/Models/CustomerEnquiry.swift` | Customer enquiry model |
| `Core/Models/Quote.swift` | Quote model for approval |
| `Core/Models/Shop.swift` | Shop model for enquiry submission |

---

## XCODE TARGET SETUP

1. **Create new iOS App target:** "Repair Minder Customer"
2. **Bundle ID:** `com.mendmyi.repairminder.customer`
3. **Share these folders with both targets:**
   - `Core/` (Networking, Storage, Models)
   - `Shared/` (Components, Extensions, Utilities)
   - `Resources/` (Assets, Core Data model)
4. **Customer target only:**
   - `Customer/` folder
5. **Copy entitlements for push notifications**

---

## API ENDPOINTS (Customer Portal)

### Authentication
```
POST /api/customer/auth/request-magic-link
{ "email": "customer@example.com" }

POST /api/customer/auth/verify-code
{ "email": "customer@example.com", "code": "123456" }
```

### Orders
```
GET /api/customer/orders
GET /api/customer/orders/{id}
GET /api/customer/orders/{id}/timeline
```

### Quote Approval
```
POST /api/customer/orders/{id}/approve-quote
POST /api/customer/orders/{id}/reject-quote
{ "reason": "Too expensive" }
```

### Enquiries
```
GET /api/customer/enquiries
POST /api/customer/enquiries
{
  "shopId": "...",
  "deviceType": "smartphone",
  "deviceBrand": "Apple",
  "deviceModel": "iPhone 15",
  "issueDescription": "Screen cracked",
  "preferredContact": "email"
}
GET /api/customer/enquiries/{id}
POST /api/customer/enquiries/{id}/reply
{ "message": "..." }
```

### Previous Shops
```
GET /api/customer/shops
```

---

## CUSTOMER ORDER STATUS MAPPING

Map internal statuses to customer-friendly descriptions:

| Internal Status | Customer Display | Customer Description |
|-----------------|------------------|---------------------|
| `booked_in` | Received | We've received your device and it's in our queue |
| `diagnosing` | Being Diagnosed | Our technician is examining your device |
| `awaiting_approval` | Approval Needed | Please review and approve the repair quote |
| `in_progress` | Being Repaired | Your device is being repaired |
| `awaiting_parts` | Waiting for Parts | We're waiting for parts to arrive |
| `quality_check` | Final Checks | We're running final quality checks |
| `ready` | Ready for Collection | Your device is ready! Come collect it anytime |
| `collected` | Collected | Thanks for choosing us! |

---

## SCOPE BOUNDARIES

### DO:
- Create separate Customer target
- Implement customer magic link authentication
- Build order list with tracking timeline
- Build quote approval flow (approve/reject with reason)
- Build new enquiry submission form
- Build shop picker (previous shops only)
- Build enquiry list and detail views
- Build messaging/conversation UI
- Register for push notifications
- Share Core/ and Shared/ code with staff app

### DON'T:
- Don't modify the staff app (Repair Minder target)
- Don't create new API endpoints (assume they exist)
- Don't implement payment processing
- Don't implement ratings/reviews (future feature)

---

## BUILD & VERIFY

```
mcp__XcodeBuildMCP__build_sim (select Customer target scheme)
mcp__XcodeBuildMCP__build_run_sim
```

---

## COMPLETION CHECKLIST

- [ ] Customer target created and configured
- [ ] Customer login via email magic link works
- [ ] Session persists across app launches
- [ ] Order list shows only customer's orders
- [ ] Order tracking shows friendly status and timeline
- [ ] Device status visible per order
- [ ] Quote approval card shows for `awaiting_approval` orders
- [ ] Approve quote updates status
- [ ] Reject quote requires reason
- [ ] New enquiry form validates and submits
- [ ] Shop picker shows previous shops only
- [ ] Enquiry list displays with status badges
- [ ] Enquiry detail shows conversation
- [ ] Push notifications work for customer
- [ ] Logout clears session completely
- [ ] Project builds without errors for both targets

---

## WORKER NOTES

After completing this stage, notify that:
- Stage 12 is complete
- Customer portal is functional
- Both targets (Staff and Customer) build successfully
