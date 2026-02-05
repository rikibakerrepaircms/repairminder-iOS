# Stage 02 — iOS: Core Service

## Objective

Create `PasscodeService` with backend API integration, local hash caching in Keychain, and biometric authentication support.

## Dependencies

`[Requires: Stage 01 complete]` — Backend endpoints must exist for set/verify/reset/timeout.

## Complexity

**Medium** — API calls, Keychain caching, SHA-256 hashing, LocalAuthentication framework.

---

## Files to Create

### 1. `Core/Auth/PasscodeAPIModels.swift`

**Purpose:** Request/response models for passcode API endpoints.

```swift
import Foundation

// MARK: - Set Passcode

struct SetPasscodeRequest: Encodable {
    let passcode: String
}

struct SetPasscodeResponse: Decodable {
    let message: String
}

// MARK: - Verify Passcode

struct VerifyPasscodeRequest: Encodable {
    let passcode: String
}

struct VerifyPasscodeResponse: Decodable {
    let valid: Bool
    let passcodeHash: String?
    let passcodeSalt: String?
}

// MARK: - Change Passcode

struct ChangePasscodeRequest: Encodable {
    let currentPasscode: String
    let newPasscode: String
}

struct ChangePasscodeResponse: Decodable {
    let message: String
    let passcodeHash: String?
    let passcodeSalt: String?
}

// MARK: - Reset Passcode

struct ResetPasscodeRequestBody: Encodable {}

struct ResetPasscodeRequestResponse: Decodable {
    let message: String
}

struct ResetPasscodeRequest: Encodable {
    let code: String
    let newPasscode: String
}

struct ResetPasscodeResponse: Decodable {
    let message: String
    let passcodeHash: String?
    let passcodeSalt: String?
}

// MARK: - Timeout

struct PasscodeTimeoutRequest: Encodable {
    let minutes: Int
}

struct PasscodeTimeoutResponse: Decodable {
    let passcodeTimeoutMinutes: Int
}
```

### 2. `Core/Services/PasscodeService.swift`

**Purpose:** Singleton managing all passcode operations — API calls, local verification, biometric auth, lock state.

```swift
import Foundation
import LocalAuthentication
import CryptoKit

@MainActor
final class PasscodeService: ObservableObject {
    static let shared = PasscodeService()

    // MARK: - Published State
    @Published private(set) var hasPasscode: Bool = false
    @Published private(set) var passcodeEnabled: Bool = false
    @Published private(set) var isBiometricEnabled: Bool = false
    @Published private(set) var biometricType: BiometricType = .none
    @Published private(set) var timeoutMinutes: Int = 15
    @Published var isLocked: Bool = false

    // MARK: - Types
    enum BiometricType {
        case none, touchID, faceID

        var displayName: String {
            switch self {
            case .none: return "Biometric"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }

        var systemImage: String {
            switch self {
            case .none: return "lock"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            }
        }
    }

    enum PasscodeError: LocalizedError {
        case incorrectPasscode
        case biometricNotAvailable
        case biometricFailed(String)
        case biometricCancelled
        case apiError(String)
        case noPasscodeSet

        var errorDescription: String? {
            switch self {
            case .incorrectPasscode: return "Incorrect passcode"
            case .biometricNotAvailable: return "Biometric authentication not available"
            case .biometricFailed(let msg): return msg
            case .biometricCancelled: return "Authentication cancelled"
            case .apiError(let msg): return msg
            case .noPasscodeSet: return "No passcode set"
            }
        }
    }

    // MARK: - Private
    private let keychain = KeychainManager.shared
    private let apiClient: APIClient  // Reference to existing shared APIClient

    private init() {
        self.apiClient = APIClient.shared
        loadLocalState()
        checkBiometricAvailability()
    }

    // MARK: - Local State

    func loadLocalState() {
        hasPasscode = keychain.getPasscodeHash() != nil
        isBiometricEnabled = keychain.isBiometricEnabled()
        timeoutMinutes = keychain.getPasscodeTimeout() ?? 15
    }

    /// Called after login — syncs server state to local
    func syncFromAuthResponse(hasPasscode: Bool, passcodeEnabled: Bool, timeoutMinutes: Int) {
        self.hasPasscode = hasPasscode
        self.passcodeEnabled = passcodeEnabled
        self.timeoutMinutes = timeoutMinutes
        keychain.setPasscodeTimeout(timeoutMinutes)
    }

    // MARK: - Biometric

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        switch context.biometryType {
        case .faceID:  biometricType = .faceID
        case .touchID: biometricType = .touchID
        default:       biometricType = .none
        }
    }

    var isBiometricAvailable: Bool { biometricType != .none }

    func setBiometric(enabled: Bool) {
        keychain.setBiometricEnabled(enabled)
        isBiometricEnabled = enabled
    }

    func authenticateWithBiometric() async -> Result<Void, PasscodeError> {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Repair Minder"
            )
            return success ? .success(()) : .failure(.biometricFailed("Authentication failed"))
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                return .failure(.biometricCancelled)
            default:
                return .failure(.biometricFailed(error.localizedDescription))
            }
        } catch {
            return .failure(.biometricFailed(error.localizedDescription))
        }
    }

    // MARK: - Set Passcode (first time, server-side)

    func setPasscode(_ passcode: String) async throws {
        let request = SetPasscodeRequest(passcode: passcode)
        let _: SetPasscodeResponse = try await apiClient.request(
            endpoint: "/api/auth/set-passcode",
            method: .post,
            body: request
        )
        // Verify immediately to get hash + salt for local cache
        try await verifyAndCachePasscode(passcode)
        hasPasscode = true
    }

    // MARK: - Verify Passcode

    /// Verify locally first (fast), fallback to server
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedHash = keychain.getPasscodeHash(),
              let salt = keychain.getPasscodeSalt() else {
            return false
        }
        let inputHash = hashPasscode(passcode, salt: salt)
        return inputHash == storedHash
    }

    /// Verify against server and cache hash locally
    func verifyAndCachePasscode(_ passcode: String) async throws {
        let request = VerifyPasscodeRequest(passcode: passcode)
        let response: VerifyPasscodeResponse = try await apiClient.request(
            endpoint: "/api/auth/verify-passcode",
            method: .post,
            body: request
        )
        guard response.valid else {
            throw PasscodeError.incorrectPasscode
        }
        // Cache hash + salt locally
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
    }

    // MARK: - Change Passcode

    func changePasscode(current: String, new: String) async throws {
        let request = ChangePasscodeRequest(currentPasscode: current, newPasscode: new)
        let response: ChangePasscodeResponse = try await apiClient.request(
            endpoint: "/api/auth/change-passcode",
            method: .post,
            body: request
        )
        // Update local cache
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
    }

    // MARK: - Reset Passcode

    func requestPasscodeReset() async throws {
        let _: ResetPasscodeRequestResponse = try await apiClient.request(
            endpoint: "/api/auth/reset-passcode-request",
            method: .post,
            body: ResetPasscodeRequestBody()
        )
    }

    func resetPasscode(code: String, newPasscode: String) async throws {
        let request = ResetPasscodeRequest(code: code, newPasscode: newPasscode)
        let response: ResetPasscodeResponse = try await apiClient.request(
            endpoint: "/api/auth/reset-passcode",
            method: .post,
            body: request
        )
        // Update local cache
        if let hash = response.passcodeHash, let salt = response.passcodeSalt {
            keychain.setPasscodeHash(hash)
            keychain.setPasscodeSalt(salt)
        }
        hasPasscode = true
    }

    // MARK: - Timeout

    func updateTimeout(_ minutes: Int) async throws {
        let request = PasscodeTimeoutRequest(minutes: minutes)
        let _: PasscodeTimeoutResponse = try await apiClient.request(
            endpoint: "/api/user/passcode-timeout",
            method: .put,
            body: request
        )
        timeoutMinutes = minutes
        keychain.setPasscodeTimeout(minutes)
    }

    // MARK: - Lock Management

    func lockApp() {
        guard hasPasscode && passcodeEnabled else { return }
        isLocked = true
    }

    func unlockApp() {
        isLocked = false
    }

    func shouldLockOnForeground(backgroundDuration: TimeInterval) -> Bool {
        let timeoutSeconds = TimeInterval(timeoutMinutes) * 60
        return hasPasscode && passcodeEnabled && backgroundDuration >= timeoutSeconds
    }

    // MARK: - Toggle Enabled

    func togglePasscodeEnabled(_ enabled: Bool) async throws {
        struct ToggleRequest: Encodable { let enabled: Bool }
        struct ToggleResponse: Decodable { let passcodeEnabled: Bool }
        let request = ToggleRequest(enabled: enabled)
        let _: ToggleResponse = try await apiClient.request(
            endpoint: /* APIEndpoint for /api/auth/toggle-passcode-enabled */,
            method: .put,
            body: request
        )
        passcodeEnabled = enabled
    }

    // MARK: - Cleanup (logout)

    func clearLocalData() {
        keychain.clearPasscodeData()
        hasPasscode = false
        isBiometricEnabled = false
        isLocked = false
        timeoutMinutes = 15
    }

    // MARK: - Hashing (matches backend)

    private func hashPasscode(_ passcode: String, salt: String) -> String {
        let input = passcode + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

---

## Files to Modify

### `Core/Auth/KeychainManager.swift`

**Add new keys and methods for passcode caching:**

Add to `Keys` enum:
```swift
static let passcodeHash = "com.repairminder.passcodeHash"
static let passcodeSalt = "com.repairminder.passcodeSalt"
static let biometricEnabled = "com.repairminder.biometricEnabled"
static let passcodeTimeout = "com.repairminder.passcodeTimeout"
```

Add public methods:
```swift
// MARK: - Passcode Cache

func setPasscodeHash(_ hash: String) { set(hash, forKey: Keys.passcodeHash) }
func getPasscodeHash() -> String? { get(forKey: Keys.passcodeHash) }

func setPasscodeSalt(_ salt: String) { set(salt, forKey: Keys.passcodeSalt) }
func getPasscodeSalt() -> String? { get(forKey: Keys.passcodeSalt) }

func setBiometricEnabled(_ enabled: Bool) { set(enabled ? "1" : "0", forKey: Keys.biometricEnabled) }
func isBiometricEnabled() -> Bool { get(forKey: Keys.biometricEnabled) == "1" }

func setPasscodeTimeout(_ minutes: Int) { set(String(minutes), forKey: Keys.passcodeTimeout) }
func getPasscodeTimeout() -> Int? {
    guard let str = get(forKey: Keys.passcodeTimeout) else { return nil }
    return Int(str)
}

func clearPasscodeData() {
    delete(forKey: Keys.passcodeHash)
    delete(forKey: Keys.passcodeSalt)
    delete(forKey: Keys.biometricEnabled)
    delete(forKey: Keys.passcodeTimeout)
}
```

Update `clearAll()` to include passcode data:
```swift
func clearAll() {
    clearStaffTokens()
    clearCustomerTokens()
    clearPasscodeData()
}
```

### `Core/Models/User.swift` (or `AuthModels.swift`)

**Add `hasPasscode` and `passcodeTimeoutMinutes` to `GetCurrentUserResponse`:**

```swift
struct GetCurrentUserResponse: Decodable {
    let user: User
    let company: Company
    let hasPassword: Bool
    let hasPasscode: Bool         // NEW
    let passcodeEnabled: Bool     // NEW
    let passcodeTimeoutMinutes: Int?  // NEW
}
```

### `Core/Auth/AuthManager.swift`

**Add passcode state sync after successful auth check:**

In `checkExistingSession()` or wherever `GetCurrentUserResponse` is handled, add:
```swift
// After successful /api/auth/me response:
PasscodeService.shared.syncFromAuthResponse(
    hasPasscode: response.hasPasscode,
    passcodeEnabled: response.passcodeEnabled,
    timeoutMinutes: response.passcodeTimeoutMinutes ?? 15
)
```

---

## Database Changes

None (iOS-side only — Keychain for caching).

---

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | Set passcode via API | `hasPasscode` becomes `true`, hash cached locally |
| 2 | Verify correct passcode locally | `verifyPasscode()` returns `true` |
| 3 | Verify wrong passcode locally | `verifyPasscode()` returns `false` |
| 4 | Verify against server | API call succeeds, hash cached |
| 5 | Change passcode | API succeeds, local cache updated |
| 6 | Request reset email | API succeeds, no local change |
| 7 | Reset passcode with code | API succeeds, local cache updated |
| 8 | Biometric detection | `biometricType` correctly identifies device capability |
| 9 | Auth response syncs state | `hasPasscode`, `passcodeEnabled`, and `timeoutMinutes` updated from `/me` |
| 10 | Logout clears data | `clearLocalData()` removes all Keychain entries |
| 11 | Lock respects timeout | 14 min → no lock; 16 min → lock (for 15-min timeout) |
| 12 | Offline verify works | With cached hash, verify succeeds without network |
| 13 | Lock respects passcodeEnabled | `passcodeEnabled = false` → no lock even with hash set |
| 14 | Toggle enabled | `togglePasscodeEnabled(false)` → `passcodeEnabled = false`, lock stops triggering |

---

## Acceptance Checklist

- [ ] `PasscodeService.swift` compiles
- [ ] `PasscodeAPIModels.swift` matches backend request/response format
- [ ] `KeychainManager` extended with passcode cache methods
- [ ] `clearAll()` also clears passcode data
- [ ] `GetCurrentUserResponse` includes `hasPasscode` and `passcodeTimeoutMinutes`
- [ ] `AuthManager.checkExistingSession()` syncs passcode state
- [ ] Local hash verification matches backend hash algorithm
- [ ] Biometric type detection works
- [ ] `shouldLockOnForeground()` uses `timeoutMinutes` from settings
- [ ] Project builds successfully

---

## Deployment

```bash
# Build to verify:
mcp__XcodeBuildMCP__build_sim
```

---

## Handoff Notes

- `PasscodeService.shared` is ready for UI components in [See: Stage 03]
- `@Published hasPasscode` drives the first-login flow in [See: Stage 04]
- `@Published isLocked` drives the lock overlay in [See: Stage 04]
- `verifyPasscode()` does local verification (fast); `verifyAndCachePasscode()` calls the server
- `syncFromAuthResponse()` must be called after every `/api/auth/me` response
- **⚠️ IMPORTANT:** `APIClient.request()` takes an `APIEndpoint` enum, NOT string paths. The actual signature is `func request<T: Decodable>(_ endpoint: APIEndpoint, body: Encodable? = nil) async throws -> T`. You will need to add new cases to the `APIEndpoint` enum for each passcode endpoint. Check [Ref: Core/Networking/APIClient.swift] for patterns.
