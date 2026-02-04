# Stage 01: API Verification & Documentation

## Objective

Document ALL backend endpoints needed by the unified app (Staff + Customer) with complete request/response examples BEFORE any code is written.

## Dependencies

- **Requires**: None (first stage)
- **Backend Access**: `/Volumes/Riki Repos/repairminder/worker/`

## Complexity

**Medium** - Research and documentation, no code changes

## Files to Modify

None (documentation only)

## Files to Create

| File | Purpose |
|------|---------|
| This document | Complete endpoint reference |

---

## Implementation Details

### Verification Process

For each endpoint:
1. Find handler in backend `worker/*.js` files
2. Document exact path, method, parameters
3. Document request body structure (if POST/PATCH)
4. Document response structure with exact field names
5. Note any enum values (statuses, types)

---

## Authentication Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/index.js]` (auth routes)

### POST /api/auth/login

**Purpose**: Login with email and password

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (Success)**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Smith",
      "role": "engineer",
      "company_id": "uuid",
      "company": {
        "id": "uuid",
        "name": "Repair Shop Ltd",
        "currency_code": "GBP"
      }
    }
  }
}
```

**Response (2FA Required)**:
```json
{
  "success": true,
  "data": {
    "requires_2fa": true,
    "method": "totp",
    "temp_token": "temp_uuid"
  }
}
```

---

### POST /api/auth/magic-link/request

**Purpose**: Request magic link code via email

**Request Body**:
```json
{
  "email": "user@example.com"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "message": "Magic link sent to your email"
  }
}
```

---

### POST /api/auth/magic-link/verify-code

**Purpose**: Verify magic link code

**Request Body**:
```json
{
  "email": "user@example.com",
  "code": "123456"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "user": { /* same as login response */ }
  }
}
```

---

### POST /api/auth/refresh

**Purpose**: Refresh access token using refresh token

**Request Body**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

### GET /api/auth/me

**Purpose**: Get current user profile

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Smith",
    "role": "engineer",
    "company_id": "uuid",
    "company": {
      "id": "uuid",
      "name": "Repair Shop Ltd",
      "currency_code": "GBP",
      "logo_url": "https://..."
    },
    "permissions": ["orders.view", "devices.edit", ...]
  }
}
```

---

### POST /api/auth/logout

**Purpose**: Logout current session

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}
```

---

## Dashboard Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/dashboard_handlers.js]`

### GET /api/dashboard/stats

**Purpose**: Get dashboard statistics

**Query Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `scope` | String | No | `user` | `user` or `company` |
| `period` | String | No | `this_month` | Period filter |
| `compare_periods` | Int | No | 1 | Number of comparison periods |
| `start_date` | Date | No | - | Override period start |
| `end_date` | Date | No | - | Override period end |

**Period Values**: `today`, `yesterday`, `this_week`, `last_week`, `this_month`, `last_month`, `this_quarter`, `this_year`

**Response**:
```json
{
  "success": true,
  "data": {
    "period": "this_month",
    "devices": {
      "current": { "count": 15 },
      "comparisons": [
        {
          "period": "last_month",
          "count": 12,
          "change": 3,
          "change_percent": 25.0
        }
      ]
    },
    "revenue": {
      "current": { "total": 1250.50 },
      "comparisons": [
        {
          "period": "last_month",
          "total": 980.00,
          "change": 270.50,
          "change_percent": 27.6
        }
      ]
    },
    "clients": {
      "current": { "count": 8 },
      "comparisons": [...]
    },
    "new_clients": {
      "current": { "count": 3 },
      "comparisons": [...]
    },
    "returning_clients": {
      "current": { "count": 5 },
      "comparisons": [...]
    },
    "refunds": {
      "current": { "total": 50.00, "count": 1 },
      "comparisons": [...]
    }
  }
}
```

---

## Device Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/device_handlers.js]`

### GET /api/devices

**Purpose**: List all devices across orders

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page` | Int | No | Page number (default: 1) |
| `limit` | Int | No | Items per page (default: 20, max: 100) |
| `status` | String | No | Filter by status (comma-separated) |
| `device_type_id` | UUID | No | Filter by device type |
| `assigned_user_id` | UUID | No | Filter by assigned engineer |
| `workflow_type` | String | No | `repair`, `buyback`, `trade_in` |
| `search` | String | No | Search serial/IMEI |

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "order_id": "uuid",
      "order_number": 100001,
      "display_name": "Apple iPhone 12 Pro",
      "brand": {
        "id": "uuid",
        "name": "Apple"
      },
      "model": {
        "id": "uuid",
        "name": "iPhone 12 Pro"
      },
      "serial_number": "ABCD1234567890",
      "imei": "123456789012345",
      "status": "diagnosing",
      "workflow_type": "repair",
      "priority": "standard",
      "assigned_engineer": {
        "id": "uuid",
        "name": "John Smith"
      },
      "device_type": {
        "id": "uuid",
        "name": "Phone",
        "slug": "phone"
      },
      "client": {
        "id": "uuid",
        "name": "Jane Doe",
        "email": "jane@example.com"
      },
      "created_at": "2024-02-04T10:30:00Z",
      "updated_at": "2024-02-04T11:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

---

### GET /api/devices/my-queue

**Purpose**: Get current user's assigned device queue

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page` | Int | No | Page number (default: 1) |
| `limit` | Int | No | Items per page (default: 20) |

**Response**: Same structure as `/api/devices` but filtered to current user's assignments

---

### GET /api/devices/my-active-work

**Purpose**: Get devices currently being worked on by user

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "display_name": "Apple iPhone 12 Pro",
      "status": "repairing",
      "started_at": "2024-02-04T10:30:00Z"
    }
  ]
}
```

---

### GET /api/header/counts

**Purpose**: Get badge counts for header/tabs

**Response**:
```json
{
  "success": true,
  "data": {
    "my_queue": 5,
    "active_work": 1,
    "open_enquiries": 3
  }
}
```

---

### GET /api/orders/:orderId/devices/:deviceId

**Purpose**: Get full device detail

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "order_id": "uuid",
    "brand": { "id": "uuid", "name": "Apple", "category": "Smartphone" },
    "model": { "id": "uuid", "name": "iPhone 12 Pro" },
    "custom_brand": null,
    "custom_model": null,
    "display_name": "Apple iPhone 12 Pro",
    "serial_number": "ABCD1234567890",
    "imei": "123456789012345",
    "colour": "Space Gray",
    "storage_capacity": "256GB",
    "passcode": "123456",
    "passcode_type": "numeric",
    "find_my_status": "off",
    "condition_grade": "Grade A",
    "customer_reported_issues": "Screen cracked",
    "technician_found_issues": "Screen cracked, battery degraded",
    "status": "diagnosing",
    "workflow_type": "repair",
    "priority": "standard",
    "due_date": "2024-02-10",
    "assigned_engineer": {
      "id": "uuid",
      "name": "John Smith"
    },
    "sub_location": {
      "id": "uuid",
      "code": "SL001",
      "description": "Shelf 1"
    },
    "device_type": {
      "id": "uuid",
      "name": "Phone",
      "slug": "phone"
    },
    "diagnosis_notes": "Requires screen replacement",
    "repair_notes": "",
    "authorization": {
      "status": "pending",
      "method": null,
      "authorized_at": null
    },
    "timestamps": {
      "received_at": "2024-02-04T10:30:00Z",
      "diagnosis_started_at": "2024-02-04T12:00:00Z",
      "diagnosis_completed_at": null,
      "repair_started_at": null,
      "repair_completed_at": null,
      "collected_at": null
    },
    "images": [
      {
        "id": "uuid",
        "image_type": "pre_repair",
        "filename": "image.jpg",
        "caption": "Cracked screen",
        "sort_order": 1
      }
    ],
    "accessories": [
      {
        "id": "uuid",
        "accessory_type": "charger",
        "description": "Original USB-C cable",
        "returned_at": null
      }
    ],
    "line_items": [
      {
        "id": "uuid",
        "description": "Screen replacement",
        "quantity": 1,
        "unit_price": 75.00,
        "vat_rate": 20.0,
        "line_total_inc_vat": 90.00
      }
    ],
    "created_at": "2024-02-04T10:30:00Z",
    "updated_at": "2024-02-04T15:30:00Z"
  }
}
```

---

### POST /api/devices/:deviceId/action

**Purpose**: Execute a workflow action on device

**Request Body**:
```json
{
  "action": "start_diagnosis",
  "notes": "Optional notes"
}
```

**Available Actions** (from `device-workflows.js`):
- `start_diagnosis` - Begin diagnosing
- `complete_diagnosis` - Finish diagnosis
- `send_quote` - Send quote to customer
- `start_repair` - Begin repair work
- `complete_repair` - Finish repair
- `mark_ready` - Mark ready for collection
- `collect` - Mark as collected
- `despatch` - Mark as despatched

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "ready_to_quote",
    "message": "Device status updated"
  }
}
```

---

### PATCH /api/devices/:deviceId/engineer

**Purpose**: Assign engineer to device

**Request Body**:
```json
{
  "engineer_id": "uuid"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "assigned_engineer": {
      "id": "uuid",
      "name": "John Smith"
    }
  }
}
```

---

### PATCH /api/devices/:deviceId/status

**Purpose**: Directly update device status (admin override)

**Request Body**:
```json
{
  "status": "repairing",
  "reason": "Override reason"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "repairing"
  }
}
```

---

## Order Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/order_handlers.js]`

### GET /api/orders

**Purpose**: List orders with pagination and filters

**Query Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | Int | Page number |
| `limit` | Int | Items per page |
| `status` | String | Order status filter (comma-separated) |
| `payment_status` | String | `unpaid`, `partial`, `paid` |
| `search` | String | Search order number, client name/email |
| `location_id` | UUID | Filter by location |
| `date_from` | Date | Start date |
| `date_to` | Date | End date |
| `sort` | String | `created_at`, `updated_at`, `order_number` |
| `order` | String | `asc` or `desc` |

**Order Status Values**: `awaiting_device`, `in_progress`, `service_complete`, `awaiting_collection`, `collected_despatched`

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "ticket_id": "uuid",
      "order_number": 100001,
      "client": {
        "id": "uuid",
        "email": "customer@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+441234567890"
      },
      "location": {
        "id": "uuid",
        "name": "Main Shop"
      },
      "assigned_user": {
        "id": "uuid",
        "name": "Staff Member"
      },
      "intake_method": "walk_in",
      "status": "in_progress",
      "payment_status": "partial",
      "order_total": 150.00,
      "amount_paid": 100.00,
      "balance_due": 50.00,
      "device_count": 2,
      "created_at": "2024-02-04T10:30:00Z",
      "updated_at": "2024-02-04T11:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  },
  "filters": {
    "locations": [{ "id": "uuid", "name": "Location Name" }],
    "users": [{ "id": "uuid", "name": "User Name" }],
    "statuses": ["awaiting_device", "in_progress", ...],
    "payment_statuses": ["unpaid", "partial", "paid"]
  }
}
```

---

### GET /api/orders/:orderId

**Purpose**: Get full order detail

**Note**: Supports lookup by UUID or order_number

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_id": "uuid",
    "order_number": 100001,
    "client": {
      "id": "uuid",
      "email": "customer@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "phone": "+441234567890",
      "address_line_1": "123 Main St",
      "city": "London",
      "postcode": "SW1A 1AA"
    },
    "location": {
      "id": "uuid",
      "name": "Main Shop",
      "phone": "0207123456"
    },
    "intake_method": "walk_in",
    "status": "in_progress",
    "devices": [
      {
        "id": "uuid",
        "display_name": "Apple iPhone 12 Pro",
        "status": "diagnosing",
        "workflow_type": "repair"
      }
    ],
    "items": [
      {
        "id": "uuid",
        "description": "Screen repair",
        "quantity": 1,
        "unit_price": 75.00,
        "vat_rate": 20.0,
        "line_total": 75.00,
        "line_total_inc_vat": 90.00
      }
    ],
    "payments": [
      {
        "id": "uuid",
        "amount": 50.00,
        "payment_method": "card",
        "payment_date": "2024-02-04",
        "is_deposit": 1
      }
    ],
    "totals": {
      "subtotal": 150.00,
      "vat_total": 30.00,
      "grand_total": 180.00,
      "amount_paid": 50.00,
      "balance_due": 130.00
    },
    "payment_status": "partial",
    "dates": {
      "created_at": "2024-02-04T10:30:00Z",
      "updated_at": "2024-02-04T11:30:00Z",
      "quote_sent_at": null,
      "collected_at": null,
      "ready_by_date": "2024-02-10T17:00:00Z"
    },
    "notes": [
      {
        "body": "Note text",
        "created_at": "2024-02-04T10:30:00Z",
        "created_by": "Staff Name"
      }
    ]
  }
}
```

---

## Ticket/Enquiry Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/ticket_handlers.js]`

### GET /api/tickets

**Purpose**: List tickets/enquiries

**Query Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | Int | Page number |
| `limit` | Int | Items per page |
| `status` | String | `open`, `pending`, `resolved`, `closed` |
| `ticket_type` | String | `lead` or `order` |
| `assigned_user_id` | UUID | Filter by assignee |
| `sort_by` | String | `updated_at`, `created_at`, `last_client_update` |
| `sort_order` | String | `asc` or `desc` |

**Response**:
```json
{
  "success": true,
  "data": {
    "tickets": [
      {
        "id": "uuid",
        "ticket_number": 100001,
        "subject": "iPhone repair request",
        "status": "open",
        "ticket_type": "order",
        "assigned_user": {
          "first_name": "John",
          "last_name": "Smith"
        },
        "client": {
          "id": "uuid",
          "email": "customer@example.com",
          "name": "John Doe"
        },
        "location": {
          "id": "uuid",
          "name": "Main Shop"
        },
        "order": {
          "id": "uuid",
          "status": "in_progress",
          "device_count": 1
        },
        "created_at": "2024-02-04T10:30:00Z",
        "updated_at": "2024-02-04T11:30:00Z",
        "last_client_update": "2024-02-04T10:45:00Z"
      }
    ],
    "statusCounts": {
      "open": 5,
      "pending": 3,
      "resolved": 10,
      "closed": 2
    },
    "total": 20,
    "page": 1,
    "limit": 20,
    "totalPages": 1
  }
}
```

---

### GET /api/tickets/:ticketId

**Purpose**: Get ticket detail with messages

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_number": 100001,
    "subject": "iPhone repair request",
    "status": "open",
    "ticket_type": "order",
    "assigned_user": {
      "first_name": "John",
      "last_name": "Smith"
    },
    "client": {
      "id": "uuid",
      "email": "customer@example.com",
      "name": "John Doe",
      "phone": "+441234567890"
    },
    "order": {
      "id": "uuid",
      "order_number": 100001,
      "status": "in_progress"
    },
    "messages": [
      {
        "id": "uuid",
        "type": "inbound",
        "from_email": "customer@example.com",
        "from_name": "John Doe",
        "subject": "iPhone repair request",
        "body_text": "Hi, I need my iPhone screen repaired.",
        "created_at": "2024-02-04T10:30:00Z",
        "attachments": [
          {
            "id": "uuid",
            "filename": "photo.jpg",
            "content_type": "image/jpeg",
            "size_bytes": 245000
          }
        ]
      },
      {
        "id": "uuid",
        "type": "outbound",
        "from_name": "Repair Shop",
        "body_text": "Hi John, we can help with that...",
        "created_at": "2024-02-04T11:00:00Z",
        "created_by": {
          "id": "uuid",
          "first_name": "Staff",
          "last_name": "Member"
        }
      },
      {
        "id": "uuid",
        "type": "note",
        "body_text": "Internal note for team",
        "created_at": "2024-02-04T11:30:00Z",
        "created_by": {
          "id": "uuid",
          "first_name": "Staff",
          "last_name": "Member"
        }
      }
    ],
    "created_at": "2024-02-04T10:30:00Z",
    "updated_at": "2024-02-04T11:30:00Z"
  }
}
```

---

### POST /api/tickets/:ticketId/reply

**Purpose**: Send reply to customer

**Request Body**:
```json
{
  "body": "Thank you for contacting us...",
  "subject": "Re: iPhone repair request"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "type": "outbound",
    "body_text": "Thank you for contacting us...",
    "created_at": "2024-02-04T12:00:00Z"
  }
}
```

---

### POST /api/tickets/:ticketId/note

**Purpose**: Add internal note (not sent to customer)

**Request Body**:
```json
{
  "body": "Internal team note..."
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "type": "note",
    "body_text": "Internal team note...",
    "created_at": "2024-02-04T12:00:00Z"
  }
}
```

---

### POST /api/tickets/:ticketId/resolve

**Purpose**: Mark ticket as resolved

**Request Body**:
```json
{
  "resolution_notes": "Issue resolved - device repaired"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "resolved"
  }
}
```

---

## Push Notification Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/device_token_handlers.js]`

### POST /api/user/device-token

**Purpose**: Register device token for push notifications

**Request Body**:
```json
{
  "token": "device_token_string_from_apns",
  "platform": "ios",
  "app_type": "staff"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "registered": true
  }
}
```

---

### DELETE /api/user/device-token

**Purpose**: Unregister device token (on logout)

**Request Body**:
```json
{
  "token": "device_token_string_from_apns"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "unregistered": true
  }
}
```

---

### GET /api/user/push-preferences

**Purpose**: Get push notification preferences

**Response**:
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "order_created": true,
    "order_status_changed": true,
    "order_collected": true,
    "device_status_changed": true,
    "quote_approved": true,
    "quote_rejected": true,
    "payment_received": true,
    "new_enquiry": true,
    "enquiry_reply": true,
    "device_assigned": true
  }
}
```

---

### PUT /api/user/push-preferences

**Purpose**: Update push notification preferences

**Request Body**:
```json
{
  "enabled": true,
  "order_created": true,
  "order_status_changed": false,
  "device_assigned": true
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "order_created": true,
    "order_status_changed": false,
    "device_assigned": true
  }
}
```

---

## Client Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/client_handlers.js]`

### GET /api/clients

**Purpose**: List clients

**Query Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | Int | Page number |
| `limit` | Int | Items per page |
| `search` | String | Search email, name, phone |
| `sort` | String | `created_at`, `name`, `email` |
| `order` | String | `asc` or `desc` |

**Response**:
```json
{
  "success": true,
  "data": {
    "clients": [
      {
        "id": "uuid",
        "email": "customer@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+441234567890",
        "order_count": 5,
        "device_count": 7,
        "total_spend": 450.50,
        "created_at": "2024-01-15T14:20:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 150,
      "totalPages": 3
    }
  }
}
```

---

### GET /api/clients/:clientId

**Purpose**: Get client detail

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "customer@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "phone": "+441234567890",
    "notes": "Preferred customer",
    "address_line_1": "123 Main St",
    "address_line_2": "Apt 4",
    "city": "London",
    "county": "Greater London",
    "postcode": "SW1A 1AA",
    "country": "GB",
    "marketing_consent": true,
    "order_count": 5,
    "total_spend": 450.50,
    "created_at": "2024-01-15T14:20:00Z",
    "updated_at": "2024-02-04T10:30:00Z"
  }
}
```

---

## Error Response Format

All error responses follow this structure:

```json
{
  "success": false,
  "error": "Error message describing what went wrong",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format"
    }
  ]
}
```

**Common HTTP Status Codes**:
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/expired token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `500` - Internal Server Error

---

---

# CUSTOMER PORTAL ENDPOINTS

**All customer endpoints use a separate authentication flow from staff.**

---

## Customer Authentication Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/src/customer-auth.js]`

### POST /api/customer/auth/request-magic-link

**Purpose**: Request magic link code for customer portal login (customers use magic link only, no password)

**Request Body**:
```json
{
  "email": "customer@example.com"
}
```

**Response (Success)**:
```json
{
  "success": true,
  "data": {
    "message": "If an account exists, a login code has been sent"
  }
}
```

**Notes**: Always returns success to prevent user enumeration. Email contains 6-digit code.

---

### POST /api/customer/auth/verify-code

**Purpose**: Verify magic code and return JWT

**Request Body (Step 1 - without company selection)**:
```json
{
  "email": "customer@example.com",
  "code": "123456"
}
```

**Response (Single Company - Direct Login)**:
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "client": {
      "id": "uuid",
      "firstName": "John",
      "lastName": "Doe",
      "email": "customer@example.com",
      "name": "John Doe"
    },
    "company": {
      "id": "uuid",
      "name": "Repair Shop Ltd",
      "logoUrl": "https://api.repairminder.com/api/branding/uuid/logo"
    }
  }
}
```

**Response (Multiple Companies - Requires Selection)**:
```json
{
  "success": true,
  "data": {
    "requiresCompanySelection": true,
    "companies": [
      {
        "id": "uuid",
        "name": "Repair Shop 1",
        "logoUrl": "https://api.repairminder.com/api/branding/uuid/logo"
      },
      {
        "id": "uuid2",
        "name": "Repair Shop 2",
        "logoUrl": null
      }
    ],
    "email": "customer@example.com",
    "code": "123456"
  }
}
```

**Request Body (Step 2 - with company selection)**:
```json
{
  "email": "customer@example.com",
  "code": "123456",
  "companyId": "uuid"
}
```

---

### GET /api/customer/auth/me

**Purpose**: Get current customer session info

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "success": true,
  "data": {
    "client": {
      "id": "uuid",
      "firstName": "John",
      "lastName": "Doe",
      "email": "customer@example.com",
      "name": "John Doe"
    },
    "company": {
      "id": "uuid",
      "name": "Repair Shop Ltd",
      "logoUrl": "https://api.repairminder.com/api/branding/uuid/logo"
    }
  }
}
```

---

### POST /api/customer/auth/logout

**Purpose**: Invalidate current customer session

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "success": true,
  "data": {
    "message": "Logged out successfully"
  }
}
```

---

## Customer Order Endpoints

**Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/index.js]` (handleCustomerListOrders, handleCustomerGetOrder)

### GET /api/customer/orders

**Purpose**: List all orders for authenticated customer

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "ticket_number": 100001,
      "status": "in_progress",
      "created_at": "2024-02-04T10:30:00Z",
      "quote_sent_at": "2024-02-04T11:00:00Z",
      "quote_approved_at": null,
      "rejected_at": null,
      "updated_at": "2024-02-04T12:00:00Z",
      "devices": [
        {
          "id": "uuid",
          "status": "diagnosing",
          "display_name": "Apple iPhone 12 Pro"
        }
      ],
      "totals": {
        "subtotal": 75.00,
        "vat_total": 15.00,
        "grand_total": 90.00
      }
    }
  ],
  "currency_code": "GBP"
}
```

---

### GET /api/customer/orders/:orderId

**Purpose**: Get full order detail for customer

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "ticket_number": 100001,
    "status": "in_progress",
    "created_at": "2024-02-04T10:30:00Z",
    "collected_at": null,
    "quote_sent_at": "2024-02-04T11:00:00Z",
    "quote_approved_at": null,
    "quote_approved_method": null,
    "rejected_at": null,
    "pre_authorization": {
      "amount": 100.00,
      "notes": "Pre-authorized for screen replacement",
      "authorised_at": "2024-02-04T10:30:00Z",
      "authorised_by": {
        "first_name": "Staff",
        "last_name": "Member"
      },
      "signature": {
        "id": "uuid",
        "type": "drawn",
        "data": "base64_signature_data",
        "typed_name": null,
        "captured_at": "2024-02-04T10:30:00Z"
      }
    },
    "review_links": {
      "google": "https://search.google.com/local/writereview?placeid=...",
      "facebook": "https://facebook.com/repairshop/reviews",
      "trustpilot": "https://trustpilot.com/...",
      "yelp": null,
      "apple": null
    },
    "devices": [
      {
        "id": "uuid",
        "display_name": "Apple iPhone 12 Pro",
        "status": "awaiting_authorisation",
        "workflow_type": "repair",
        "customer_reported_issues": "Screen cracked",
        "diagnosis_notes": "Requires screen replacement",
        "serial_number": "ABC123",
        "imei": "123456789012345",
        "authorization_status": "pending",
        "authorization_method": null,
        "authorized_at": null,
        "authorization_notes": null,
        "collection_location": {
          "id": "uuid",
          "name": "Main Shop",
          "address": "123 Main St, London, SW1A 1AA",
          "phone": "020 7123 4567",
          "email": "shop@example.com",
          "google_maps_url": "https://www.google.com/maps/place/?q=place_id:...",
          "opening_hours": { "monday": "09:00-18:00" }
        },
        "deposit_paid": 50.00,
        "images": [
          {
            "id": "uuid",
            "image_type": "pre_repair",
            "url": "https://api.repairminder.com/api/customer/devices/uuid/images/uuid/file",
            "filename": "screen_damage.jpg",
            "caption": "Cracked screen",
            "uploaded_at": "2024-02-04T10:30:00Z"
          }
        ],
        "pre_repair_checklist": {
          "id": "uuid",
          "template_name": "iPhone Pre-Repair",
          "results": [
            { "name": "Screen Check", "result": "fail", "notes": "Cracked" }
          ],
          "completed_at": "2024-02-04T10:30:00Z",
          "completed_by_name": "Staff Member"
        }
      }
    ],
    "items": [
      {
        "id": "uuid",
        "description": "Screen replacement",
        "quantity": 1,
        "unit_price": 75.00,
        "vat_rate": 0.20,
        "line_total": 75.00,
        "vat_amount": 15.00,
        "line_total_inc_vat": 90.00,
        "device_id": "uuid",
        "authorization_status": "pending",
        "signature_id": null,
        "authorized_price": null
      }
    ],
    "totals": {
      "subtotal": 75.00,
      "vat_total": 15.00,
      "grand_total": 90.00,
      "deposits_paid": 50.00,
      "final_payments_paid": 0.00,
      "amount_paid": 50.00,
      "balance_due": 40.00
    },
    "messages": [
      {
        "id": "uuid",
        "type": "inbound",
        "subject": "iPhone repair request",
        "body_text": "Hi, I need my screen repaired.",
        "created_at": "2024-02-04T10:30:00Z"
      }
    ],
    "company": {
      "name": "Repair Shop Ltd",
      "phone": "020 7123 4567",
      "email": "support@repairshop.com",
      "logo_url": "https://api.repairminder.com/api/branding/uuid/logo",
      "currency_code": "GBP",
      "terms_conditions": "All repairs carry 90 day warranty...",
      "collection_storage_fee_enabled": true,
      "collection_recycling_enabled": true,
      "collection_storage_fee_daily": 5,
      "collection_storage_fee_cap": 150
    }
  }
}
```

---

### POST /api/customer/orders/:orderId/approve

**Purpose**: Approve or reject quote from customer portal with signature

**Headers**: `Authorization: Bearer {token}`

**Request Body (Approve)**:
```json
{
  "action": "approve",
  "signature_type": "drawn",
  "signature_data": "base64_encoded_signature_image",
  "amount_acknowledged": 90.00
}
```

**Request Body (Reject)**:
```json
{
  "action": "reject",
  "signature_type": "typed",
  "signature_data": "John Doe",
  "rejection_reason": "Too expensive"
}
```

**Response (Success)**:
```json
{
  "success": true,
  "data": {
    "message": "Quote approved successfully",
    "approved_at": "2024-02-04T15:00:00Z",
    "signature_id": "uuid"
  }
}
```

**Signature Types**: `typed` (name text) or `drawn` (base64 image)

---

### POST /api/customer/devices/:deviceId/authorize

**Purpose**: Per-device authorization for quotes (used when order has multiple devices)

**Headers**: `Authorization: Bearer {token}`

**Request Body (Approve)**:
```json
{
  "action": "approve",
  "signature_type": "drawn",
  "signature_data": "base64_encoded_signature"
}
```

**Request Body (Reject)**:
```json
{
  "action": "reject"
}
```

**Request Body (Proceed with Original - for revised quotes)**:
```json
{
  "action": "proceed_original"
}
```

**Note**: For buyback workflow devices, bank details are required:
```json
{
  "action": "approve",
  "signature_type": "drawn",
  "signature_data": "base64_encoded_signature",
  "bank_details": {
    "account_name": "John Doe",
    "sort_code": "12-34-56",
    "account_number": "12345678"
  }
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "message": "Device approved successfully",
    "new_status": "authorised_source_parts",
    "signature_id": "uuid"
  }
}
```

---

### POST /api/customer/orders/:orderId/reply

**Purpose**: Submit a message from customer portal (creates ticket message)

**Headers**: `Authorization: Bearer {token}`

**Request Body**:
```json
{
  "message": "I have a question about my repair...",
  "device_id": "uuid"
}
```

**Note**: `device_id` is optional. If provided, subject includes device name.

**Response**:
```json
{
  "success": true,
  "data": {
    "message_id": "uuid",
    "created_at": "2024-02-04T15:30:00Z"
  }
}
```

---

### GET /api/customer/orders/:orderId/invoice

**Purpose**: Download invoice HTML for customer

**Headers**: `Authorization: Bearer {token}`

**Response**: HTML document with `Content-Disposition: attachment; filename="Invoice-100001.html"`

---

### GET /api/customer/devices/:deviceId/images/:imageId/file

**Purpose**: Serve device image file for customer portal

**Headers**: `Authorization: Bearer {token}`

**Response**: Binary image data with appropriate `Content-Type`

---

## Customer Push Notification Registration

Customers use the same push notification endpoints as staff, but with `app_type: "customer"`:

### POST /api/user/device-token (Customer Context)

**Purpose**: Register device token for customer push notifications

**Headers**: `Authorization: Bearer {token}` (customer token)

**Request Body**:
```json
{
  "token": "device_token_string_from_apns",
  "platform": "ios",
  "app_type": "customer"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "registered": true
  }
}
```

---

## Database Changes

None (documentation stage)

## Test Cases

| Test | Expected |
|------|----------|
| **Staff Endpoints** | |
| Verify auth endpoints match | All fields documented exist in backend |
| Verify dashboard stats response | Field names match exactly |
| Verify device status enum | All 18 statuses documented |
| Verify order status enum | All 5 order statuses documented |
| Verify ticket status enum | All 4 ticket statuses documented |
| Verify pagination format | page, limit, total, total_pages present |
| **Customer Endpoints** | |
| Verify customer auth endpoints | Magic link flow works end-to-end |
| Verify customer orders list | Returns orders for authenticated customer only |
| Verify customer order detail | Returns full order with devices, items, totals |
| Verify quote approval flow | Signature captured, status updated |
| Verify customer reply | Creates ticket message as inbound type |

## Acceptance Checklist

### Staff Endpoints
- [ ] All authentication endpoints documented
- [ ] Dashboard stats endpoint documented with all periods
- [ ] Device endpoints documented with status enum
- [ ] Order endpoints documented with filters
- [ ] Ticket endpoints documented with message types
- [ ] Push notification endpoints documented
- [ ] Client endpoints documented
- [ ] Error response format documented
- [ ] All field names verified against backend handler code

### Customer Endpoints
- [ ] Customer magic link auth flow documented
- [ ] Customer verify code response documented (single & multi-company)
- [ ] Customer orders list endpoint documented
- [ ] Customer order detail endpoint documented (full response structure)
- [ ] Quote approval endpoint documented (approve/reject actions)
- [ ] Per-device authorization endpoint documented
- [ ] Customer reply endpoint documented
- [ ] Customer push notification registration documented (app_type: customer)

## Deployment

N/A (documentation stage)

## Handoff Notes

- All endpoints use `snake_case` field names
- Swift decoder must use `.convertFromSnakeCase` strategy
- Device has 18 possible statuses (17 repair + buyback)
- Pagination uses `total_pages` not `totalPages`
- All timestamps are ISO8601 format in UTC
- [See: Stage 02] for model implementation using this documentation
