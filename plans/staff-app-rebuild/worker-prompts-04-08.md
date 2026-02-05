# Worker Prompts for Parallel Stages 04-08

These stages can be executed in parallel after Stage 03 is complete.

---

## Stage 04: Devices & Scanner

### Prompt

```
You are implementing Stage 04 (Devices & Scanner) for the Repair Minder iOS app.

## Context
- iOS Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Backend Source: `/Volumes/Riki Repos/repairminder/worker/`
- Stage Plan: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/staff-app-rebuild/04-devices-scanner.md`

## DO
- Read stage plan FIRST before implementing
- Read backend handler files to verify response shapes
- Create DevicesView with list, filtering, pagination
- Create DeviceDetailView with full device info
- Create ScannerView for barcode lookup
- Implement device status transitions (read from `src/device-workflows.js`)
- Add models: DeviceDetail, DeviceStatus transitions
- Use existing APIClient, AuthManager from Stage 01-02
- Test against running backend

## DO NOT
- Modify Dashboard, My Queue, or Auth screens
- Add new packages or dependencies
- Create unit tests (Stage 09)
- Add offline support

## Backend Files to Read
- `device_handlers.js` - getDevices(), getDevice() response shapes
- `src/device-workflows.js` - REPAIR_TRANSITIONS, BUYBACK_TRANSITIONS
- `index.js` - find `/api/devices` and `/api/orders/:orderId/devices` routes

## Pre-Implementation Verification
Run these commands to verify backend structure:
```bash
grep -n "getDevices\|getDevice\|getNextStatuses" /Volumes/Riki\ Repos/repairminder/worker/device_handlers.js
grep -n "REPAIR_TRANSITIONS\|BUYBACK_TRANSITIONS" /Volumes/Riki\ Repos/repairminder/worker/src/device-workflows.js
```

## Files to Create/Modify
### Models (Core/Models/)
- DeviceDetail.swift - Full device with all nested objects
- DeviceStatus.swift - Add transition logic (if not exists)

### Views (Features/Staff/Devices/)
- DevicesView.swift - List with search, filter, pagination
- DeviceDetailView.swift - Full device display with status actions
- DeviceDetailViewModel.swift

### Scanner (Features/Staff/Scanner/)
- ScannerView.swift - Camera barcode scanner
- ScannerViewModel.swift - Handle lookup

## API Endpoints
- GET /api/devices - List with filters
- GET /api/orders/:orderId/devices/:deviceId - Device detail
- GET /api/orders/:orderId/devices/:deviceId/actions - Available status transitions
- PATCH /api/orders/:orderId/devices/:deviceId - Update status

## Completion Checklist
- [ ] Device list displays with filters working
- [ ] Device detail shows all info
- [ ] Status transitions work correctly
- [ ] Scanner can look up devices by serial/IMEI
- [ ] No JSON decode errors in console
- [ ] Build succeeds without errors
```

---

## Stage 05: Orders & Clients

### Prompt

```
You are implementing Stage 05 (Orders & Clients) for the Repair Minder iOS app.

## Context
- iOS Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Backend Source: `/Volumes/Riki Repos/repairminder/worker/`
- Stage Plan: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/staff-app-rebuild/05-devices-orders.md`

## DO
- Read stage plan FIRST before implementing
- Read backend handler files to verify response shapes
- Create OrderListView with filtering and pagination
- Create OrderDetailView with items, payments, devices
- Create ClientListView with search
- Create ClientDetailView with order history
- Use existing models (Order.swift, Client.swift) - extend if needed
- Use existing APIClient from Stage 01

## DO NOT
- Modify Dashboard, My Queue, Devices, or Auth screens
- Implement payment processing (web-only)
- Add offline support
- Create unit tests (Stage 09)

## Backend Files to Read
- `order_handlers.js` - getOrders(), getOrder() response shapes
- `client_handlers.js` - getClients(), getClient() response shapes
- `index.js` - find `/api/orders` and `/api/clients` routes

## Pre-Implementation Verification
```bash
grep -n "getOrders\|getOrder" /Volumes/Riki\ Repos/repairminder/worker/order_handlers.js | head -10
grep -n "getClients\|getClient" /Volumes/Riki\ Repos/repairminder/worker/client_handlers.js | head -10
```

## Files to Create/Modify
### Views (Features/Staff/Orders/)
- OrderListView.swift - List with filters (extend if exists)
- OrderDetailView.swift - Full order with items, payments, devices
- OrderDetailViewModel.swift

### Views (Features/Staff/Clients/)
- ClientListView.swift - List with search (extend if exists)
- ClientDetailView.swift - Client info, order history
- ClientDetailViewModel.swift

### Models (if needed)
- Extend Order.swift for detail fields
- Extend Client.swift for detail fields

## API Endpoints
- GET /api/orders - List with filters
- GET /api/orders/:id - Order detail
- GET /api/clients - Client list
- GET /api/clients/:id - Client detail

## Completion Checklist
- [ ] Order list displays with filters working
- [ ] Order detail shows items, payments, devices
- [ ] Client list displays with search working
- [ ] Client detail shows order history
- [ ] No JSON decode errors in console
- [ ] Build succeeds without errors
```

---

## Stage 06: Enquiries

### Prompt

```
You are implementing Stage 06 (Enquiries/Tickets) for the Repair Minder iOS app.

## Context
- iOS Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Backend Source: `/Volumes/Riki Repos/repairminder/worker/`
- Stage Plan: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/staff-app-rebuild/06-enquiries.md`

## DO
- Read stage plan FIRST before implementing
- Read backend handler files to verify response shapes
- Create EnquiryListView with status filters
- Create EnquiryDetailView with message thread
- Implement reply, note, and AI response functionality
- Implement macro/workflow execution
- Use existing Ticket.swift, TicketMessage.swift models - extend if needed
- Use existing APIClient from Stage 01

## DO NOT
- Modify Dashboard, Devices, Orders, or Auth screens
- Add voice notes (not supported on iOS)
- Add offline support
- Create unit tests (Stage 09)

## Backend Files to Read
- `ticket_handlers.js` - getTickets(), getTicket(), sendReply() shapes
- `src/ticket_llm_handlers.js` - AI response generation
- `macro_execution_handlers.js` - Macro list and execution
- `index.js` - find `/api/tickets` routes

## Pre-Implementation Verification
```bash
grep -n "getTickets\|getTicket" /Volumes/Riki\ Repos/repairminder/worker/ticket_handlers.js | head -10
grep -n "generateResponse" /Volumes/Riki\ Repos/repairminder/worker/src/ticket_llm_handlers.js
grep -n "executeMacro" /Volumes/Riki\ Repos/repairminder/worker/macro_execution_handlers.js
```

## Files to Create/Modify
### Views (Features/Staff/Enquiries/)
- EnquiryListView.swift - List with status/type filters
- EnquiryDetailView.swift - Message thread with reply composer
- EnquiryDetailViewModel.swift
- Components/MessageBubble.swift
- Components/ReplyComposerView.swift
- Components/MacroPickerSheet.swift (may exist)

### Models (Core/Models/)
- Extend Ticket.swift for messages array
- Macro.swift - Macro with stages (may exist)
- MacroExecution.swift - Execution status (may exist)

## API Endpoints
- GET /api/tickets - List with filters
- GET /api/tickets/:id - Ticket detail with messages
- POST /api/tickets/:id/reply - Send reply
- POST /api/tickets/:id/note - Add internal note
- POST /api/tickets/:id/ai-response - Generate AI response
- GET /api/macros - List available macros
- POST /api/tickets/:id/execute-macro - Execute macro

## Completion Checklist
- [ ] Enquiry list displays with filters
- [ ] Message thread shows correctly
- [ ] Can send reply to customer
- [ ] Can add internal note
- [ ] AI response generation works
- [ ] Macro execution works
- [ ] No JSON decode errors in console
- [ ] Build succeeds without errors
```

---

## Stage 07: Settings & Push

### Prompt

```
You are implementing Stage 07 (Settings & Push Notifications) for the Repair Minder iOS app.

## Context
- iOS Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Backend Source: `/Volumes/Riki Repos/repairminder/worker/`
- Stage Plan: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/staff-app-rebuild/07-settings-push.md`

## DO
- Read stage plan FIRST before implementing
- Read backend handler files to verify response shapes
- Implement push notification registration with APNs
- Create notification preferences screen
- Implement deep linking from notifications
- Use `appType: "staff"` when registering tokens
- Extend existing SettingsView.swift

## DO NOT
- Modify other feature screens
- Implement customer push notifications (Stage 08)
- Add offline support
- Create unit tests (Stage 09)

## Backend Files to Read
- `device_token_handlers.js` - registerDeviceToken(), getPreferences()
- `src/apns.js` - Understand push payload structure
- `src/order-push-triggers.js` - What events trigger notifications

## Pre-Implementation Verification
```bash
grep -n "registerDeviceToken\|getPreferences" /Volumes/Riki\ Repos/repairminder/worker/device_token_handlers.js
grep -n "triggerOrderStatusPush\|triggerDeviceStatusPush" /Volumes/Riki\ Repos/repairminder/worker/src/order-push-triggers.js
```

## Files to Create/Modify
### Services (Core/Services/)
- PushNotificationService.swift - APNs registration, token management
- DeepLinkHandler.swift - Handle notification tap actions

### Views (Features/Settings/)
- NotificationSettingsView.swift - Preference toggles
- NotificationSettingsViewModel.swift

### Models (Core/Models/)
- PushPreferences.swift - Preference fields (may exist)
- NotificationPayload.swift - Deep link parsing (may exist)

### App (App/)
- Update AppDelegate.swift for push registration
- Update Repair_MinderApp.swift for deep link handling

## API Endpoints
- POST /api/user/device-token - Register APNS token
- DELETE /api/user/device-token - Unregister token
- GET /api/user/push-preferences - Get preferences
- PUT /api/user/push-preferences - Update preferences

## Token Registration Payload
```json
{
  "deviceToken": "apns_token_string",
  "platform": "ios",
  "appType": "staff",
  "deviceName": "iPhone 15 Pro",
  "osVersion": "17.4",
  "appVersion": "1.0.0"
}
```

## Completion Checklist
- [ ] Push permission requested at appropriate time
- [ ] Token registered with backend on login
- [ ] Token unregistered on logout
- [ ] Preferences screen shows all toggles
- [ ] Preferences update correctly
- [ ] Deep links navigate to correct screen
- [ ] Build succeeds without errors
```

---

## Stage 08: Customer Screens

### Prompt

```
You are implementing Stage 08 (Customer Screens) for the Repair Minder iOS app.

## Context
- iOS Project: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- Backend Source: `/Volumes/Riki Repos/repairminder/worker/`
- Stage Plan: `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/staff-app-rebuild/08-customer-screens.md`

## DO
- Read stage plan FIRST before implementing
- Read backend handler files to verify response shapes
- Create CustomerOrderListView showing customer's orders
- Create CustomerOrderDetailView with timeline, devices, quote
- Implement quote approval/rejection flow with signature
- Implement customer messaging (read-only thread + compose)
- Use existing CustomerAuthManager from Stage 02
- Show appropriate CustomerMainView when user logs in as customer

## DO NOT
- Modify Staff screens
- Implement payment processing (web-only)
- Show internal notes to customers
- Add offline support
- Create unit tests (Stage 09)

## Backend Files to Read
- `order_handlers.js` - Search for `/api/customer/` handlers
- `authorization_handlers.js` - Quote approval/rejection
- `index.js` - Find all `/api/customer/` routes

## Pre-Implementation Verification
```bash
grep -n "/api/customer" /Volumes/Riki\ Repos/repairminder/worker/index.js | head -20
grep -n "approveQuote\|rejectQuote" /Volumes/Riki\ Repos/repairminder/worker/authorization_handlers.js
```

## Files to Create/Modify
### Views (Features/Customer/)
- CustomerOrderListView.swift - Customer's order list
- CustomerOrderListViewModel.swift
- CustomerOrderDetailView.swift - Order with timeline, quote
- CustomerOrderDetailViewModel.swift
- Components/CustomerProgressBar.swift - Visual progress stages
- Components/CustomerApprovalSheet.swift - Quote approve/reject
- Components/CustomerSignatureView.swift - Signature capture

### Models (Core/Models/)
- CustomerOrder.swift - Customer order response (may exist)
- CustomerOrderDetail.swift - Full order detail (may exist)

### App
- Update Repair_MinderApp.swift - Show CustomerMainView for customer role

## API Endpoints
- GET /api/customer/orders - Customer's order list
- GET /api/customer/orders/:id - Order detail
- POST /api/customer/orders/:orderId/devices/:deviceId/approve - Approve quote
- POST /api/customer/orders/:orderId/devices/:deviceId/reject - Reject quote
- GET /api/customer/orders/:orderId/messages - Message thread
- POST /api/customer/orders/:orderId/messages - Send message

## Customer Progress Stages
Map internal statuses to customer-friendly stages:
1. Received - device_received
2. Diagnosing - diagnosing
3. Quote Sent - ready_to_quote, awaiting_authorisation
4. Approved - authorized
5. Repairing - repairing, ready_for_testing
6. Ready - repair_complete, ready_for_collection
7. Collected - collected

## Quote Approval Payload
```json
{
  "action": "approve",
  "signature_type": "drawn",
  "signature_data": "base64_signature_image",
  "terms_agreed": true
}
```

## Completion Checklist
- [ ] Customer can view their orders
- [ ] Order detail shows timeline and devices
- [ ] Quote approval flow works with signature
- [ ] Quote rejection works
- [ ] Customer can send messages
- [ ] Progress bar shows correct stage
- [ ] No JSON decode errors in console
- [ ] Build succeeds without errors
```

---

## Running Stages in Parallel

These stages (04-08) can be run in parallel by different workers since they don't have dependencies on each other. Each stage extends the app with new features while using the foundation from Stages 01-03.

### Parallel Execution Strategy
1. Assign each stage to a separate worker
2. Each worker reads their stage plan and backend files
3. Each worker creates their files in the designated directories
4. Conflicts should be minimal since each stage has isolated concerns
5. After all stages complete, run Stage 09 (Integration Testing)

### Merge Strategy
If multiple workers modify shared files:
- `Repair_MinderApp.swift` - May need manual merge for navigation
- `APIEndpoints.swift` - Additive changes, should merge cleanly
- Models in `Core/Models/` - Each stage creates different models

### Build Verification
After each stage completes, verify:
```bash
xcodebuild -project "Repair Minder/Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  build
```
