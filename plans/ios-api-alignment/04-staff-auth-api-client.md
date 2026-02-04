# Stage 04: Staff Auth & API Client

## Objective

Verify staff authentication flow works and fix API client response handling patterns.

## Dependencies

- **Requires**: Stages 01-03 complete (models fixed)

## Complexity

**Medium** - Auth endpoints likely work, focus on response wrapper handling

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Core/Networking/APIClient.swift` | Verify response handling, add debug logging |
| `Repair Minder/Core/Networking/APIResponse.swift` | Verify wrapper structure matches backend |
| `Repair Minder/Features/Auth/LoginViewModel.swift` | Verify login flow |
| `Repair Minder/Features/Auth/MagicLinkViewModel.swift` | Verify magic link flow |

## Files to Create

None

## Backend Reference

### Auth Endpoints

| Endpoint | Method | Handler |
|----------|--------|---------|
| `/api/auth/login` | POST | `handleLogin` |
| `/api/auth/logout` | POST | `handleLogout` |
| `/api/auth/refresh` | POST | `handleRefreshToken` |
| `/api/auth/me` | GET | `handleGetMe` |
| `/api/auth/magic-link/request` | POST | `handleRequestMagicLink` |
| `/api/auth/magic-link/verify-code` | POST | `handleVerifyMagicLinkCode` |

### Standard Response Wrapper

Most backend endpoints return:
```json
{
  "success": true,
  "data": { ... actual payload ... }
}
```

But some endpoints return data directly without the wrapper. Document which ones.

## Implementation Details

### 1. Verify APIResponse.swift

```swift
/// Standard API response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}
```

### 2. Add Debug Logging to APIClient

Add temporary debug logging to catch decode failures:

```swift
// In APIClient.swift request method
func request<T: Decodable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
    // ... existing code ...

    do {
        let response = try decoder.decode(APIResponse<T>.self, from: data)
        // ...
    } catch let DecodingError.keyNotFound(key, context) {
        #if DEBUG
        logger.error("Missing key: \(key.stringValue) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.debug("Response: \(jsonString.prefix(500))")
        }
        #endif
        throw error
    } catch let DecodingError.typeMismatch(type, context) {
        #if DEBUG
        logger.error("Type mismatch: expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        #endif
        throw error
    }
}
```

### 3. Verify Auth Endpoints Match

Check `APIEndpoints.swift` auth section matches backend:

```swift
// Verify these match backend exactly:

static func login(email: String, password: String, twoFactorToken: String? = nil) -> APIEndpoint {
    // Body: { email, password, twoFactorToken? }
}

static func requestMagicLink(email: String) -> APIEndpoint {
    // Body: { email }
    // Path: /api/auth/magic-link/request
}

static func verifyMagicLinkCode(email: String, code: String) -> APIEndpoint {
    // Body: { email, code }
    // Path: /api/auth/magic-link/verify-code
}
```

### 4. Verify Login Response Model

Read backend `handleLogin` to get exact response:

```swift
struct LoginResponse: Codable {
    let token: String
    let refreshToken: String
    let user: User
    // ... verify all fields
}
```

### 5. Verify Magic Link Response Model

Read backend `handleVerifyMagicLinkCode` to get exact response.

## Verification Steps

1. Search for auth handlers:
   ```bash
   grep -n "handleLogin\|handleRequestMagicLink" \
     /Volumes/Riki\ Repos/repairminder/worker/index.js | head -10
   ```

2. Read each handler to document request/response format

3. Compare with iOS implementation

## Database Changes

None

## Test Cases

| Test | Steps | Expected |
|------|-------|----------|
| Login success | Valid credentials | Token received, user object populated |
| Login failure | Invalid credentials | Error message displayed |
| Magic link request | Valid email | Success response, code sent |
| Magic link verify | Valid code | Token received |
| Token refresh | Expired access token | New tokens received |
| Auth persistence | App restart | User remains logged in |

## Acceptance Checklist

- [ ] Login endpoint path and body match backend
- [ ] Magic link request endpoint matches backend
- [ ] Magic link verify endpoint matches backend
- [ ] Logout endpoint matches backend
- [ ] Token refresh endpoint matches backend
- [ ] APIClient has debug logging for decode errors
- [ ] Login flow works end-to-end
- [ ] Magic link flow works end-to-end

## Deployment

Test authentication manually:
1. Build and run app
2. Attempt login with valid credentials
3. Check Xcode console for any decode errors
4. Verify token is stored
5. Verify `/api/auth/me` returns user data

## Handoff Notes

- If any auth response formats differ, document exact changes needed
- Debug logging can be removed after all stages complete
- Note any endpoints that don't use standard `APIResponse` wrapper
