# RepairMinder iOS - Stage 15: Enquiries Module (Staff)

You are implementing Stage 15 of the RepairMinder iOS app.

**NOTE:** This stage can run IN PARALLEL with Stage 12 (Customer Portal).

---

## CONFIGURATION

**Master Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Stage Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/15-enquiries-module.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## TASK OVERVIEW

Build a polished enquiry management interface for staff to view, respond to, and convert customer enquiries into repair orders. This is a high-visibility feature that creates first impressions with potential customers.

---

## FILES TO CREATE

| File | Purpose |
|------|---------|
| `Features/Enquiries/EnquiryListView.swift` | Main enquiry inbox with filters |
| `Features/Enquiries/EnquiryListViewModel.swift` | List state management, filtering, pagination |
| `Features/Enquiries/EnquiryDetailView.swift` | Full enquiry view with conversation |
| `Features/Enquiries/EnquiryDetailViewModel.swift` | Detail logic, reply, convert |
| `Features/Enquiries/EnquiryFilterSheet.swift` | Filter/sort options sheet |
| `Features/Enquiries/Components/EnquiryCard.swift` | Rich enquiry preview card |
| `Features/Enquiries/Components/EnquiryStatsHeader.swift` | Stats pills (new today, awaiting reply, converted) |
| `Features/Enquiries/Components/EnquiryFilterChips.swift` | Horizontal filter chips |
| `Features/Enquiries/Components/EnquiryStatusPill.swift` | Animated status indicator |
| `Features/Enquiries/Components/CustomerInitialsAvatar.swift` | Colorful avatar with initials |
| `Features/Enquiries/Components/EnquiryHeaderCard.swift` | Customer info header |
| `Features/Enquiries/Components/DeviceInfoCard.swift` | Device details card |
| `Features/Enquiries/Components/IssueDescriptionCard.swift` | Issue text card |
| `Features/Enquiries/Components/ConversationThread.swift` | Message thread UI |
| `Features/Enquiries/Components/MessageBubble.swift` | Chat bubble (staff/customer) |
| `Features/Enquiries/Components/QuickReplyBar.swift` | Fast response input with templates |
| `Features/Enquiries/Components/ContactPill.swift` | Tappable phone/email pill |
| `Features/Enquiries/ConvertToOrderSheet.swift` | Enquiry → Order conversion flow |
| `Core/Models/Enquiry.swift` | Enquiry data model |
| `Core/Models/EnquiryMessage.swift` | Message in conversation |
| `Core/Models/EnquiryStatus.swift` | Status enum with colors |
| `Core/Models/EnquiryStats.swift` | Stats for header |

---

## FILES TO MODIFY

| File | Changes |
|------|---------|
| `App/AppRouter.swift` | Add `enquiryDetail(id: String)` route |
| `Core/Networking/APIEndpoints.swift` | Add enquiry endpoints |
| `Core/Notifications/DeepLinkHandler.swift` | Handle enquiry notifications (already has placeholders) |

---

## API ENDPOINTS

```swift
// Add to APIEndpoints.swift

// MARK: - Enquiries Endpoints
extension APIEndpoint {
    static func enquiries(
        page: Int = 1,
        limit: Int = 20,
        status: String? = nil
    ) -> APIEndpoint {
        var params: [String: String] = [
            "page": String(page),
            "limit": String(limit)
        ]
        if let status = status { params["status"] = status }
        return APIEndpoint(path: "/api/enquiries", queryParameters: params)
    }

    static func enquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)")
    }

    static func enquiryMessages(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/messages")
    }

    static func sendEnquiryReply(id: String, message: String) -> APIEndpoint {
        struct ReplyBody: Encodable { let message: String }
        return APIEndpoint(
            path: "/api/enquiries/\(id)/messages",
            method: .post,
            body: ReplyBody(message: message)
        )
    }

    static func enquiryStats() -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/stats")
    }

    static func markEnquiryRead(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/read", method: .post)
    }

    static func archiveEnquiry(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/archive", method: .post)
    }

    static func markEnquirySpam(id: String) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/spam", method: .post)
    }

    static func convertEnquiryToOrder<T: Encodable>(id: String, body: T) -> APIEndpoint {
        APIEndpoint(path: "/api/enquiries/\(id)/convert", method: .post, body: body)
    }
}
```

---

## MODELS

### EnquiryStatus
```swift
enum EnquiryStatus: String, Codable, CaseIterable {
    case new = "new"
    case pending = "pending"              // Awaiting staff response
    case awaitingCustomer = "awaiting_customer"
    case converted = "converted"          // Converted to order
    case spam = "spam"
    case archived = "archived"

    var displayName: String { ... }
    var shortName: String { ... }
    var color: Color { ... }
}
```

### EnquiryFilter
```swift
enum EnquiryFilter: String, CaseIterable {
    case all, new, pending, awaitingCustomer
    var displayName: String { ... }
}
```

### DeviceType
```swift
enum DeviceType: String, Codable, CaseIterable {
    case smartphone, tablet, laptop, desktop, console, other
    var displayName: String { ... }
    var icon: String { ... }
}
```

---

## UI REQUIREMENTS

### EnquiryListView
- Stats header showing: New Today, Awaiting Reply, Converted This Week
- Horizontal filter chips: All, New, Needs Reply, Waiting
- Cards with:
  - Customer avatar (colorful initials)
  - Unread indicator (blue dot)
  - Customer name + email
  - Device info pill
  - Issue preview (2 lines)
  - Last reply info
  - Status pill
- Context menu: Mark Read, Archive
- Pull-to-refresh
- Infinite scroll pagination

### EnquiryDetailView
- Customer header with contact pills (tap to call/email)
- Device info card
- Issue description card
- Conversation thread (chat bubbles)
- Quick reply bar with template buttons
- Toolbar: Convert to Order button, overflow menu (Mark Spam, Archive)

### ConvertToOrderSheet
- Pre-filled customer info (read-only)
- Device info (read-only)
- Issue description (read-only)
- Service selection toggles
- Estimated price input
- Priority picker
- Internal notes
- Create Order button

---

## SCOPE BOUNDARIES

### DO:
- Create polished enquiry inbox UI
- Implement filtering and stats
- Build conversation thread UI
- Create reply functionality with templates
- Build Convert to Order flow
- Add enquiry routes to AppRouter
- Add enquiry endpoints to APIEndpoints
- Update DeepLinkHandler for enquiry notifications
- Handle unread/read state

### DON'T:
- Don't modify existing Staff views (Dashboard, Orders, etc.)
- Don't create customer-facing enquiry views (that's Stage 12)
- Don't add enquiries tab to main tab bar (future enhancement)
- Don't implement reply templates API (hardcode a few for now)

---

## NAVIGATION

Access enquiries from:
1. Push notification tap (via DeepLinkHandler)
2. Deep link URL: `repairminder://enquiry/{id}`
3. (Future) Dashboard quick action or tab

For now, focus on the detail navigation working via notifications.

---

## BUILD & VERIFY

```
mcp__XcodeBuildMCP__build_sim
mcp__XcodeBuildMCP__build_run_sim
```

---

## COMPLETION CHECKLIST

- [ ] Enquiry model and status enum created
- [ ] EnquiryListView shows enquiries with filters
- [ ] Stats header displays accurate counts
- [ ] Filter chips filter the list correctly
- [ ] EnquiryCard shows all required info
- [ ] Unread enquiries have visual indicator
- [ ] EnquiryDetailView shows full enquiry
- [ ] Customer contact pills work (call/email)
- [ ] Conversation thread displays messages
- [ ] Quick reply input works
- [ ] Reply sends and appears in thread
- [ ] ConvertToOrderSheet opens and submits
- [ ] Converted enquiry shows status change
- [ ] Archive/Spam actions work
- [ ] AppRouter has enquiryDetail route
- [ ] DeepLinkHandler navigates to enquiry
- [ ] API endpoints added
- [ ] Project builds without errors

---

## WORKER NOTES

After completing this stage, notify that:
- Stage 15 is complete
- Enquiry inbox is functional
- Stage 13 (Settings & Polish) is now unblocked
