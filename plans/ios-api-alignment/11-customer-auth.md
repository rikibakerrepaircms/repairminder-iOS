# Stage 11: Customer Auth

## Objective

Fix customer app magic link authentication flow to work with actual backend endpoints.

## Dependencies

- **Requires**: Stage 04 complete (API client patterns established)

## Complexity

**Medium** - Auth flow needs verification, company selection handling

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Customer/Auth/CustomerLoginView.swift` | Update bindings |
| `Repair Minder/Customer/Auth/CustomerLoginViewModel.swift` | Fix API calls |
| `Repair Minder/Customer/Auth/CustomerAuthService.swift` | If exists, update |
| `Repair Minder/Core/Networking/APIEndpoints.swift` | Already updated |

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Customer/Auth/CustomerAuthManager.swift` | Manage customer auth state |

## Backend Reference

### Endpoints

| Endpoint | Method | Request | Response |
|----------|--------|---------|----------|
| `/api/customer/auth/request-magic-link` | POST | `{ email, companyId? }` | `{ success, data: { message } }` |
| `/api/customer/auth/verify-code` | POST | `{ email, code, companyId? }` | `{ success, data: { token, companies? } }` |
| `/api/customer/auth/me` | GET | - | `{ success, data: { clientId, email, companyId } }` |
| `/api/customer/auth/logout` | POST | - | `{ success }` |
| `/api/customer/order-access/:token` | GET | - | `{ success, data: { token, orderId } }` |

### Company Selection Flow

1. Customer enters email, requests magic link
2. Customer enters code
3. If customer has multiple companies, backend returns `companies` array
4. Customer selects company
5. Call verify-code again with `companyId`
6. Backend returns final JWT token

## Implementation Details

### 1. CustomerAuthManager

```swift
// Repair Minder/Customer/Auth/CustomerAuthManager.swift

import Foundation
import os.log

@MainActor
@Observable
final class CustomerAuthManager {
    static let shared = CustomerAuthManager()

    private(set) var isAuthenticated = false
    private(set) var currentEmail: String?
    private(set) var currentCompanyId: String?

    private let tokenKey = "customer_auth_token"
    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder-Customer", category: "Auth")

    private init() {
        // Check for existing token
        if let _ = KeychainHelper.get(tokenKey) {
            isAuthenticated = true
        }
    }

    var token: String? {
        KeychainHelper.get(tokenKey)
    }

    func saveToken(_ token: String) {
        KeychainHelper.save(token, forKey: tokenKey)
        isAuthenticated = true
    }

    func logout() async {
        // Call logout endpoint
        do {
            try await APIClient.shared.requestVoid(.customerLogout())
        } catch {
            logger.error("Logout API failed: \(error.localizedDescription)")
        }

        // Clear local state
        KeychainHelper.delete(tokenKey)
        isAuthenticated = false
        currentEmail = nil
        currentCompanyId = nil
    }
}
```

### 2. CustomerLoginViewModel

```swift
@MainActor
@Observable
final class CustomerLoginViewModel {
    // State
    var email = ""
    var verificationCode = ""
    private(set) var isLoading = false
    private(set) var codeSent = false
    private(set) var needsCompanySelection = false
    private(set) var companies: [CustomerCompany] = []
    var error: String?

    // MARK: - Request Magic Link

    func requestMagicLink() async {
        guard !email.isEmpty else {
            error = "Please enter your email"
            return
        }

        isLoading = true
        error = nil

        do {
            let _: MagicLinkResponse = try await APIClient.shared.request(
                .customerRequestMagicLink(email: email),
                responseType: MagicLinkResponse.self
            )
            codeSent = true
        } catch {
            self.error = "Failed to send verification code"
        }

        isLoading = false
    }

    // MARK: - Verify Code

    func verifyCode(companyId: String? = nil) async {
        guard !verificationCode.isEmpty else {
            error = "Please enter the verification code"
            return
        }

        isLoading = true
        error = nil

        do {
            let response: VerifyCodeResponse = try await APIClient.shared.request(
                .customerVerifyCode(email: email, code: verificationCode, companyId: companyId),
                responseType: VerifyCodeResponse.self
            )

            if let token = response.token {
                // Login complete
                CustomerAuthManager.shared.saveToken(token)
            } else if let companies = response.companies, !companies.isEmpty {
                // Need to select company
                self.companies = companies
                needsCompanySelection = true
            } else {
                error = "Invalid response from server"
            }
        } catch {
            self.error = "Invalid verification code"
        }

        isLoading = false
    }

    // MARK: - Select Company

    func selectCompany(_ company: CustomerCompany) async {
        await verifyCode(companyId: company.id)
    }
}

// MARK: - Response Types

struct MagicLinkResponse: Decodable {
    let message: String?
}

struct VerifyCodeResponse: Decodable {
    let token: String?
    let companies: [CustomerCompany]?
}

struct CustomerCompany: Identifiable, Decodable {
    let id: String
    let name: String
}
```

### 3. Order Access Token Flow

For direct order access via magic link:

```swift
func verifyOrderAccess(token: String) async {
    do {
        let response: OrderAccessResponse = try await APIClient.shared.request(
            .customerOrderAccess(token: token),
            responseType: OrderAccessResponse.self
        )

        // Save the order-scoped token
        CustomerAuthManager.shared.saveToken(response.token)

        // Navigate to specific order
        // Note: This token only allows access to one order
    } catch {
        self.error = "This link has expired"
    }
}

struct OrderAccessResponse: Decodable {
    let token: String
    let orderId: String
}
```

### 4. Login View Flow

```
1. Show email input
2. User enters email, taps "Send Code"
3. Show code input
4. User enters code, taps "Verify"
5. If companies returned:
   - Show company picker
   - User selects company
   - Call verify again with companyId
6. Token saved, navigate to main app
```

### 5. APIClient Customer Auth Header

Ensure APIClient uses customer token when in customer app:

```swift
// In APIClient request method
if let token = CustomerAuthManager.shared.token {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

## Database Changes

None

## Test Cases

| Test | Expected |
|------|----------|
| Enter email, request code | Success message, code input shown |
| Enter valid code (single company) | Token saved, logged in |
| Enter valid code (multi company) | Company picker shown |
| Select company | Token saved, logged in |
| Enter invalid code | Error message |
| Order access token | Direct login to order |
| Logout | Token cleared, login shown |

## Acceptance Checklist

- [ ] Magic link request sends to correct endpoint
- [ ] Verify code uses correct endpoint
- [ ] Company selection flow works
- [ ] Token saved securely in Keychain
- [ ] Order access token flow works
- [ ] Logout clears token and calls API
- [ ] Auth state persists across app restart
- [ ] Error messages display correctly

## Deployment

1. Build and run customer app target
2. Enter email to request magic link
3. Check email for code
4. Enter code to verify
5. If multiple companies, select one
6. Verify login completes
7. Restart app, verify still logged in
8. Logout and verify token cleared

## Handoff Notes

- Customer JWT is different from staff JWT
- Order-scoped tokens only allow access to one order
- Company selection is required for multi-company customers
- Token storage should use separate Keychain key from staff app
