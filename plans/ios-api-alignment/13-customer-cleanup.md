# Stage 13: Customer App Cleanup

## Objective

Remove non-working features from customer app that have no backend endpoints.

## Dependencies

- **Requires**: Stage 12 complete (Orders working)

## Complexity

**Low** - Deletion and navigation updates

## Files to Delete

| File | Reason |
|------|--------|
| `Repair Minder/Customer/Enquiries/CustomerEnquiryListView.swift` | No `/api/customer/enquiries` endpoint |
| `Repair Minder/Customer/Enquiries/CustomerEnquiryListViewModel.swift` | No endpoint |
| `Repair Minder/Customer/Enquiries/CustomerEnquiryDetailView.swift` | No endpoint |
| `Repair Minder/Customer/Enquiries/CustomerEnquiryDetailViewModel.swift` | No endpoint |
| `Repair Minder/Customer/Enquiries/ShopPickerView.swift` | No `/api/customer/shops` endpoint |
| `Repair Minder/Customer/Enquiries/ShopPickerViewModel.swift` | No endpoint |
| `Repair Minder/Customer/Messages/CustomerMessagesListView.swift` | No `/api/customer/messages` endpoint |
| `Repair Minder/Customer/Messages/ConversationView.swift` | Use order reply instead |
| `Repair Minder/Customer/Messages/ConversationViewModel.swift` | Use order reply instead |

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Customer/CustomerTabView.swift` | Remove Enquiries and Messages tabs |
| `Repair Minder/Customer/CustomerApp.swift` | Remove unused navigation |

## Backend Reference

### Non-Existent Customer Endpoints

These endpoints were defined in iOS but don't exist in the backend:

- `GET /api/customer/enquiries` - ❌ Not implemented
- `GET /api/customer/enquiries/:id` - ❌ Not implemented
- `POST /api/customer/enquiries` - ❌ Not implemented (use public API)
- `GET /api/customer/shops` - ❌ Not implemented
- `GET /api/customer/messages` - ❌ Not implemented

### How Customers Should Access Features

| Feature | Backend Approach |
|---------|------------------|
| Submit enquiry | Public API via website/WordPress |
| View messages | Messages included in order detail |
| Send message | `POST /api/customer/orders/:id/reply` |

## Implementation Details

### 1. Update CustomerTabView

Remove tabs for non-working features:

```swift
// Repair Minder/Customer/CustomerTabView.swift

import SwiftUI

struct CustomerTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Orders tab - KEEP
            CustomerOrderListView()
                .tabItem {
                    Label("Orders", systemImage: "doc.text")
                }
                .tag(0)

            // Profile/Settings tab - KEEP (if exists)
            CustomerProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(1)

            // REMOVED: Enquiries tab
            // REMOVED: Messages tab
        }
    }
}
```

### 2. Delete Enquiries Directory

```bash
rm -rf "Repair Minder/Customer/Enquiries/"
```

Contents being deleted:
- `CustomerEnquiryListView.swift`
- `CustomerEnquiryListViewModel.swift`
- `CustomerEnquiryDetailView.swift`
- `CustomerEnquiryDetailViewModel.swift`
- `ShopPickerView.swift`
- `ShopPickerViewModel.swift`
- Any related models

### 3. Delete Messages Directory

```bash
rm -rf "Repair Minder/Customer/Messages/"
```

Contents being deleted:
- `CustomerMessagesListView.swift`
- `ConversationView.swift`
- `ConversationViewModel.swift`
- Related models

### 4. Update Navigation

If any navigation references deleted views, update or remove:

```swift
// Remove NavigationLinks to deleted views
// Remove any deep link handlers for enquiries/messages
```

### 5. Messaging via Order Detail

Messaging functionality moves to order detail:

```swift
// In CustomerOrderDetailView.swift

// Messages section showing order messages
if let messages = viewModel.order?.messages, !messages.isEmpty {
    Section("Messages") {
        ForEach(messages) { message in
            MessageRow(message: message)
        }
    }
}

// Reply input
Section {
    HStack {
        TextField("Type a message...", text: $newMessage)
        Button("Send") {
            Task {
                await viewModel.sendMessage(newMessage)
                newMessage = ""
            }
        }
        .disabled(newMessage.isEmpty)
    }
}
```

### 6. Clean Up APIEndpoints

The following endpoint definitions can be removed from `APIEndpoints.swift` since they were already updated, but verify they're gone:

```swift
// REMOVE IF STILL PRESENT:
// static func customerEnquiries(...)
// static func customerEnquiry(id:)
// static func customerSubmitEnquiry(...)
// static func customerEnquiryReply(...)
// static func customerShops()
// static func customerConversations()
// static func customerOrderMessages(...)
// static func customerSendMessage(...)
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| App launches | Shows Orders and Profile tabs only |
| No Enquiries tab | Tab bar has only 2 items |
| No Messages tab | Tab bar has only 2 items |
| Order detail messages | Messages section visible |
| Send message from order | Uses `/api/customer/orders/:id/reply` |
| Build succeeds | No missing file errors |

## Acceptance Checklist

- [ ] Enquiries directory deleted
- [ ] Messages directory deleted
- [ ] CustomerTabView shows only Orders and Profile
- [ ] No navigation references to deleted views
- [ ] No compiler errors from missing files
- [ ] APIEndpoints has no customer enquiry/message endpoints
- [ ] Messaging works from order detail
- [ ] App builds and runs successfully

## Deployment

```bash
# 1. Delete directories
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder/Customer"
rm -rf Enquiries Messages

# 2. Build to find any remaining references
xcodebuild -workspace "../Repair Minder.xcworkspace" \
  -scheme "Repair Minder Customer" \
  -destination "generic/platform=iOS" \
  build 2>&1 | grep -i error

# 3. Fix any remaining references
# 4. Rebuild and test
```

## Handoff Notes

- Customer messaging is now ONLY via order detail reply
- Enquiry submission should happen through website/public API
- If these features are needed in the future, backend endpoints must be added first
- Consider showing a message explaining where to submit enquiries (website)
