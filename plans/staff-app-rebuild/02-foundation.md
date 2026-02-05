# Stage 02: Authentication

## Objective

Implement dual authentication flows for Staff and Customer roles with token refresh and secure storage.

---

## ⚠️ Pre-Implementation Verification

**Before writing any code, verify the following against the backend source files:**

1. **Staff auth flow** - Read `/Volumes/Riki Repos/repairminder/worker/src/auth.js` and verify:
   - Login response shape (especially `requiresTwoFactor` field)
   - 2FA verify response (token, refreshToken, expiresIn, user, company)
   - Magic link flow in same file

2. **Customer auth flow** - Read `/Volumes/Riki Repos/repairminder/worker/src/customer-auth.js` and verify:
   - Magic link request/verify endpoints
   - `requiresCompanySelection` multi-company response
   - Customer JWT claims structure

3. **Token refresh** - Confirm refresh token rotation behavior and `isMobile` detection

```bash
# Quick verification commands
grep -n "requiresTwoFactor\|_issueTokenPair" /Volumes/Riki\ Repos/repairminder/worker/src/auth.js | head -10
grep -n "requiresCompanySelection" /Volumes/Riki\ Repos/repairminder/worker/src/customer-auth.js
```

**Do not proceed until you've verified the auth response shapes match this documentation.**

---

## API Reference

### Staff Login Flow (Email/Password + Mandatory 2FA)

All staff password logins require a two-step process with email-based 2FA.

#### Step 1: Validate Credentials

```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "staff@example.com",
  "password": "password123"
}
```

**Response (always requires 2FA):**
```json
{
  "requiresTwoFactor": true,
  "userId": "uuid",
  "email": "staff@example.com",
  "user": {
    "id": "uuid",
    "email": "staff@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "companyId": "uuid"
  }
}
```

**Error Responses:**
- `401` - "Invalid credentials" (wrong email or password)
- `401` - "Account is deactivated"
- `401` - "Account has been archived and cannot login"
- `401` - "No password set. Please use Magic Link login or set a password in Settings."

#### Step 2: Request 2FA Code

```http
POST /api/auth/2fa/request
Content-Type: application/json

{
  "userId": "uuid",
  "email": "staff@example.com"
}
```

**Response:**
```json
{
  "message": "2FA code sent to your email"
}
```

A 6-digit code is emailed to the user.

#### Step 3: Verify 2FA Code

```http
POST /api/auth/2fa/verify
Content-Type: application/json

{
  "userId": "uuid",
  "code": "123456"
}
```

**Success Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "opaque_refresh_token_string",
  "expiresIn": 900,
  "user": {
    "id": "uuid",
    "email": "staff@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "company_id": "uuid",
    "role": "admin",
    "phi_access_level": "full",
    "data_classification": "internal",
    "is_active": 1,
    "magic_link_enabled": 1,
    "company_status": "active"
  },
  "company": {
    "id": "uuid",
    "name": "Acme Repairs",
    "status": "active",
    "currency_code": "GBP",
    "vat_number": "GB123456789",
    "logo_url": "https://...",
    "vat_rate_repair": "20.00",
    "vat_rate_device_sale": "20.00",
    "vat_rate_accessory": "20.00",
    "vat_rate_device_purchase": "0.00"
  }
}
```

**Note:** The code can also be a TOTP code (6 digits) or recovery code (8 alphanumeric chars) if the user has app-based 2FA enabled.

---

### Staff Magic Link Flow (Alternative to Password)

For users who prefer passwordless login or don't have a password set.

#### Step 1: Request Magic Link

```http
POST /api/auth/magic-link/request
Content-Type: application/json

{
  "email": "staff@example.com"
}
```

**Response:**
```json
{
  "message": "Magic link sent"
}
```

A 6-digit code is emailed to the user.

#### Step 2: Verify Magic Link Code

```http
POST /api/auth/magic-link/verify-code
Content-Type: application/json

{
  "email": "staff@example.com",
  "code": "123456"
}
```

**Success Response:** (Same structure as 2FA verify)
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "opaque_refresh_token_string",
  "expiresIn": 900,
  "user": { ... },
  "company": { ... }
}
```

---

### Customer Magic Link Flow (No Passwords)

Customer portal uses magic links only - no password authentication.

#### Step 1: Request Magic Link

```http
POST /api/customer/auth/request-magic-link
Content-Type: application/json

{
  "email": "customer@example.com",
  "companyId": "uuid"  // Optional - required on custom domains
}
```

**Response (always the same to prevent enumeration):**
```json
{
  "message": "If an account exists, a login code has been sent"
}
```

#### Step 2: Verify Code

```http
POST /api/customer/auth/verify-code
Content-Type: application/json

{
  "email": "customer@example.com",
  "code": "123456",
  "companyId": "uuid"  // Optional first time
}
```

**Single Company Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "client": {
    "id": "uuid",
    "firstName": "Jane",
    "lastName": "Customer",
    "email": "customer@example.com",
    "name": "Jane Customer"
  },
  "company": {
    "id": "uuid",
    "name": "Acme Repairs",
    "logoUrl": "https://api.repairminder.com/api/branding/uuid/logo"
  }
}
```

**Multiple Companies Response (requires selection):**
```json
{
  "requiresCompanySelection": true,
  "companies": [
    {
      "id": "uuid1",
      "name": "Acme Repairs",
      "logoUrl": "https://..."
    },
    {
      "id": "uuid2",
      "name": "Beta Tech",
      "logoUrl": null
    }
  ],
  "email": "customer@example.com",
  "code": "123456"
}
```

When `requiresCompanySelection: true`, call verify again with `companyId` to complete login.

---

### Token Refresh

```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refreshToken": "opaque_refresh_token_string"
}
```

**Response:**
```json
{
  "token": "new_jwt_access_token",
  "refreshToken": "new_opaque_refresh_token",
  "expiresIn": 900
}
```

**Token Lifetimes:**
| Client Type | Access Token | Refresh Token |
|-------------|--------------|---------------|
| Web | 15 minutes | 7 days |
| Mobile | 15 minutes | 90 days |

Mobile detection uses User-Agent header patterns: `Mobile`, `Android`, `iPhone`, `iPad`, `iPod`

**Security Features:**
- Refresh tokens are single-use (rotation on each refresh)
- Stolen token detection: reusing a revoked token revokes the entire token family
- Sliding expiry: each refresh extends the refresh token lifetime

**Error Responses:**
- `401` - "Invalid refresh token"
- `401` - "Refresh token expired"
- `401` - "User account is no longer active"
- `401` - "Token reuse detected. All sessions revoked. Please log in again."

---

### Get Current User

```http
GET /api/auth/me
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "user": { ... },
  "company": { ... },
  "hasPassword": true
}
```

---

### Logout

```http
POST /api/auth/logout
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "success": true
}
```

Revokes the entire refresh token family for this session.

---

## Data Models

### User Model (Staff)

```swift
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String?      // API: first_name
    let lastName: String?       // API: last_name
    let companyId: String       // API: company_id
    let role: UserRole
    let phiAccessLevel: String? // API: phi_access_level
    let dataClassification: String? // API: data_classification
    let isActive: Bool          // API: is_active (0/1 in API)
    let magicLinkEnabled: Bool? // API: magic_link_enabled
    let companyStatus: String?  // API: company_status
    let lastLogin: String?      // API: last_login
    let createdAt: String?      // API: created_at
    let updatedAt: String?      // API: updated_at
}
```

### UserRole Enum

```swift
enum UserRole: String, Codable {
    case masterAdmin = "master_admin"
    case admin = "admin"
    case seniorEngineer = "senior_engineer"
    case engineer = "engineer"
    case office = "office"
}
```

### Company Model

```swift
struct Company: Codable, Identifiable {
    let id: String
    let name: String
    let status: String              // "active", "pending_approval", "suspended"
    let currencyCode: String?       // API: currency_code
    let vatNumber: String?          // API: vat_number
    let logoUrl: String?            // API: logo_url
    let vatRateRepair: String?      // API: vat_rate_repair
    let vatRateDeviceSale: String?  // API: vat_rate_device_sale
    let vatRateAccessory: String?   // API: vat_rate_accessory
    let vatRateDevicePurchase: String? // API: vat_rate_device_purchase
}
```

### Client Model (Customer)

```swift
struct Client: Codable, Identifiable {
    let id: String
    let firstName: String?  // API: first_name
    let lastName: String?   // API: last_name
    let email: String
    let name: String?       // Full name
}
```

### JWT Claims

**Staff JWT:**
```json
{
  "userId": "uuid",
  "companyId": "uuid",
  "role": "admin",
  "phiAccessLevel": "full",
  "isMobile": true,
  "dataClassification": "internal",
  "permissions": []
}
```

**Customer JWT:**
```json
{
  "type": "customer",
  "clientId": "uuid",
  "companyId": "uuid",
  "email": "customer@example.com",
  "scope": "customer_portal",
  "issuedAt": 1234567890,
  "sessionId": "uuid"
}
```

---

## Quarantine Mode

Users from companies with `status = 'pending_approval'` or `status = 'suspended'` have restricted API access.

**Allowed endpoints during quarantine:**
- `/api/auth/me`, `/api/auth/logout`, `/api/auth/refresh`
- `/api/companies/{id}` (own company only)
- `/api/company-locations/*`
- `/api/users/me`, `/api/users/me/avatar`
- `/api/subscription/features`

All other endpoints return `403` with:
```json
{
  "error": "Your account is pending approval...",
  "code": "ACCOUNT_PENDING_APPROVAL"
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Models/User.swift` | User, Company, Client models |
| `Core/Models/AuthModels.swift` | Login request/response types |
| `Core/Auth/AuthManager.swift` | Staff authentication |
| `Core/Auth/CustomerAuthManager.swift` | Customer authentication |
| `Core/Auth/KeychainManager.swift` | Secure token storage |
| `Core/Auth/TokenRefreshInterceptor.swift` | Auto-refresh on 401 |
| `App/UserRole.swift` | Staff/Customer enum |
| `App/AppState.swift` | Global auth state |
| `Features/Auth/RoleSelectionView.swift` | Choose Staff or Customer |
| `Features/Auth/StaffLoginView.swift` | Email/password form |
| `Features/Auth/TwoFactorView.swift` | 2FA code entry |
| `Features/Auth/MagicLinkView.swift` | Magic link code entry |
| `Features/Auth/CustomerLoginView.swift` | Customer email entry |
| `Features/Auth/CompanySelectionView.swift` | Multi-company picker |

---

## Implementation Notes

### Mobile User-Agent

Set User-Agent to include iOS identifiers for 90-day refresh tokens:
```swift
"RepairMinder-iOS/1.0 (iPhone; iOS 17.0)"
```

### Token Storage

Store in Keychain with attributes:
- `kSecAttrAccessible`: `.afterFirstUnlock` (background refresh support)
- Separate keys for access token, refresh token, user data

### Auto-Refresh Strategy

1. Intercept all API responses
2. On `401 Unauthorized`, attempt token refresh
3. If refresh succeeds, retry original request
4. If refresh fails, clear tokens and return to login

### Logout Cleanup

On logout, clear:
- Access token from Keychain
- Refresh token from Keychain
- Cached user data
- Any local state

---

## Testing

### Test Tokens

Reference: `docs/REFERENCE-test-tokens/CLAUDE.md`

### Generate Magic Link Codes

```bash
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT magic_link_code FROM users WHERE email = 'test@example.com'"
```

### Manual Testing with curl

```bash
# Staff login step 1
curl -X POST https://api.repairminder.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"staff@example.com","password":"test123"}'

# Staff 2FA request
curl -X POST https://api.repairminder.com/api/auth/2fa/request \
  -H "Content-Type: application/json" \
  -d '{"userId":"uuid","email":"staff@example.com"}'

# Staff 2FA verify
curl -X POST https://api.repairminder.com/api/auth/2fa/verify \
  -H "Content-Type: application/json" \
  -d '{"userId":"uuid","code":"123456"}'

# Token refresh
curl -X POST https://api.repairminder.com/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"opaque_token"}'

# Customer magic link request
curl -X POST https://api.repairminder.com/api/customer/auth/request-magic-link \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@example.com"}'
```

---

## Verification Checklist

- [ ] Staff can login with email/password + 2FA
- [ ] Staff can login with magic link
- [ ] Customer can login with magic link
- [ ] Multi-company customer can select company
- [ ] Token refresh works automatically on 401
- [ ] Refresh token rotation works (old token invalid)
- [ ] Logout clears all tokens
- [ ] Role selection persists between launches
- [ ] Quarantine mode restricts suspended accounts
- [ ] Mobile User-Agent gets 90-day refresh tokens

---

## Next Stage

Once authentication works, proceed to Stage 03: Dashboard.
