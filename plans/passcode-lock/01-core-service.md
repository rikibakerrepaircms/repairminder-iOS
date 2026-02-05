# Stage 01 — Core Service

## Objective

Create `PasscodeService` singleton and extend `KeychainManager` to securely store, verify, and manage a 6-digit passcode with biometric authentication support.

## Dependencies

None — this is the foundation stage.

## Complexity

**Medium** — Involves Keychain security APIs, SHA-256 hashing with CryptoKit, and LocalAuthentication framework.

---

## Files to Modify

### `Core/Auth/KeychainManager.swift`

Add new Keychain keys and methods for passcode storage with higher security accessibility level.

**Changes:**
1. Add new keys to `Keys` enum: `passcodeHash`, `passcodeSalt`, `passcodeEnabled`, `biometricEnabled`
2. Add a `set(_:forKey:accessibility:)` overload that accepts a custom accessibility level
3. Add public methods: `setPasscodeHash()`, `getPasscodeHash()`, `setPasscodeSalt()`, `getPasscodeSalt()`, `setPasscodeEnabled()`, `isPasscodeEnabled()`, `setBiometricEnabled()`, `isBiometricEnabled()`, `clearPasscodeData()`
4. Integrate with existing `clearAll()` to also clear passcode data on full logout

---

## Files to Create

### `Core/Services/PasscodeService.swift`

**Purpose:** Singleton service managing all passcode and biometric logic. Acts as the single source of truth for lock state.

**Implementation Details:**

```swift
import Foundation
import LocalAuthentication
import CryptoKit

@MainActor
final class PasscodeService: ObservableObject {
    static let shared = PasscodeService()

    // MARK: - Published State
    @Published private(set) var isPasscodeEnabled: Bool = false
    @Published private(set) var isBiometricEnabled: Bool = false
    @Published private(set) var biometricType: BiometricType = .none
    @Published var isLocked: Bool = false

    // MARK: - Private
    private let keychain = KeychainManager.shared
    private let gracePeriod: TimeInterval = 5.0  // seconds

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

    enum PasscodeError: Error {
        case incorrectPasscode
        case biometricNotAvailable
        case biometricFailed(String)
        case biometricCancelled
    }

    // MARK: - Init
    private init() {
        loadState()
        checkBiometricAvailability()
    }

    // MARK: - State Loading
    func loadState() {
        isPasscodeEnabled = keychain.isPasscodeEnabled()
        isBiometricEnabled = keychain.isBiometricEnabled()
    }

    // MARK: - Biometric Detection
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

    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    // MARK: - Passcode Management
    func setPasscode(_ passcode: String) {
        let salt = generateSalt()
        let hash = hashPasscode(passcode, salt: salt)
        keychain.setPasscodeHash(hash)
        keychain.setPasscodeSalt(salt)
        keychain.setPasscodeEnabled(true)
        isPasscodeEnabled = true
    }

    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedHash = keychain.getPasscodeHash(),
              let salt = keychain.getPasscodeSalt() else {
            return false
        }
        let inputHash = hashPasscode(passcode, salt: salt)
        return inputHash == storedHash
    }

    func removePasscode() {
        keychain.clearPasscodeData()
        isPasscodeEnabled = false
        isBiometricEnabled = false
        isLocked = false
    }

    func setBiometric(enabled: Bool) {
        keychain.setBiometricEnabled(enabled)
        isBiometricEnabled = enabled
    }

    // MARK: - Biometric Auth
    func authenticateWithBiometric() async -> Result<Void, PasscodeError> {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Repair Minder"
            )
            if success {
                return .success(())
            } else {
                return .failure(.biometricFailed("Authentication failed"))
            }
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

    // MARK: - Lock Management
    func lockApp() {
        guard isPasscodeEnabled else { return }
        isLocked = true
    }

    func unlockApp() {
        isLocked = false
    }

    func shouldLockOnForeground(backgroundDuration: TimeInterval) -> Bool {
        return isPasscodeEnabled && backgroundDuration >= gracePeriod
    }

    // MARK: - Hashing
    private func generateSalt() -> String {
        let saltData = (0..<16).map { _ in UInt8.random(in: 0...255) }
        return Data(saltData).base64EncodedString()
    }

    private func hashPasscode(_ passcode: String, salt: String) -> String {
        let input = passcode + salt
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

---

## Database Changes

None — all data stored locally in iOS Keychain.

---

## Test Cases

| # | Scenario | Input | Expected Output |
|---|----------|-------|-----------------|
| 1 | Set passcode | `"123456"` | `isPasscodeEnabled == true`, hash + salt stored in Keychain |
| 2 | Verify correct passcode | `"123456"` | `verifyPasscode()` returns `true` |
| 3 | Verify wrong passcode | `"654321"` | `verifyPasscode()` returns `false` |
| 4 | Remove passcode | — | `isPasscodeEnabled == false`, Keychain cleared |
| 5 | Biometric detection | — | `biometricType` is `.faceID` / `.touchID` / `.none` |
| 6 | Lock triggers | `backgroundDuration = 10` | `shouldLockOnForeground()` returns `true` |
| 7 | Grace period respected | `backgroundDuration = 2` | `shouldLockOnForeground()` returns `false` |
| 8 | Set then remove passcode | Set → Remove | No orphan Keychain entries |
| 9 | Enable biometric | `setBiometric(enabled: true)` | `isBiometricEnabled == true` |
| 10 | Full logout clears passcode | `clearAll()` | Passcode data also cleared |

---

## Acceptance Checklist

- [ ] `PasscodeService.swift` compiles with no errors
- [ ] `KeychainManager` extended with passcode methods
- [ ] Passcode stored as SHA-256 hash with random salt
- [ ] `verifyPasscode()` correctly validates input against stored hash
- [ ] `removePasscode()` clears all passcode-related Keychain entries
- [ ] `biometricType` correctly detects Face ID / Touch ID / none
- [ ] `authenticateWithBiometric()` returns proper success/failure results
- [ ] `shouldLockOnForeground()` respects 5-second grace period
- [ ] `clearAll()` in KeychainManager also clears passcode data
- [ ] Project builds successfully

---

## Deployment

```bash
# Build only — no run needed for this stage
# Verify via Xcode build or:
mcp__XcodeBuildMCP__build_sim
```

---

## Handoff Notes

- `PasscodeService.shared` is ready for use by UI components in [See: Stage 02] and [See: Stage 03]
- The service exposes `@Published isLocked` which [See: Stage 04] will observe in `Repair_MinderApp.swift`
- `biometricType.displayName` and `.systemImage` provide UI labels for [See: Stage 03]
- The `authenticateWithBiometric()` method is async and returns a `Result` — UI should handle both `.success` and `.failure` cases
