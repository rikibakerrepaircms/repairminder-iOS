# Stage 03: Authentication

## Objective

Implement complete authentication flow including login, secure token storage in Keychain, automatic token refresh, and logout functionality.

---

## Dependencies

**Requires:** [See: Stage 02] complete - APIClient and endpoints exist

---

## Complexity

**High** - Security critical, must handle edge cases correctly

---

## Files to Modify

| File | Changes |
|------|---------|
| `App/AppState.swift` | Add auth properties, connect to AuthManager |
| `App/Repair_MinderApp.swift` | Initialize AuthManager, configure API client |
| `ContentView.swift` | Handle auth state transitions |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Storage/KeychainManager.swift` | Secure credential storage |
| `Features/Auth/AuthManager.swift` | Authentication business logic |
| `Features/Auth/LoginView.swift` | Login screen UI |
| `Features/Auth/LoginViewModel.swift` | Login screen logic |
| `Features/Auth/TwoFactorView.swift` | 2FA code entry |
| `Core/Models/User.swift` | User model |
| `Core/Models/Company.swift` | Company model |
| `Core/Models/AuthResponse.swift` | Login/refresh response models |

---

## Implementation Details

### 1. Keychain Manager

```swift
// Core/Storage/KeychainManager.swift
import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.mendmyi.repairminder"

    enum KeychainKey: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiresAt = "token_expires_at"
        case userId = "user_id"
    }

    private init() {}

    // MARK: - Public API

    func save(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        try save(data, for: key.rawValue)
    }

    func save(_ value: Date, for key: KeychainKey) throws {
        let timestamp = String(value.timeIntervalSince1970)
        try save(timestamp, for: key)
    }

    func getString(for key: KeychainKey) -> String? {
        guard let data = getData(for: key.rawValue) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getDate(for key: KeychainKey) -> Date? {
        guard let string = getString(for: key),
              let timestamp = Double(string) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func delete(key: KeychainKey) {
        delete(key: key.rawValue)
    }

    func deleteAll() {
        KeychainKey.allCases.forEach { delete(key: $0) }
    }

    // MARK: - Private

    private func save(_ data: Data, for key: String) throws {
        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

extension KeychainManager.KeychainKey: CaseIterable {}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .readFailed(let status):
            return "Failed to read from Keychain: \(status)"
        }
    }
}
```

### 2. Auth Response Models

```swift
// Core/Models/AuthResponse.swift
import Foundation

struct LoginResponse: Decodable {
    let token: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: User?
    let company: Company?
    let requiresTwoFactor: Bool?
    let requiresMagicLink: Bool?
    let userId: String?
    let email: String?
    let message: String?
}

struct RefreshResponse: Decodable {
    let token: String
    let refreshToken: String
    let expiresIn: Int
}

struct MeResponse: Decodable {
    let user: User
    let company: Company
}
```

### 3. User Model

```swift
// Core/Models/User.swift
import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
    let companyId: String
    let companyName: String?
    let role: UserRole
    let isActive: Bool
    let verified: Bool
    let twoFactorEnabled: Bool
    let magicLinkEnabled: Bool
    let lastLogin: Date?
    let createdAt: Date
    let updatedAt: Date

    var displayName: String {
        if let first = firstName, let last = lastName {
            return "\(first) \(last)"
        }
        return username
    }

    var initials: String {
        if let first = firstName?.first, let last = lastName?.first {
            return "\(first)\(last)"
        }
        return String(username.prefix(2)).uppercased()
    }
}

enum UserRole: String, Codable {
    case masterAdmin = "master_admin"
    case admin = "admin"
    case seniorEngineer = "senior_engineer"
    case engineer = "engineer"
    case office = "office"
    case custom

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = UserRole(rawValue: rawValue) ?? .custom
    }

    var displayName: String {
        switch self {
        case .masterAdmin: return "Master Admin"
        case .admin: return "Admin"
        case .seniorEngineer: return "Senior Engineer"
        case .engineer: return "Engineer"
        case .office: return "Office"
        case .custom: return "Custom"
        }
    }

    var canManageOrders: Bool {
        switch self {
        case .masterAdmin, .admin, .seniorEngineer, .engineer, .office:
            return true
        case .custom:
            return false // Would need to check permissions
        }
    }
}
```

### 4. Company Model

```swift
// Core/Models/Company.swift
import Foundation

struct Company: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let domain: String?
    let isActive: Bool
    let currencyCode: String
    let depositsEnabled: Bool?
    let createdAt: Date
    let updatedAt: Date

    var currencySymbol: String {
        switch currencyCode {
        case "GBP": return "£"
        case "EUR": return "€"
        case "USD": return "$"
        default: return currencyCode
        }
    }
}
```

### 5. Auth Manager

```swift
// Features/Auth/AuthManager.swift
import Foundation
import os.log

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUser: User?
    @Published private(set) var currentCompany: Company?
    @Published private(set) var isLoading: Bool = true

    private let keychain = KeychainManager.shared
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "Auth")

    private var refreshTask: Task<Void, Never>?

    private init() {
        // Configure API client with token provider
        Task {
            await APIClient.shared.setAuthTokenProvider { [weak self] in
                self?.keychain.getString(for: .accessToken)
            }
        }
    }

    // MARK: - Public API

    /// Check authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        defer { isLoading = false }

        guard let token = keychain.getString(for: .accessToken) else {
            logger.debug("No stored token, user not authenticated")
            await clearAuth()
            return
        }

        // Check if token is expired
        if let expiresAt = keychain.getDate(for: .tokenExpiresAt),
           expiresAt < Date() {
            logger.debug("Token expired, attempting refresh")
            do {
                try await refreshToken()
            } catch {
                logger.error("Token refresh failed: \(error.localizedDescription)")
                await clearAuth()
                return
            }
        }

        // Fetch current user to validate token
        do {
            let response: MeResponse = try await APIClient.shared.request(
                .me(),
                responseType: MeResponse.self
            )
            currentUser = response.user
            currentCompany = response.company
            isAuthenticated = true
            logger.debug("Auth restored for user: \(response.user.email)")

            // Schedule proactive token refresh
            scheduleTokenRefresh()
        } catch {
            logger.error("Failed to fetch current user: \(error.localizedDescription)")
            await clearAuth()
        }
    }

    /// Login with email and password
    func login(email: String, password: String, twoFactorToken: String? = nil) async throws -> LoginResult {
        logger.debug("Attempting login for: \(email)")

        let response: APIResponse<LoginResponse> = try await APIClient.shared.requestRaw(
            .login(email: email, password: password, twoFactorToken: twoFactorToken)
        )

        guard response.success, let data = response.data else {
            throw AuthError.loginFailed(response.error ?? "Login failed")
        }

        // Check if 2FA is required
        if data.requiresTwoFactor == true {
            logger.debug("2FA required for user")
            return .requiresTwoFactor(userId: data.userId ?? "", email: data.email ?? email)
        }

        // Check if magic link is required
        if data.requiresMagicLink == true {
            logger.debug("Magic link required for user")
            return .requiresMagicLink(email: data.email ?? email)
        }

        // Successful login
        guard let token = data.token,
              let refreshToken = data.refreshToken,
              let expiresIn = data.expiresIn,
              let user = data.user,
              let company = data.company else {
            throw AuthError.invalidResponse
        }

        // Store credentials
        try await storeCredentials(
            token: token,
            refreshToken: refreshToken,
            expiresIn: expiresIn
        )

        // Update state
        currentUser = user
        currentCompany = company
        isAuthenticated = true

        logger.debug("Login successful for: \(user.email)")

        // Schedule proactive token refresh
        scheduleTokenRefresh()

        return .success(user: user, company: company)
    }

    /// Logout the current user
    func logout() async {
        logger.debug("Logging out user")

        // Try to notify server (best effort)
        try? await APIClient.shared.requestVoid(.logout())

        await clearAuth()
    }

    /// Refresh the access token
    func refreshToken() async throws {
        guard let refreshToken = keychain.getString(for: .refreshToken) else {
            throw AuthError.noRefreshToken
        }

        logger.debug("Refreshing access token")

        let response: RefreshResponse = try await APIClient.shared.request(
            .refreshToken(refreshToken: refreshToken),
            responseType: RefreshResponse.self
        )

        try await storeCredentials(
            token: response.token,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )

        logger.debug("Token refreshed successfully")
    }

    // MARK: - Private

    private func storeCredentials(token: String, refreshToken: String, expiresIn: Int) async throws {
        try keychain.save(token, for: .accessToken)
        try keychain.save(refreshToken, for: .refreshToken)

        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        try keychain.save(expiresAt, for: .tokenExpiresAt)
    }

    private func clearAuth() async {
        refreshTask?.cancel()
        refreshTask = nil

        keychain.deleteAll()
        currentUser = nil
        currentCompany = nil
        isAuthenticated = false
    }

    private func scheduleTokenRefresh() {
        refreshTask?.cancel()

        guard let expiresAt = keychain.getDate(for: .tokenExpiresAt) else { return }

        // Refresh 60 seconds before expiry
        let refreshTime = expiresAt.addingTimeInterval(-60)
        let delay = refreshTime.timeIntervalSinceNow

        guard delay > 0 else {
            // Token already needs refresh
            Task {
                try? await refreshToken()
            }
            return
        }

        logger.debug("Scheduling token refresh in \(Int(delay)) seconds")

        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            do {
                try await self?.refreshToken()
                self?.scheduleTokenRefresh()
            } catch {
                self?.logger.error("Scheduled token refresh failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Types

enum LoginResult {
    case success(user: User, company: Company)
    case requiresTwoFactor(userId: String, email: String)
    case requiresMagicLink(email: String)
}

enum AuthError: LocalizedError {
    case loginFailed(String)
    case invalidResponse
    case noRefreshToken
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .loginFailed(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server"
        case .noRefreshToken:
            return "No refresh token available"
        case .refreshFailed(let message):
            return "Token refresh failed: \(message)"
        }
    }
}
```

### 6. Login View Model

```swift
// Features/Auth/LoginViewModel.swift
import Foundation
import os.log

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var twoFactorCode: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var showTwoFactor: Bool = false

    private var pendingUserId: String?
    private var pendingEmail: String?

    private let authManager = AuthManager.shared
    private let logger = Logger(subsystem: "com.mendmyi.repairminder", category: "Login")

    var isValid: Bool {
        !email.trimmed.isEmpty && !password.isEmpty
    }

    var isTwoFactorValid: Bool {
        twoFactorCode.count == 6
    }

    func login() async {
        guard isValid else { return }

        isLoading = true
        error = nil

        do {
            let result = try await authManager.login(
                email: email.trimmed,
                password: password
            )

            switch result {
            case .success:
                logger.debug("Login successful")
                // Navigation handled by ContentView observing AuthManager

            case .requiresTwoFactor(let userId, let email):
                pendingUserId = userId
                pendingEmail = email
                showTwoFactor = true
                logger.debug("2FA required")

            case .requiresMagicLink(let email):
                error = "Please check your email (\(email)) for a login link"
                logger.debug("Magic link sent")
            }
        } catch let authError as AuthError {
            error = authError.localizedDescription
            logger.error("Login failed: \(authError.localizedDescription)")
        } catch let apiError as APIError {
            error = apiError.localizedDescription
            logger.error("API error during login: \(apiError.localizedDescription)")
        } catch {
            error = "An unexpected error occurred"
            logger.error("Unexpected login error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func submitTwoFactorCode() async {
        guard isTwoFactorValid else { return }

        isLoading = true
        error = nil

        do {
            let result = try await authManager.login(
                email: pendingEmail ?? email.trimmed,
                password: password,
                twoFactorToken: twoFactorCode
            )

            switch result {
            case .success:
                logger.debug("2FA verification successful")
            case .requiresTwoFactor, .requiresMagicLink:
                error = "Verification failed. Please try again."
            }
        } catch {
            error = "Invalid verification code"
            logger.error("2FA verification failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func cancelTwoFactor() {
        showTwoFactor = false
        twoFactorCode = ""
        pendingUserId = nil
        pendingEmail = nil
    }
}
```

### 7. Login View

```swift
// Features/Auth/LoginView.swift
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, twoFactor
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo/Header
                    VStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)

                        Text("Repair Minder")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Sign in to continue")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Login Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        if let error = viewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                await viewModel.login()
                            }
                        } label: {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.isValid || viewModel.isLoading)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onSubmit {
                switch focusedField {
                case .email:
                    focusedField = .password
                case .password:
                    Task { await viewModel.login() }
                default:
                    break
                }
            }
            .sheet(isPresented: $viewModel.showTwoFactor) {
                TwoFactorView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    LoginView()
}
```

### 8. Two Factor View

```swift
// Features/Auth/TwoFactorView.swift
import SwiftUI

struct TwoFactorView: View {
    @ObservedObject var viewModel: LoginViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text("Two-Factor Authentication")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter the 6-digit code from your authenticator app")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("000000", text: $viewModel.twoFactorCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title.monospaced())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 60)
                    .focused($isFocused)
                    .onChange(of: viewModel.twoFactorCode) { _, newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            viewModel.twoFactorCode = String(newValue.prefix(6))
                        }
                        // Auto-submit when 6 digits entered
                        if newValue.count == 6 {
                            Task { await viewModel.submitTwoFactorCode() }
                        }
                    }

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await viewModel.submitTwoFactorCode() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Verify")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isTwoFactorValid || viewModel.isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelTwoFactor()
                        dismiss()
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

#Preview {
    TwoFactorView(viewModel: LoginViewModel())
}
```

### 9. Update AppState

```swift
// App/AppState.swift (updated)
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var syncStatus: SyncStatus = .idle

    private let authManager = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()

    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }

    var currentUser: User? {
        authManager.currentUser
    }

    var currentCompany: Company? {
        authManager.currentCompany
    }

    enum SyncStatus {
        case idle
        case syncing
        case error(String)
        case offline
    }

    init() {
        // Observe auth manager changes
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        authManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
    }

    func checkAuthStatus() async {
        await authManager.checkAuthStatus()
    }

    func logout() async {
        await authManager.logout()
    }
}
```

### 10. Update App Entry Point

```swift
// Repair_MinderApp.swift (updated)
import SwiftUI

@main
struct Repair_MinderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(router)
                .task {
                    await appState.checkAuthStatus()
                }
        }
    }
}
```

### 11. Update ContentView

```swift
// ContentView.swift (updated)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoading {
                LoadingView(message: "Loading...")
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}
```

---

## Database Changes

None in this stage (credentials stored in Keychain).

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Valid login | Correct email/password | User authenticated, redirected to main app |
| Invalid login | Wrong password | Error message shown |
| 2FA required | Account with 2FA | 2FA sheet presented |
| Valid 2FA code | Correct 6-digit code | Authentication completes |
| Invalid 2FA code | Wrong code | Error message shown |
| Token persists | Kill and reopen app | User still authenticated |
| Token refresh | Wait for token expiry | Token refreshed automatically |
| Logout | Tap logout | Keychain cleared, back to login |
| Network error | No connection | Appropriate error message |
| Keychain save | Login | Token stored securely |
| Keychain clear | Logout | All credentials removed |

---

## Acceptance Checklist

- [ ] Login screen renders correctly
- [ ] Email validation works (basic format check)
- [ ] Password field is secure (hidden input)
- [ ] Login button disabled when form invalid
- [ ] Loading state shown during login
- [ ] Error messages display correctly
- [ ] 2FA flow works (sheet, code entry, verify)
- [ ] Successful login navigates to main app
- [ ] Token stored in Keychain (not UserDefaults)
- [ ] App restores session on relaunch
- [ ] Token refresh works automatically
- [ ] Logout clears all credentials
- [ ] 401 errors trigger re-authentication

---

## Deployment

### Build Commands

```bash
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build
```

### Verification

1. Run app - should show login screen
2. Enter invalid credentials - should show error
3. Enter valid credentials - should authenticate
4. Kill app, reopen - should still be authenticated
5. Tap logout (when implemented in settings) - should return to login

---

## Handoff Notes

**For Stage 04:**
- `AuthManager.shared.currentUser` provides logged-in user
- `AuthManager.shared.currentCompany` provides company info
- `KeychainManager.shared` can store additional secure data
- Token is automatically injected into API requests

**For Stage 06:**
- User/Company models are ready for use in Dashboard
- Use `appState.currentUser?.role` for role-based UI

**For Stage 13:**
- Logout functionality via `AuthManager.shared.logout()`
- Add logout button to Settings view
