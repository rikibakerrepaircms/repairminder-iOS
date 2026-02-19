# Cross-Project Sync Rule — MANDATORY

Repair Minder is a two-project system. The iOS app and web app/API share API contracts. **Every API-touching task MUST be checked against this rule before completion. This is not optional.**

## Project Locations

- **iOS app:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS`
- **Web app + API (Cloudflare Workers):** `/Volumes/Riki Repos/repairminder`

## HARD REQUIREMENTS

You MUST do ALL of the following for any iOS task that touches or depends on API endpoints, response shapes, request bodies, auth, or push notifications:

### 1. Before Starting Work

- **Read the backend route handler** in `/Volumes/Riki Repos/repairminder/worker/src/` to confirm the actual request/response shape. Do not assume — open and read the JS handler files.
- **Identify the exact API response fields** the iOS code needs. Compare them against what the backend actually returns.

### 2. During Implementation

- **Do not add Swift model fields that don't exist in the API.** If you need a new field, flag that the backend must add it first.
- **All API field names are `snake_case`.** The iOS decoder uses `.convertFromSnakeCase`. Do NOT add explicit CodingKeys raw values for standard snake_case conversion — let the decoder handle it.
- **Match types exactly.** If the API returns a nullable field, the Swift property must be Optional. If it returns an Int, don't decode as String.
- **Flag backend changes needed BEFORE writing iOS code.** The backend change must land first.

### 3. Before Completing the Task — MANDATORY SYNC GATE

**STOP. Do not mark the task as complete until you have answered every question below:**

| Question | If YES |
|----------|--------|
| Does this consume an API endpoint? | Read the backend handler and verify the response shape matches the Swift model exactly. |
| Does this need a new field from the API? | Flag that the backend must add it. Specify the endpoint, field name, type, and whether it's nullable. |
| Does this need a new endpoint? | Flag that the backend must create it. Specify path, HTTP method, request/response types. |
| Does this change auth flow or token handling? | Both projects MUST be updated together. |
| Does this affect push notifications? | Check both APNs config and backend push triggers. Verify payload shape matches. |
| Does this affect the customer portal? | Web and iOS customer views must both match. |
| Does this change how magic links / deep links work? | Both projects must handle the new flow. |

**If you cannot answer "no" to all of the above, you are not done.**

### 4. How to Flag Backend Impact

When backend changes are needed, output a clear block like this:

```
## Backend Sync Required

**Endpoint:** GET /api/orders/:id
**Change needed:** Add `tracking_url` field (string, nullable) to response
**Backend file:** worker/src/order_handlers.js

**Breaking:** No (additive only)
**Deploy order:** Backend first, then iOS update
```

Do not bury this in a paragraph. Make it impossible to miss.

### 5. Document the Dependency

When a task spans both projects:
- Note which project changes must land first (usually backend before iOS)
- If changes are breaking, both must ship together — flag this as a blocking dependency

## Common Mistakes to Avoid

- Assuming a field exists in the API without reading the handler
- Adding CodingKeys raw values like `case ticketNumber = "ticket_number"` when `.convertFromSnakeCase` handles it automatically
- Decoding flexible types (Int/String/Double) without using `FlexibleString` or try-catch patterns
- Building iOS features against an API shape that doesn't exist yet without flagging it
- Forgetting that `is_active` style booleans come as Int (0/1) from D1/SQLite
