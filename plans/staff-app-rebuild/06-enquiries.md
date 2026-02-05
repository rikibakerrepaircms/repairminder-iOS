# Stage 06: Enquiries/Tickets

## Objective

Implement ticket list, ticket detail with message thread, reply/note/AI response functionality, and macro/workflow execution.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Ticket list response** - Read `/Volumes/Riki Repos/repairminder/worker/ticket_handlers.js` and verify:
   - `getTickets()` function return shape
   - Status counts and type counts structure
   - Nested order, client, location objects

2. **Ticket detail response** - Verify the full ticket object including:
   - Messages array with events and attachments
   - Message type values (inbound, outbound, note)
   - Custom email fields

3. **AI response** - Read `/Volumes/Riki Repos/repairminder/worker/src/ticket_llm_handlers.js` and verify:
   - Generate response endpoint exists
   - Response shape (text, usage, model, provider)

4. **Macros** - Read `/Volumes/Riki Repos/repairminder/worker/macro_execution_handlers.js` and verify:
   - Macro list response with stages
   - Execution response structure
   - Pause/resume/cancel responses

```bash
# Quick verification commands
grep -n "getTickets\|getTicket" /Volumes/Riki\ Repos/repairminder/worker/ticket_handlers.js | head -10
grep -n "generateResponse" /Volumes/Riki\ Repos/repairminder/worker/src/ticket_llm_handlers.js
grep -n "executeMacro" /Volumes/Riki\ Repos/repairminder/worker/macro_execution_handlers.js
```

**Do not proceed until you've verified the response shapes match this documentation.**

---

## API Endpoints

### GET /api/tickets

List tickets with pagination and filtering.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | String | Filter by status: `open`, `pending`, `resolved`, `closed` |
| `ticket_type` | String | Filter by type: `lead`, `order` |
| `assigned_user_id` | String | Filter by assigned user UUID |
| `location_id` | String | Location UUID, `all` (default), or `unset` |
| `workflow_status` | String | Filter by macro execution status: `all`, `none`, `active`, `paused`, `completed`, `cancelled` |
| `page` | Int | Page number (default: 1) |
| `limit` | Int | Items per page (default: 20, max: 100) |
| `sort_by` | String | `updated_at` (default), `last_client_update`, `created_at` |
| `sort_order` | String | `asc` or `desc` (default: desc) |

**Response:**
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": "uuid",
        "ticket_number": 100000001,
        "subject": "iPhone screen repair inquiry",
        "status": "open",
        "ticket_type": "lead",
        "assigned_user_id": "uuid or null",
        "assigned_user": {
          "first_name": "John",
          "last_name": "Doe"
        },
        "client": {
          "id": "uuid",
          "email": "customer@example.com",
          "name": "Jane Smith"
        },
        "location_id": "uuid or null",
        "location": {
          "id": "uuid",
          "name": "Main Store"
        },
        "order": {
          "id": "uuid",
          "status": "in_progress",
          "device_count": 2,
          "devices": [
            {
              "id": "uuid",
              "display_name": "Apple iPhone 14 Pro",
              "status": "repairing"
            }
          ]
        },
        "created_at": "2024-01-15T10:30:00Z",
        "updated_at": "2024-01-15T14:22:00Z",
        "last_client_update": "2024-01-15T12:00:00Z",
        "notes": [
          {
            "body": "Customer called, prefers afternoon pickup",
            "created_at": "2024-01-15T11:00:00Z",
            "created_by": "Staff Name",
            "device_id": "uuid or null",
            "device_name": "iPhone 14 Pro or null"
          }
        ]
      }
    ],
    "company_locations": [
      { "id": "uuid", "name": "Main Store", "is_primary": true }
    ],
    "statusCounts": {
      "open": 15,
      "pending": 8,
      "resolved": 42,
      "closed": 120
    },
    "ticketTypeCounts": {
      "lead": 25,
      "order": 160
    },
    "total": 185,
    "page": 1,
    "limit": 20,
    "totalPages": 10
  }
}
```

---

### GET /api/tickets/:id

Get single ticket with all messages. Supports lookup by UUID or ticket_number.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_number": 100000001,
    "subject": "iPhone screen repair inquiry",
    "status": "open",
    "ticket_type": "lead",
    "assigned_user_id": "uuid or null",
    "assigned_user": {
      "first_name": "John",
      "last_name": "Doe"
    },
    "merged_into_ticket_id": "uuid or null",
    "location_id": "uuid or null",
    "location": {
      "id": "uuid",
      "name": "Main Store"
    },
    "requires_location": true,
    "received_custom_email": {
      "id": "uuid",
      "email_address": "support@company.com",
      "display_name": "Support Team"
    },
    "last_reply_from_custom_email_id": "uuid or null",
    "created_at": "2024-01-15T10:30:00Z",
    "updated_at": "2024-01-15T14:22:00Z",
    "client": {
      "id": "uuid",
      "email": "customer@example.com",
      "name": "Jane Smith",
      "phone": "+44 7700 900000",
      "email_suppressed": 0,
      "email_suppressed_at": null,
      "is_generated_email": 0,
      "suppression_status": null,
      "suppression_error": null
    },
    "messages": [
      {
        "id": "uuid",
        "type": "inbound",
        "from_email": "customer@example.com",
        "from_name": "Jane Smith",
        "to_email": "support@company.com",
        "subject": "iPhone screen repair inquiry",
        "body_text": "Hi, I need a screen repair...",
        "body_html": "<div>Hi, I need a screen repair...</div>",
        "device_id": null,
        "device_name": null,
        "created_at": "2024-01-15T10:30:00Z",
        "created_by": null,
        "events": [],
        "attachments": []
      },
      {
        "id": "uuid",
        "type": "outbound",
        "from_email": "support@company.com",
        "from_name": "Reply by Staff",
        "to_email": "customer@example.com",
        "subject": "Re: iPhone screen repair inquiry",
        "body_text": "Hi Jane, thanks for reaching out...",
        "body_html": "<div>Hi Jane, thanks for reaching out...</div>",
        "device_id": null,
        "device_name": null,
        "created_at": "2024-01-15T11:00:00Z",
        "created_by": {
          "id": "uuid",
          "first_name": "John",
          "last_name": "Doe"
        },
        "events": [
          {
            "id": "uuid",
            "event_type": "sent",
            "event_data": {
              "postmark_message_id": "abc123",
              "to": "customer@example.com",
              "subject": "Re: iPhone screen repair inquiry",
              "sent_at": "2024-01-15T11:00:00Z"
            },
            "created_at": "2024-01-15T11:00:00Z"
          },
          {
            "id": "uuid",
            "event_type": "delivered",
            "event_data": { "delivered_at": "2024-01-15T11:00:05Z" },
            "created_at": "2024-01-15T11:00:05Z"
          }
        ],
        "attachments": [
          {
            "id": "uuid",
            "filename": "repair_guide.pdf",
            "content_type": "application/pdf",
            "size_bytes": 102400,
            "download_url": "/api/tickets/100000001/attachments/uuid/download",
            "created_at": "2024-01-15T11:00:00Z"
          }
        ]
      },
      {
        "id": "uuid",
        "type": "note",
        "from_email": null,
        "from_name": "Internal Note",
        "to_email": null,
        "subject": null,
        "body_text": "Customer called, prefers afternoon pickup",
        "body_html": null,
        "device_id": "uuid",
        "device_name": "Apple iPhone 14 Pro",
        "created_at": "2024-01-15T12:00:00Z",
        "created_by": {
          "id": "uuid",
          "first_name": "John",
          "last_name": "Doe"
        },
        "events": [],
        "attachments": []
      }
    ]
  }
}
```

---

### POST /api/tickets/:id/reply

Send a public email reply to the customer. Supports lookup by UUID or ticket_number.

**Request Body:**
```json
{
  "html_body": "<div>Your reply content here...</div>",
  "text_body": "Your reply content here...",
  "status": "pending",
  "from_custom_email_id": "uuid",
  "pending_attachment_ids": ["uuid1", "uuid2"]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `html_body` | String | Yes | HTML content of the reply |
| `text_body` | String | No | Plain text fallback |
| `status` | String | No | Update ticket status: `open`, `pending`, `resolved`, `closed` |
| `from_custom_email_id` | String | No | Send from a custom email address |
| `pending_attachment_ids` | Array | No | IDs of uploaded attachments to include |

**Response:**
```json
{
  "success": true,
  "data": {
    "message_id": "uuid",
    "postmark_message_id": "abc123",
    "type": "outbound",
    "body_html": "<div>Your reply content here...</div>",
    "body_text": "Your reply content here...",
    "created_at": "2024-01-15T14:30:00Z"
  }
}
```

**Error Responses:**
- `403`: Cannot reply to closed or merged ticket
- `422`: Email suppressed (bounced/blocked)

---

### POST /api/tickets/:id/note

Add an internal note (not emailed to customer). Supports lookup by UUID or ticket_number.

**Request Body:**
```json
{
  "body": "Customer called, prefers afternoon pickup",
  "device_id": "uuid"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `body` | String | Yes | Note content |
| `device_id` | String | No | Associate note with a specific device on the order |

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "type": "note",
    "body": "Customer called, prefers afternoon pickup",
    "device_id": "uuid or null",
    "created_by_user_id": "uuid",
    "created_at": "2024-01-15T14:30:00Z"
  }
}
```

**Error Responses:**
- `403`: Cannot add note to closed or merged ticket
- `400`: Device not found or doesn't belong to this ticket

---

### POST /api/tickets/:id/generate-response

Generate an AI-suggested response using LLM. Supports lookup by UUID or ticket_number.

**Request Body:**
```json
{
  "location_id": "uuid"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `location_id` | String | No | Use specific location details in response |

**Response:**
```json
{
  "success": true,
  "data": {
    "text": "Hi Jane,\n\nThank you for reaching out about your iPhone screen repair...",
    "usage": {
      "input_tokens": 1250,
      "output_tokens": 350,
      "cost": 0.000845
    },
    "model": "deepseek-reasoner",
    "provider": "deepseek"
  }
}
```

**Error Responses:**
- `400`: LLM generation not enabled, or ticket is closed/merged

---

### GET /api/macros

List available macros/canned responses for the company.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `category` | String | Filter by category |
| `name` | String | Filter by exact name |
| `include_inactive` | Boolean | Include inactive macros (default: false) |
| `include_stages` | Boolean | Include follow-up stages (default: false) |

**Response:**
```json
{
  "success": true,
  "data": {
    "macros": [
      {
        "id": "uuid",
        "name": "Quote Follow-up",
        "category": "general",
        "description": "Send after providing a quote",
        "initial_action_type": "email",
        "initial_subject": "Following up on your quote",
        "initial_content": "Hi {{client_name}},\n\nJust following up...",
        "reply_behavior": "cancel",
        "pause_expiry_days": null,
        "is_active": 1,
        "sort_order": 0,
        "stage_count": 2,
        "stages": [
          {
            "id": "uuid",
            "stage_number": 1,
            "delay_minutes": 1440,
            "delay_display": "1 day",
            "action_type": "email",
            "subject": "Still interested?",
            "content": "Hi {{client_name}}, wanted to check in...",
            "send_email": 1,
            "add_note": 0,
            "change_status": 0,
            "new_status": null,
            "note_content": null,
            "is_active": 1
          }
        ],
        "created_at": "2024-01-01T00:00:00Z"
      }
    ]
  }
}
```

---

### POST /api/tickets/:id/macro

Execute a macro on a ticket. Supports lookup by UUID or ticket_number.

**Request Body:**
```json
{
  "macro_id": "uuid",
  "variable_overrides": {
    "price": "99.99",
    "device_type": "iPhone 14 Pro",
    "repair_type": "Screen Replacement"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `macro_id` | String | Yes | ID of the macro to execute |
| `variable_overrides` | Object | No | Override template variables |

**Response:**
```json
{
  "success": true,
  "data": {
    "execution": {
      "id": "uuid",
      "macro_id": "uuid",
      "macro_name": "Quote Follow-up",
      "ticket_id": "uuid",
      "status": "active",
      "initial_message_id": "uuid",
      "scheduled_stages": [
        {
          "stage_number": 1,
          "scheduled_for": "2024-01-16T14:30:00Z",
          "delay_display": "1 day"
        }
      ],
      "created_at": "2024-01-15T14:30:00Z"
    }
  }
}
```

---

### GET /api/tickets/:id/macro-executions

List all macro executions for a specific ticket.

**Response:**
```json
{
  "success": true,
  "data": {
    "executions": [
      {
        "id": "uuid",
        "macro_id": "uuid",
        "macro_name": "Quote Follow-up",
        "status": "active",
        "executed_by_name": "John Doe",
        "created_at": "2024-01-15T14:30:00Z",
        "cancelled_at": null,
        "cancelled_reason": null,
        "completed_at": null,
        "stages_completed": 0,
        "stages_total": 2,
        "next_stage": {
          "stage_number": 1,
          "scheduled_for": "2024-01-16T14:30:00Z",
          "time_until": "23 hours"
        }
      }
    ],
    "pagination": {
      "total": 3,
      "page": 1,
      "per_page": 20,
      "total_pages": 1
    }
  }
}
```

---

### DELETE /api/macro-executions/:id

Cancel an active macro execution.

**Request Body (optional):**
```json
{
  "reason": "Customer responded, no longer needed"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "cancelled_stages": 2
  }
}
```

---

### PATCH /api/macro-executions/:id/pause

Pause an active workflow.

**Request Body:**
```json
{
  "reason": "Waiting for customer callback"
}
```

**Response:**
```json
{
  "success": true,
  "execution": { ... },
  "pending_stages_count": 2,
  "message": "Workflow paused successfully"
}
```

---

### PATCH /api/macro-executions/:id/resume

Resume a paused workflow.

**Request Body:**
```json
{
  "scheduling_option": "reschedule_from_now"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `scheduling_option` | String | `immediate`, `keep_original`, or `reschedule_from_now` |

**Response:**
```json
{
  "success": true,
  "execution": { ... },
  "next_stage": {
    "stage_number": 1,
    "scheduled_for": "2024-01-16T14:30:00Z",
    "delay_minutes": 1440
  },
  "message": "Workflow resumed with reschedule_from_now scheduling"
}
```

---

## Models

### Ticket

```swift
struct Ticket: Codable, Identifiable {
    let id: String
    let ticketNumber: Int
    let subject: String
    let status: TicketStatus
    let ticketType: TicketType
    let assignedUserId: String?
    let assignedUser: AssignedUser?
    let mergedIntoTicketId: String?
    let locationId: String?
    let location: TicketLocation?
    let requiresLocation: Bool?
    let receivedCustomEmail: CustomEmail?
    let lastReplyFromCustomEmailId: String?
    let createdAt: String
    let updatedAt: String
    let lastClientUpdate: String?
    let client: TicketClient
    let messages: [TicketMessage]?
    let order: TicketOrder?
    let notes: [TicketNote]?
}
```

### TicketMessage

```swift
struct TicketMessage: Codable, Identifiable {
    let id: String
    let type: MessageType
    let fromEmail: String?
    let fromName: String?
    let toEmail: String?
    let subject: String?
    let bodyText: String?
    let bodyHtml: String?
    let deviceId: String?
    let deviceName: String?
    let createdAt: String
    let createdBy: CreatedByUser?
    let events: [MessageEvent]?
    let attachments: [MessageAttachment]?
}
```

### MessageEvent

```swift
struct MessageEvent: Codable, Identifiable {
    let id: String
    let eventType: String  // sent, delivered, opened, clicked, bounced
    let eventData: AnyCodable?
    let createdAt: String
}
```

### MessageAttachment

```swift
struct MessageAttachment: Codable, Identifiable {
    let id: String
    let filename: String
    let contentType: String
    let sizeBytes: Int
    let downloadUrl: String
    let createdAt: String
}
```

### Macro

```swift
struct Macro: Codable, Identifiable {
    let id: String
    let name: String
    let category: String?
    let description: String?
    let initialActionType: String  // email, note
    let initialSubject: String?
    let initialContent: String
    let replyBehavior: String?  // cancel, pause, continue
    let pauseExpiryDays: Int?
    let isActive: Int
    let sortOrder: Int
    let stageCount: Int?
    let stages: [MacroStage]?
    let createdAt: String?
}
```

### MacroStage

```swift
struct MacroStage: Codable, Identifiable {
    let id: String
    let stageNumber: Int
    let delayMinutes: Int
    let delayDisplay: String?
    let actionType: String
    let subject: String?
    let content: String?
    let sendEmail: Int
    let addNote: Int
    let changeStatus: Int
    let newStatus: String?
    let noteContent: String?
    let isActive: Int
}
```

### MacroExecution

```swift
struct MacroExecution: Codable, Identifiable {
    let id: String
    let macroId: String
    let macroName: String
    let ticketId: String
    let ticketNumber: Int?
    let ticketSubject: String?
    let clientName: String?
    let clientEmail: String?
    let status: ExecutionStatus  // active, paused, completed, cancelled
    let executedByName: String?
    let createdAt: String
    let cancelledAt: String?
    let cancelledReason: String?
    let completedAt: String?
    let stagesCompleted: Int?
    let stagesTotal: Int?
    let nextStage: NextStage?
}
```

---

## Enums

### TicketStatus

```swift
enum TicketStatus: String, Codable, CaseIterable {
    case open
    case pending
    case resolved
    case closed

    var label: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }

    var color: Color {
        switch self {
        case .open: return .blue
        case .pending: return .orange
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}
```

### TicketType

```swift
enum TicketType: String, Codable, CaseIterable {
    case lead
    case order

    var label: String {
        switch self {
        case .lead: return "Lead/Enquiry"
        case .order: return "Order"
        }
    }
}
```

### MessageType

```swift
enum MessageType: String, Codable {
    case inbound
    case outbound
    case note
    case outboundSms = "outbound_sms"

    var isPublic: Bool {
        switch self {
        case .inbound, .outbound, .outboundSms: return true
        case .note: return false
        }
    }
}
```

### ExecutionStatus

```swift
enum ExecutionStatus: String, Codable, CaseIterable {
    case active
    case paused
    case completed
    case cancelled
}
```

---

## Template Variables for Macros

| Variable | Description | Example |
|----------|-------------|---------|
| `{{client_name}}` | Customer's full name | John Smith |
| `{{client_email}}` | Customer's email | john@example.com |
| `{{client_first_name}}` | Customer's first name | John |
| `{{customer_phone}}` | Customer's phone | +44 7700 900000 |
| `{{ticket_number}}` | Ticket reference | 100000001 |
| `{{ticket_subject}}` | Ticket subject line | iPhone repair |
| `{{ticket_status}}` | Current status | open |
| `{{company_name}}` | Company name | Repair Shop Ltd |
| `{{location_name}}` | Location name | Main Store |
| `{{location_address}}` | Full address | 123 High St, London |
| `{{location_phone}}` | Location phone | +44 20 1234 5678 |
| `{{location_email}}` | Location email | info@shop.com |
| `{{location_website}}` | Website URL | https://shop.com |
| `{{opening_hours}}` | Opening hours | Mon-Fri 9-5 |
| `{{staff_name}}` | Staff member's name | Admin User |
| `{{staff_first_name}}` | Staff first name | Admin |
| `{{greeting}}` | Time-based greeting | Good morning |
| `{{google_review_url}}` | Google review link | https://search.google.com/... |
| `{{location_google_maps}}` | Google Maps link | https://maps.google.com/... |
| `{{location_apple_maps}}` | Apple Maps link | https://maps.apple.com/... |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/Ticket.swift` | Ticket model with nested types |
| `Core/Models/TicketMessage.swift` | Message model with events/attachments |
| `Core/Models/TicketEnums.swift` | TicketStatus, TicketType, MessageType enums |
| `Core/Models/Macro.swift` | Macro and MacroStage models |
| `Core/Models/MacroExecution.swift` | Execution tracking model |
| `Core/Services/TicketService.swift` | Ticket API service |
| `Core/Services/MacroService.swift` | Macro API service |
| `Features/Staff/Enquiries/EnquiryListView.swift` | Ticket list UI |
| `Features/Staff/Enquiries/EnquiryListViewModel.swift` | List logic with filters |
| `Features/Staff/Enquiries/EnquiryDetailView.swift` | Ticket detail UI |
| `Features/Staff/Enquiries/EnquiryDetailViewModel.swift` | Detail logic with actions |
| `Features/Staff/Enquiries/Components/MessageBubble.swift` | Message display component |
| `Features/Staff/Enquiries/Components/MessageEventBadge.swift` | Delivery status indicator |
| `Features/Staff/Enquiries/Components/ReplyComposer.swift` | Reply/note input |
| `Features/Staff/Enquiries/Components/MacroPickerSheet.swift` | Macro selection |
| `Features/Staff/Enquiries/Components/WorkflowStatusCard.swift` | Active workflow display |

---

## Testing

**List tickets with curl:**
```bash
curl -s "https://api.repairminder.com/api/tickets?status=open" \
  -H "Authorization: Bearer TOKEN" | jq '.data.tickets[0]'
```

**Get ticket detail:**
```bash
curl -s "https://api.repairminder.com/api/tickets/100000001" \
  -H "Authorization: Bearer TOKEN" | jq '.data'
```

**Send reply:**
```bash
curl -X POST "https://api.repairminder.com/api/tickets/100000001/reply" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"html_body": "<p>Thank you for your inquiry...</p>"}' | jq .
```

**Add internal note:**
```bash
curl -X POST "https://api.repairminder.com/api/tickets/100000001/note" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body": "Customer prefers morning appointment"}' | jq .
```

**Generate AI response:**
```bash
curl -X POST "https://api.repairminder.com/api/tickets/100000001/generate-response" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.data.text'
```

**List macros:**
```bash
curl -s "https://api.repairminder.com/api/macros?include_stages=true" \
  -H "Authorization: Bearer TOKEN" | jq '.data.macros'
```

**Execute macro:**
```bash
curl -X POST "https://api.repairminder.com/api/tickets/100000001/macro" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"macro_id": "uuid-here"}' | jq .
```

---

## Verification Checklist

- [ ] Ticket list loads with pagination
- [ ] Ticket list filters work (status, ticket_type, location, assigned_user)
- [ ] Status counts display correctly
- [ ] Ticket type counts display correctly
- [ ] Ticket detail shows all messages in chronological order
- [ ] Inbound messages styled as customer messages
- [ ] Outbound messages styled as staff replies
- [ ] Internal notes styled distinctly (not visible to customer indicator)
- [ ] Message delivery events display (sent, delivered, opened)
- [ ] Attachments display with download option
- [ ] Can send public email reply
- [ ] Can add internal note
- [ ] Can add note associated with a specific device
- [ ] AI response generates and can be edited before sending
- [ ] Macro list loads with categories
- [ ] Can execute macro on ticket
- [ ] Active workflow displays on ticket detail
- [ ] Can pause/resume/cancel workflow
- [ ] Workflow stages show scheduled times
- [ ] Cannot reply to closed tickets (proper error handling)
- [ ] Cannot reply to merged tickets (proper error handling)
- [ ] Email suppression errors handled gracefully
- [ ] No decode errors for any response
