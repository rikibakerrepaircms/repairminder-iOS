# Stage 09: Staff Enquiries

## Objective

Fix enquiry/ticket list and detail view models to work with updated Ticket model and correct endpoints.

## Dependencies

- **Requires**: Stage 02 complete (Ticket model fixed)
- **Requires**: Stage 04 complete (API client working)

## Complexity

**Medium** - Ticket model changes and multiple actions to verify

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Features/Enquiries/EnquiryListViewModel.swift` | Update for Ticket model |
| `Repair Minder/Features/Enquiries/EnquiryDetailViewModel.swift` | Update for Ticket model |
| `Repair Minder/Features/Enquiries/EnquiryListView.swift` | Update bindings |
| `Repair Minder/Features/Enquiries/EnquiryDetailView.swift` | Update bindings |
| `Repair Minder/Features/Scanner/Components/ScanResultView.swift` | If uses tickets |

## Backend Reference

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/tickets` | GET | List enquiries |
| `GET /api/tickets/:id` | GET | Single ticket detail |
| `GET /api/tickets/:id/messages` | GET | Ticket messages |
| `POST /api/tickets/:id/messages` | POST | Send reply |
| `POST /api/tickets/:id/read` | POST | Mark as read |
| `POST /api/tickets/:id/archive` | POST | Archive ticket |
| `POST /api/tickets/:id/spam` | POST | Mark as spam |
| `POST /api/tickets/:id/convert` | POST | Convert to order |
| `POST /api/tickets/:id/generate-response` | POST | AI reply |

### Note on Naming

The iOS app calls these "Enquiries" but the backend uses "Tickets". The endpoints use `/api/tickets`.

## Implementation Details

### 1. Property Mapping Changes

| Old Property | New Property | Notes |
|--------------|--------------|-------|
| `ticket.priority` | Removed | Not in backend |
| `ticket.orderRef` | `ticket.orderId` | Just the ID |
| `ticket.messageCount` | `ticket.deviceCount` | Different metric |
| `ticket.assignedUserName` | Computed | From first/last name |

### 2. EnquiryListViewModel

```swift
@MainActor
@Observable
final class EnquiryListViewModel {
    private(set) var enquiries: [Ticket] = []
    private(set) var isLoading = false
    var error: String?
    var statusFilter: TicketStatus?

    func loadEnquiries() async {
        isLoading = true

        do {
            let response: PaginatedResponse<Ticket> = try await APIClient.shared.request(
                .enquiries(status: statusFilter?.rawValue),  // Uses /api/tickets
                responseType: PaginatedResponse<Ticket>.self
            )
            enquiries = response.data
        } catch {
            self.error = "Failed to load enquiries"
        }

        isLoading = false
    }
}
```

### 3. EnquiryDetailViewModel

```swift
@MainActor
@Observable
final class EnquiryDetailViewModel {
    let enquiryId: String
    private(set) var enquiry: Ticket?
    private(set) var messages: [TicketMessage] = []
    private(set) var isLoading = false
    var error: String?

    func loadEnquiry() async {
        isLoading = true

        do {
            // Load ticket detail
            enquiry = try await APIClient.shared.request(
                .enquiry(id: enquiryId),
                responseType: Ticket.self
            )

            // Load messages
            let msgResponse: MessagesResponse = try await APIClient.shared.request(
                .enquiryMessages(id: enquiryId),
                responseType: MessagesResponse.self
            )
            messages = msgResponse.messages
        } catch {
            self.error = "Failed to load enquiry"
        }

        isLoading = false
    }

    func sendReply(message: String) async {
        do {
            try await APIClient.shared.requestVoid(
                .sendEnquiryReply(id: enquiryId, message: message)
            )
            await loadEnquiry()  // Reload to get new message
        } catch {
            self.error = "Failed to send reply"
        }
    }

    func markAsRead() async {
        do {
            try await APIClient.shared.requestVoid(
                .markEnquiryRead(id: enquiryId)
            )
        } catch {
            // Silently fail - not critical
        }
    }

    func archive() async {
        do {
            try await APIClient.shared.requestVoid(
                .archiveEnquiry(id: enquiryId)
            )
        } catch {
            self.error = "Failed to archive"
        }
    }

    func generateAIReply() async -> String? {
        do {
            struct AIResponse: Decodable {
                let response: String
            }
            let result: AIResponse = try await APIClient.shared.request(
                .generateEnquiryReply(id: enquiryId),
                responseType: AIResponse.self
            )
            return result.response
        } catch {
            self.error = "Failed to generate reply"
            return nil
        }
    }
}
```

### 4. Verify Endpoint Definitions

In `APIEndpoints.swift`, verify the enquiries section uses correct paths:

```swift
// Should use /api/tickets path
static func enquiries(page: Int = 1, limit: Int = 20, status: String? = nil) -> APIEndpoint {
    // ...
    return APIEndpoint(path: "/api/tickets", queryParameters: params)
}

static func enquiry(id: String) -> APIEndpoint {
    APIEndpoint(path: "/api/tickets/\(id)")
}

static func enquiryMessages(id: String) -> APIEndpoint {
    APIEndpoint(path: "/api/tickets/\(id)/messages")
}

static func sendEnquiryReply(id: String, message: String) -> APIEndpoint {
    // POST to /api/tickets/:id/messages
}
```

### 5. UI Updates

**EnquiryListRow** (or equivalent):
```swift
// Use displayRef
Text(ticket.displayRef)  // "#12345"

// Use computed assignedUserName
if let assignee = ticket.assignedUserName {
    Text(assignee)
}

// Client name
Text(ticket.clientName ?? "Unknown")
```

**EnquiryDetail**:
```swift
// Remove priority display (doesn't exist)
// Show status
Text(ticket.status.displayName)

// Show location if available
if let locName = ticket.locName {
    Text(locName)
}
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Enquiry list loads | Tickets displayed |
| Status filter works | Filtered list |
| Enquiry detail loads | Ticket info shown |
| Messages load | Message thread displayed |
| Send reply | Message sent, list updated |
| Mark as read | No error |
| Archive | Ticket archived |
| AI reply | Generated text returned |

## Acceptance Checklist

- [ ] Enquiry list compiles and loads
- [ ] Enquiry list uses `/api/tickets` endpoint
- [ ] Enquiry detail loads
- [ ] Messages load and display
- [ ] Reply sends successfully
- [ ] No references to `priority`
- [ ] Assigned user name computed from first/last
- [ ] Archive/spam actions work
- [ ] AI generate reply works

## Deployment

1. Build and run app
2. Navigate to Enquiries tab
3. Verify list loads
4. Tap an enquiry to view detail
5. Test sending a reply
6. Test archive action

## Handoff Notes

- "Enquiries" in iOS = "Tickets" in backend
- Priority field removed - not in backend
- AI reply generation available via `generate-response` endpoint
