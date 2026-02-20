# Cross-Project Sync Rule — MANDATORY

Repair Minder is a multi-platform system. The Apple apps (iPhone, iPad, Mac) and web app/API share API contracts. All three Apple platforms live in one Xcode project and share the same Swift models and services. **Every API-touching task MUST be checked against this rule before completion. This is not optional.**

## Project Locations

- **Apple apps (iPhone / iPad / Mac):** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS`
  - **Shared Swift models & services:** `Repair Minder/Repair Minder/` (used by all three platforms)
  - **macOS-specific code:** `Repair Minder/Repair Minder Mac/`
  - **Xcode project:** `Repair Minder/Repair Minder.xcodeproj`
- **Web app + API (Cloudflare Workers):** `/Volumes/Riki Repos/repairminder`

## HARD REQUIREMENTS

You MUST do ALL of the following for any Apple app task that touches or depends on API endpoints, response shapes, request bodies, auth, or push notifications:

### 1. Before Starting Work

- **Read the backend route handler** in `/Volumes/Riki Repos/repairminder/worker/src/` to confirm the actual request/response shape. Do not assume — open and read the JS handler files.
- **Identify the exact API response fields** the app code needs. Compare them against what the backend actually returns.
- **Consider all three platforms.** Shared models/services affect iPhone, iPad, AND Mac simultaneously. Platform-specific code (`#if os(macOS)` / `#if os(iOS)`) only affects one platform.

### 2. During Implementation

- **Do not add Swift model fields that don't exist in the API.** If you need a new field, flag that the backend must add it first.
- **All API field names are `snake_case`.** The decoder uses `.convertFromSnakeCase`. Do NOT add explicit CodingKeys raw values for standard snake_case conversion — let the decoder handle it.
- **Match types exactly.** If the API returns a nullable field, the Swift property must be Optional. If it returns an Int, don't decode as String.
- **Flag backend changes needed BEFORE writing app code.** The backend change must land first.
- **Platform-specific API calls.** Device token registration uses `"ios"` for iPhone/iPad and `"macos"` for Mac. Camera/scanner features are iOS-only (`#if os(iOS)`).

### 3. Before Completing the Task — MANDATORY SYNC GATE

**STOP. Do not mark the task as complete until you have answered every question below:**

| Question | If YES |
|----------|--------|
| Does this consume an API endpoint? | Read the backend handler and verify the response shape matches the Swift model exactly. |
| Does this need a new field from the API? | Flag that the backend must add it. Specify the endpoint, field name, type, and whether it's nullable. |
| Does this need a new endpoint? | Flag that the backend must create it. Specify path, HTTP method, request/response types. |
| Does this change auth flow or token handling? | All projects MUST be updated together. |
| Does this affect push notifications? | Check APNs config and backend push triggers for all platforms. macOS has separate entitlements. Verify payload shape matches. |
| Does this affect the customer portal? | Web and all Apple client views must match. |
| Does this change how magic links / deep links work? | All projects must handle the new flow. |
| Is this platform-specific (Mac-only or iOS-only)? | Use `#if os(macOS)` / `#if os(iOS)` guards. Ensure shared models remain compatible with all platforms. |

**If you cannot answer "no" to all of the above, you are not done.**

### 4. How to Flag Backend Impact

When backend changes are needed, output a clear block like this:

```
## Backend Sync Required

**Endpoint:** GET /api/orders/:id
**Change needed:** Add `tracking_url` field (string, nullable) to response
**Backend file:** worker/src/order_handlers.js

**Platforms affected:** iPhone, iPad, Mac (shared model)
**Breaking:** No (additive only)
**Deploy order:** Backend first, then Apple app update
```

Do not bury this in a paragraph. Make it impossible to miss.

### 5. Document the Dependency

When a task spans both projects:
- Note which project changes must land first (usually backend before Apple apps)
- If changes are breaking, both must ship together — flag this as a blocking dependency
- Remember: one Swift model change propagates to all three Apple platforms

## Platform Notes

- **iPhone & iPad** share the same iOS target — iPad uses adaptive layouts but the same models/services
- **Mac** is a separate native macOS target but shares models/services via shared file membership
- **Device tokens:** iPhone and iPad register as `"ios"`, Mac registers as `"macos"`
- **Camera/scanner:** Not available on Mac — uses text-entry device lookup instead (`#if os(iOS)` / `#if os(macOS)`)
- **Push notifications:** All three platforms receive pushes but have separate entitlements files
- **Platform guards:** Use `#if os(macOS)` and `#if os(iOS)` for platform-specific code. Shared code must compile on both.

## Common Mistakes to Avoid

- Assuming a field exists in the API without reading the handler
- Adding CodingKeys raw values like `case ticketNumber = "ticket_number"` when `.convertFromSnakeCase` handles it automatically
- Decoding flexible types (Int/String/Double) without using `FlexibleString` or try-catch patterns
- Building features against an API shape that doesn't exist yet without flagging it
- Forgetting that `is_active` style booleans come as Int (0/1) from D1/SQLite
- Forgetting that shared model changes affect iPhone, iPad, AND Mac simultaneously
- Using iOS-only APIs (UIKit, AVFoundation camera) in shared code without `#if os(iOS)` guards
