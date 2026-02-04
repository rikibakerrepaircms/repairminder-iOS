# Stage 03: Authentication & App Infrastructure

## Objective

Implement **dual authentication flows** for unified app supporting both **Staff** and **Customer** roles:
- **Staff**: Email/password OR magic link login
- **Customer**: Magic link only (no password auth)

User selects their role at launch, then sees appropriate login flow and UI.

## Dependencies

- **Requires**: Stage 02 complete (Models and APIClient, including CustomerModels)
- **Backend Reference**:
  - Staff: `[Ref: /Volumes/Riki Repos/repairminder/worker/index.js]` (auth routes)
  - Customer: `[Ref: /Volumes/Riki Repos/repairminder/worker/src/customer-auth.js]`

## Complexity

**Medium-High** - Dual auth flows, role management, token management, push registration

## Files to Modify

| File | Changes |
|------|---------|
| `App/Repair_MinderApp.swift` | Wire up AppDelegate, root view with role selection |
| `App/AppDelegate.swift` | Push notification delegate methods |

## Files to Create

| File | Purpose |
|------|---------|
| `Core/Auth/AuthManager.swift` | Staff authentication state and token management |
| `Core/Auth/CustomerAuthManager.swift` | Customer authentication state and token management |
| `Core/Auth/KeychainManager.swift` | Secure token storage (both roles) |
| `App/AppState.swift` | Global app state with role awareness |
| `App/UserRole.swift` | Staff vs Customer role enum |
| `Features/Auth/RoleSelectionView.swift` | Choose Staff or Customer at launch |
| `Features/Auth/LoginView.swift` | Staff login screen (email/password + magic link) |
| `Features/Auth/LoginViewModel.swift` | Staff login business logic |
| `Features/Auth/MagicLinkView.swift` | Magic link code entry (both roles) |
| `Features/Auth/CustomerLoginView.swift` | Customer login screen (magic link only) |
| `Features/Auth/CustomerLoginViewModel.swift` | Customer login business logic |
| `Features/Auth/CompanySelectionView.swift` | Multi-company selection for customers |
| `Core/Notifications/PushNotificationManager.swift` | Push registration with role-aware appType |

---

## Implementation Details

### UserRole.swift

```swift
// App/UserRole.swift

import Foundation

/// Role selection for unified app - Staff or Customer
enum UserRole: String, Codable, CaseIterable {
    case staff
    case customer

    var displayName: String {
        switch self {
        case .staff: return "Staff"
        case .customer: return "Customer"
        }
    }

    var description: String {
        switch self {
        case .staff: return "For repair shop employees"
        case .customer: return "View orders and approve quotes"
        }
    }

    var icon: String {
        switch self {
        case .staff: return "wrench.and.screwdriver.fill"
        case .customer: return "person.fill"
        }
    }
}
```

---

### KeychainManager.swift

```swift
// Core/Auth/KeychainManager.swift

import Foundation
import Security

enum KeychainManager {
    private static let service = "com.mendmyi.Repair-Minder"

    enum Key: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpiry = "token_expiry"
        case userRole = "user_role"           // Staff or Customer
        case customerToken = "customer_token" // Separate customer token
    }

    static func save(_ value: String, forKey key: Key) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        Key.allCases.forEach { delete($0) }
    }
}

extension KeychainManager.Key: CaseIterable {}
```

---

### AuthManager.swift

```swift
// Core/Auth/AuthManager.swift

import Foundation
import os.log

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var isAuthenticated = false
    private(set) var currentUser: User?
    private(set) var isLoading = false

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Auth")
    private var refreshTask: Task<String, Error>?

    var token: String? {
        KeychainManager.get(.accessToken)
    }

    private init() {
        // Check for existing token on init
        if let _ = KeychainManager.get(.accessToken) {
            isAuthenticated = true
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response: LoginResponse = try await APIClient.shared.request(
            .login(email: email, password: password),
            responseType: LoginResponse.self
        )

        // Handle 2FA requirement
        if response.requires2fa == true {
            throw AuthError.requires2FA(method: response.method ?? "unknown")
        }

        guard let token = response.token,
              let refreshToken = response.refreshToken,
              let user = response.user else {
            throw AuthError.invalidResponse
        }

        // Save tokens
        saveTokens(access: token, refresh: refreshToken)

        // Update state
        currentUser = user
        isAuthenticated = true

        logger.debug("Login successful for \(email)")

        // Register push token
        await PushNotificationManager.shared.registerTokenWithBackend()
    }

    // MARK: - Magic Link

    func requestMagicLink(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await APIClient.shared.requestVoid(
            .requestMagicLink(email: email)
        )

        logger.debug("Magic link requested for \(email)")
    }

    func verifyMagicCode(email: String, code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response: LoginResponse = try await APIClient.shared.request(
            .verifyMagicCode(email: email, code: code),
            responseType: LoginResponse.self
        )

        guard let token = response.token,
              let refreshToken = response.refreshToken,
              let user = response.user else {
            throw AuthError.invalidResponse
        }

        saveTokens(access: token, refresh: refreshToken)
        currentUser = user
        isAuthenticated = true

        logger.debug("Magic code verified for \(email)")

        await PushNotificationManager.shared.registerTokenWithBackend()
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded() async throws -> String {
        // If already refreshing, wait for that task
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }

        guard let currentToken = token else {
            throw AuthError.notAuthenticated
        }

        // For now, just return current token
        // TODO: Check expiry and refresh if needed
        return currentToken
    }

    func refreshToken() async throws {
        guard let refreshToken = KeychainManager.get(.refreshToken) else {
            throw AuthError.notAuthenticated
        }

        let task = Task<String, Error> {
            let response: RefreshResponse = try await APIClient.shared.request(
                .refreshToken(refreshToken: refreshToken),
                responseType: RefreshResponse.self
            )

            saveTokens(access: response.token, refresh: response.refreshToken)
            return response.token
        }

        self.refreshTask = task

        do {
            _ = try await task.value
            self.refreshTask = nil
            logger.debug("Token refreshed")
        } catch {
            self.refreshTask = nil
            // If refresh fails, logout
            await logout()
            throw AuthError.sessionExpired
        }
    }

    // MARK: - Logout

    func logout() async {
        // Unregister push token first
        await PushNotificationManager.shared.unregisterToken()

        // Call logout API (best effort)
        do {
            try await APIClient.shared.requestVoid(.logout())
        } catch {
            logger.error("Logout API failed: \(error.localizedDescription)")
        }

        // Clear local state
        KeychainManager.deleteAll()
        currentUser = nil
        isAuthenticated = false

        logger.debug("Logged out")
    }

    // MARK: - Fetch Current User

    func fetchCurrentUser() async {
        guard isAuthenticated else { return }

        do {
            currentUser = try await APIClient.shared.request(
                .me(),
                responseType: User.self
            )
        } catch {
            logger.error("Failed to fetch user: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func saveTokens(access: String, refresh: String) {
        KeychainManager.save(access, forKey: .accessToken)
        KeychainManager.save(refresh, forKey: .refreshToken)
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidResponse
    case notAuthenticated
    case sessionExpired
    case requires2FA(method: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .notAuthenticated:
            return "Not authenticated"
        case .sessionExpired:
            return "Session expired. Please login again."
        case .requires2FA(let method):
            return "2FA required via \(method)"
        }
    }
}
```

---

### CustomerAuthManager.swift

```swift
// Core/Auth/CustomerAuthManager.swift

import Foundation
import os.log

@MainActor
@Observable
final class CustomerAuthManager {
    static let shared = CustomerAuthManager()

    private(set) var isAuthenticated = false
    private(set) var currentClient: CustomerClient?
    private(set) var currentCompany: CustomerCompany?
    private(set) var isLoading = false

    // Multi-company selection state
    private(set) var pendingCompanySelection: CustomerLoginResponse?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "CustomerAuth")

    var token: String? {
        KeychainManager.get(.customerToken)
    }

    private init() {
        // Check for existing customer token on init
        if let _ = KeychainManager.get(.customerToken) {
            isAuthenticated = true
        }
    }

    // MARK: - Magic Link Request

    func requestMagicLink(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        try await APIClient.shared.requestVoid(
            .customerRequestMagicLink(email: email)
        )

        logger.debug("Customer magic link requested for \(email)")
    }

    // MARK: - Verify Code

    func verifyCode(email: String, code: String, companyId: String? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        let response: CustomerLoginResponse = try await APIClient.shared.request(
            .customerVerifyCode(email: email, code: code, companyId: companyId),
            responseType: CustomerLoginResponse.self
        )

        // Check if multi-company selection is required
        if response.requiresCompanySelection == true {
            pendingCompanySelection = response
            logger.debug("Customer requires company selection - \(response.companies?.count ?? 0) companies")
            return
        }

        // Single company or company already selected - complete login
        try completeLogin(response: response)
    }

    // MARK: - Complete Login After Company Selection

    func selectCompany(companyId: String) async throws {
        guard let pending = pendingCompanySelection,
              let email = pending.email,
              let code = pending.code else {
            throw AuthError.invalidResponse
        }

        pendingCompanySelection = nil

        // Verify again with selected company
        try await verifyCode(email: email, code: code, companyId: companyId)
    }

    private func completeLogin(response: CustomerLoginResponse) throws {
        guard let token = response.token,
              let client = response.client,
              let company = response.company else {
            throw AuthError.invalidResponse
        }

        // Save token
        KeychainManager.save(token, forKey: .customerToken)
        KeychainManager.save(UserRole.customer.rawValue, forKey: .userRole)

        // Update state
        currentClient = client
        currentCompany = company
        isAuthenticated = true

        logger.debug("Customer login successful for \(client.email)")

        // Register push token
        Task {
            await PushNotificationManager.shared.registerCustomerTokenWithBackend()
        }
    }

    // MARK: - Fetch Current Session

    func fetchCurrentSession() async {
        guard isAuthenticated else { return }

        do {
            let response: CustomerLoginResponse = try await APIClient.shared.request(
                .customerMe(),
                responseType: CustomerLoginResponse.self
            )
            currentClient = response.client
            currentCompany = response.company
        } catch {
            logger.error("Failed to fetch customer session: \(error.localizedDescription)")
        }
    }

    // MARK: - Logout

    func logout() async {
        // Unregister push token first
        await PushNotificationManager.shared.unregisterToken()

        // Call logout API (best effort)
        do {
            try await APIClient.shared.requestVoid(.customerLogout())
        } catch {
            logger.error("Customer logout API failed: \(error.localizedDescription)")
        }

        // Clear local state
        KeychainManager.delete(.customerToken)
        KeychainManager.delete(.userRole)
        currentClient = nil
        currentCompany = nil
        isAuthenticated = false
        pendingCompanySelection = nil

        logger.debug("Customer logged out")
    }

    // MARK: - Cancel Company Selection

    func cancelCompanySelection() {
        pendingCompanySelection = nil
    }
}
```

---

### AppState.swift

```swift
// App/AppState.swift

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    // Current role (persisted)
    var currentRole: UserRole? {
        didSet {
            if let role = currentRole {
                KeychainManager.save(role.rawValue, forKey: .userRole)
            }
        }
    }

    // Staff Navigation
    var selectedStaffTab: StaffTab = .dashboard
    var staffNavigationPath = NavigationPath()

    // Customer Navigation
    var selectedCustomerTab: CustomerTab = .orders
    var customerNavigationPath = NavigationPath()

    // Deep link handling
    var pendingDeepLink: DeepLink?

    // Header counts (for staff badges)
    var headerCounts: HeaderCounts?

    private init() {
        // Restore role from keychain
        if let roleString = KeychainManager.get(.userRole),
           let role = UserRole(rawValue: roleString) {
            currentRole = role
        }
    }

    // MARK: - Staff Tabs

    enum StaffTab: Int, CaseIterable {
        case dashboard = 0
        case devices = 1
        case orders = 2
        case enquiries = 3
        case settings = 4

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .devices: return "Devices"
            case .orders: return "Orders"
            case .enquiries: return "Enquiries"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .devices: return "iphone"
            case .orders: return "doc.text.fill"
            case .enquiries: return "message.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Customer Tabs

    enum CustomerTab: Int, CaseIterable {
        case orders = 0
        case settings = 1

        var title: String {
            switch self {
            case .orders: return "Orders"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .orders: return "doc.text.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Role Management

    func selectRole(_ role: UserRole) {
        currentRole = role
    }

    func clearRole() {
        currentRole = nil
        KeychainManager.delete(.userRole)
    }

    // MARK: - Authentication State

    var isAuthenticated: Bool {
        switch currentRole {
        case .staff:
            return AuthManager.shared.isAuthenticated
        case .customer:
            return CustomerAuthManager.shared.isAuthenticated
        case .none:
            return false
        }
    }

    // MARK: - Header Counts (Staff Only)

    func refreshHeaderCounts() async {
        guard currentRole == .staff else { return }

        do {
            headerCounts = try await APIClient.shared.request(
                .headerCounts(),
                responseType: HeaderCounts.self
            )
        } catch {
            // Silent fail for badge counts
        }
    }

    // MARK: - Deep Link

    func handleDeepLink(_ deepLink: DeepLink) {
        guard let role = currentRole else { return }

        switch (role, deepLink) {
        // Staff deep links
        case (.staff, .order(let id)):
            selectedStaffTab = .orders
            pendingDeepLink = deepLink

        case (.staff, .device(_, _)):
            selectedStaffTab = .devices
            pendingDeepLink = deepLink

        case (.staff, .ticket(_)):
            selectedStaffTab = .enquiries
            pendingDeepLink = deepLink

        // Customer deep links
        case (.customer, .customerOrder(let id)):
            selectedCustomerTab = .orders
            pendingDeepLink = deepLink

        default:
            break
        }
    }

    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }
}

// MARK: - Deep Link

enum DeepLink: Equatable {
    // Staff deep links
    case order(id: String)
    case device(orderId: String, deviceId: String)
    case ticket(id: String)

    // Customer deep links
    case customerOrder(id: String)
}
```

---

### PushNotificationManager.swift

```swift
// Core/Notifications/PushNotificationManager.swift

import Foundation
import UIKit
import UserNotifications
import os.log

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var isRegistered = false
    @Published private(set) var deviceToken: String?

    private let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "Push")

    private override init() {
        super.init()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                logger.debug("Push permission granted")
            }

            return granted
        } catch {
            logger.error("Push permission error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Token Handling

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        logger.debug("Device token received: \(tokenString.prefix(20))...")

        Task {
            await registerTokenWithBackend()
        }
    }

    func handleRegistrationError(_ error: Error) {
        logger.error("Push registration failed: \(error.localizedDescription)")
    }

    // MARK: - Backend Registration

    // MARK: - Staff Backend Registration

    func registerTokenWithBackend() async {
        guard AuthManager.shared.isAuthenticated,
              let token = deviceToken else {
            logger.debug("Skipping staff token registration - not ready")
            return
        }

        do {
            try await APIClient.shared.requestVoid(
                .registerDeviceToken(token: token, appType: "staff")
            )
            isRegistered = true
            logger.debug("Staff device token registered with backend")
        } catch {
            logger.error("Failed to register staff token: \(error.localizedDescription)")
        }
    }

    // MARK: - Customer Backend Registration

    func registerCustomerTokenWithBackend() async {
        guard CustomerAuthManager.shared.isAuthenticated,
              let token = deviceToken else {
            logger.debug("Skipping customer token registration - not ready")
            return
        }

        do {
            try await APIClient.shared.requestVoid(
                .registerCustomerDeviceToken(token: token)
            )
            isRegistered = true
            logger.debug("Customer device token registered with backend")
        } catch {
            logger.error("Failed to register customer token: \(error.localizedDescription)")
        }
    }

    func unregisterToken() async {
        guard let token = deviceToken else { return }

        do {
            try await APIClient.shared.requestVoid(
                .unregisterDeviceToken(token: token)
            )
            isRegistered = false
            logger.debug("Device token unregistered")
        } catch {
            logger.error("Failed to unregister token: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification Handling

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "order_created", "order_status_changed", "order_collected", "payment_received":
            if let orderId = userInfo["order_id"] as? String {
                AppState.shared.handleDeepLink(.order(id: orderId))
            }

        case "device_status_changed", "quote_approved", "quote_rejected", "device_assigned":
            if let orderId = userInfo["order_id"] as? String,
               let deviceId = userInfo["device_id"] as? String {
                AppState.shared.handleDeepLink(.device(orderId: orderId, deviceId: deviceId))
            }

        case "new_enquiry", "enquiry_reply":
            if let ticketId = userInfo["ticket_id"] as? String {
                AppState.shared.handleDeepLink(.ticket(id: ticketId))
            }

        default:
            logger.debug("Unknown notification type: \(type)")
        }
    }
}
```

---

### AppDelegate.swift

```swift
// App/AppDelegate.swift

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Push Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRegistrationError(error)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .badge, .sound]
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            PushNotificationManager.shared.handleNotificationTap(userInfo: userInfo)
        }
    }
}
```

---

### LoginView.swift

```swift
// Features/Auth/LoginView.swift

import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .padding(.top, 40)

                Text("Repair Minder")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                // Login Form
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    if !viewModel.useMagicLink {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.horizontal)

                // Error
                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                // Login Button
                Button {
                    Task {
                        await viewModel.login()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.useMagicLink ? "Send Magic Link" : "Login")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || viewModel.email.isEmpty)
                .padding(.horizontal)

                // Toggle magic link
                Button {
                    viewModel.useMagicLink.toggle()
                } label: {
                    Text(viewModel.useMagicLink ? "Use password instead" : "Use magic link instead")
                        .font(.caption)
                }

                Spacer()
            }
            .navigationDestination(isPresented: $viewModel.showMagicCodeEntry) {
                MagicLinkCodeView(email: viewModel.email)
            }
        }
    }
}

// MARK: - LoginViewModel

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var useMagicLink = false
    var isLoading = false
    var error: String?
    var showMagicCodeEntry = false

    func login() async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if useMagicLink {
                try await AuthManager.shared.requestMagicLink(email: email)
                showMagicCodeEntry = true
            } else {
                try await AuthManager.shared.login(email: email, password: password)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

---

### MagicLinkCodeView.swift

```swift
// Features/Auth/MagicLinkCodeView.swift

import SwiftUI

struct MagicLinkCodeView: View {
    let email: String
    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter Code")
                .font(.title)
                .fontWeight(.bold)

            Text("We sent a 6-digit code to \(email)")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            if let error = error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await verifyCode()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || code.count != 6)

            Button("Resend Code") {
                Task {
                    await resendCode()
                }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(isLoading)
    }

    private func verifyCode() async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthManager.shared.verifyMagicCode(email: email, code: code)
            // Success - AuthManager will update isAuthenticated
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resendCode() async {
        error = nil

        do {
            try await AuthManager.shared.requestMagicLink(email: email)
            error = "Code resent!"
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

---

### RoleSelectionView.swift

```swift
// Features/Auth/RoleSelectionView.swift

import SwiftUI

struct RoleSelectionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 32) {
            // Logo
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .padding(.top, 60)

            Text("Repair Minder")
                .font(.title)
                .fontWeight(.bold)

            Text("How would you like to sign in?")
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 16) {
                ForEach(UserRole.allCases, id: \.self) { role in
                    Button {
                        appState.selectRole(role)
                    } label: {
                        HStack {
                            Image(systemName: role.icon)
                                .font(.title2)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.displayName)
                                    .font(.headline)
                                Text(role.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}
```

---

### CustomerLoginView.swift

```swift
// Features/Auth/CustomerLoginView.swift

import SwiftUI

struct CustomerLoginView: View {
    @State private var viewModel = CustomerLoginViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .padding(.top, 40)

                Text("Customer Portal")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Enter your email to receive a login code")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Email Field
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // Error
                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                // Send Code Button
                Button {
                    Task {
                        await viewModel.requestMagicLink()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send Login Code")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || viewModel.email.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationDestination(isPresented: $viewModel.showCodeEntry) {
                CustomerMagicCodeView(email: viewModel.email)
            }
        }
    }
}

// MARK: - CustomerLoginViewModel

@MainActor
@Observable
final class CustomerLoginViewModel {
    var email = ""
    var isLoading = false
    var error: String?
    var showCodeEntry = false

    func requestMagicLink() async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await CustomerAuthManager.shared.requestMagicLink(email: email)
            showCodeEntry = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

---

### CustomerMagicCodeView.swift

```swift
// Features/Auth/CustomerMagicCodeView.swift

import SwiftUI

struct CustomerMagicCodeView: View {
    let email: String
    @State private var code = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCompanySelection = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter Code")
                .font(.title)
                .fontWeight(.bold)

            Text("We sent a 6-digit code to\n\(email)")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            if let error = error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await verifyCode()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || code.count != 6)

            Button("Resend Code") {
                Task {
                    await resendCode()
                }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(isLoading)
        .sheet(isPresented: $showCompanySelection) {
            CompanySelectionView()
        }
        .onChange(of: CustomerAuthManager.shared.pendingCompanySelection) { _, newValue in
            showCompanySelection = newValue != nil
        }
    }

    private func verifyCode() async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await CustomerAuthManager.shared.verifyCode(email: email, code: code)
            // Success handled by CustomerAuthManager state
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resendCode() async {
        error = nil

        do {
            try await CustomerAuthManager.shared.requestMagicLink(email: email)
            error = "Code resent!"
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

---

### CompanySelectionView.swift

```swift
// Features/Auth/CompanySelectionView.swift

import SwiftUI

struct CompanySelectionView: View {
    @State private var isLoading = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var companies: [CustomerCompany] {
        CustomerAuthManager.shared.pendingCompanySelection?.companies ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Select Your Company")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You have accounts with multiple repair shops.\nSelect the one you want to access.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let error = error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                List(companies, id: \.id) { company in
                    Button {
                        Task {
                            await selectCompany(company.id)
                        }
                    } label: {
                        HStack {
                            // Company logo or placeholder
                            if let logoUrl = company.logoUrl {
                                AsyncImage(url: URL(string: logoUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.secondary.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.secondary.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "building.2")
                                            .foregroundStyle(.secondary)
                                    }
                            }

                            Text(company.name)
                                .font(.headline)

                            Spacer()

                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .listStyle(.insetGrouped)
            }
            .padding(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        CustomerAuthManager.shared.cancelCompanySelection()
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func selectCompany(_ companyId: String) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await CustomerAuthManager.shared.selectCompany(companyId: companyId)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

---

### Repair_MinderApp.swift (Updated)

```swift
// App/Repair_MinderApp.swift

import SwiftUI

@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared
    @State private var authManager = AuthManager.shared
    @State private var customerAuthManager = CustomerAuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.currentRole {
                case .none:
                    // No role selected - show role selection
                    RoleSelectionView()
                        .environment(appState)

                case .staff:
                    // Staff role selected
                    if authManager.isAuthenticated {
                        StaffMainTabView()
                            .environment(appState)
                            .task {
                                await authManager.fetchCurrentUser()
                                await appState.refreshHeaderCounts()
                                _ = await PushNotificationManager.shared.requestPermission()
                            }
                    } else {
                        LoginView()
                            .environment(appState)
                    }

                case .customer:
                    // Customer role selected
                    if customerAuthManager.isAuthenticated {
                        CustomerMainTabView()
                            .environment(appState)
                            .task {
                                await customerAuthManager.fetchCurrentSession()
                                _ = await PushNotificationManager.shared.requestPermission()
                            }
                    } else {
                        CustomerLoginView()
                            .environment(appState)
                    }
                }
            }
            .animation(.default, value: appState.currentRole)
            .animation(.default, value: authManager.isAuthenticated)
            .animation(.default, value: customerAuthManager.isAuthenticated)
        }
    }
}

// MARK: - Staff Main Tab View

struct StaffMainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedStaffTab) {
            ForEach(AppState.StaffTab.allCases, id: \.self) { tab in
                NavigationStack {
                    staffView(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func staffView(for tab: AppState.StaffTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .devices:
            DeviceListView()
        case .orders:
            OrderListView()
        case .enquiries:
            EnquiryListView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Customer Main Tab View

struct CustomerMainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedCustomerTab) {
            ForEach(AppState.CustomerTab.allCases, id: \.self) { tab in
                NavigationStack {
                    customerView(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func customerView(for tab: AppState.CustomerTab) -> some View {
        switch tab {
        case .orders:
            CustomerOrderListView() // Defined in Stage 08
        case .settings:
            CustomerSettingsView() // Defined in Stage 08
        }
    }
}
```

---

## Database Changes

None (iOS only)

## Test Cases

### Role Selection
| Test | Steps | Expected |
|------|-------|----------|
| Show role selection | Fresh app launch | Role selection screen shown |
| Select Staff role | Tap Staff | Staff login screen shown |
| Select Customer role | Tap Customer | Customer login screen shown |
| Role persists | Select role, force quit, reopen | Same role still selected |

### Staff Authentication
| Test | Steps | Expected |
|------|-------|----------|
| Staff login with password | Enter email/password, tap Login | Staff dashboard loads, token saved |
| Staff login with magic link | Enter email, tap Send, enter code | Staff dashboard loads |
| Invalid staff password | Enter wrong password | Error message shown |
| Invalid staff magic code | Enter wrong code | Error message shown |
| Staff logout | Tap logout | Returns to staff login, token cleared |
| Staff session persistence | Force quit, reopen | Still logged in as staff |

### Customer Authentication
| Test | Steps | Expected |
|------|-------|----------|
| Customer request code | Enter email, tap Send | Success message, code entry shown |
| Customer verify code (single company) | Enter correct code | Customer orders view loads |
| Customer verify code (multi-company) | Enter correct code | Company selection sheet shown |
| Customer select company | Tap company | Customer orders view loads |
| Invalid customer code | Enter wrong code | Error message shown |
| Customer logout | Tap logout | Returns to customer login |
| Customer session persistence | Force quit, reopen | Still logged in as customer |

### Push Notifications
| Test | Steps | Expected |
|------|-------|----------|
| Staff push token register | Staff login on device | Token sent with appType: "staff" |
| Customer push token register | Customer login on device | Token sent with appType: "customer" |
| Push token unregister | Logout either role | Token removed from backend |

### Deep Links
| Test | Steps | Expected |
|------|-------|----------|
| Staff deep link order | Tap order notification (staff) | Navigates to staff order detail |
| Staff deep link ticket | Tap enquiry notification | Navigates to ticket detail |
| Customer deep link order | Tap order notification (customer) | Navigates to customer order detail |

## Acceptance Checklist

### Role Selection
- [ ] Role selection view displays on first launch
- [ ] Staff and Customer options shown with icons and descriptions
- [ ] Selected role persisted to Keychain

### Staff Authentication
- [ ] Staff login with email/password works
- [ ] Staff login with magic link works
- [ ] Staff tokens saved in Keychain
- [ ] Staff auth state persists across app restart
- [ ] Staff logout clears tokens and state

### Customer Authentication
- [ ] Customer magic link request works
- [ ] Customer code verification works
- [ ] Multi-company selection shows when needed
- [ ] Company selection completes login
- [ ] Customer token saved in Keychain
- [ ] Customer auth state persists across restart
- [ ] Customer logout clears tokens and state

### Push Notifications
- [ ] Push permission requested on login (both roles)
- [ ] Staff token registered with appType: "staff"
- [ ] Customer token registered with appType: "customer"
- [ ] Token unregistered on logout (both roles)
- [ ] Notifications show when app in foreground
- [ ] Notification tap navigates correctly for role

## Deployment

1. Build and run on simulator
2. Test login flow with test credentials
3. Build and run on physical device for push testing
4. Verify push token appears in backend logs
5. Send test push notification
6. Verify notification appears and tap navigates

## Handoff Notes

### Staff Authentication
- `AuthManager.shared` provides `token` for staff API calls
- `AuthManager.shared.isAuthenticated` checks staff login state
- `AuthManager.shared.currentUser` provides current staff user
- Push notifications registered with `appType: "staff"`

### Customer Authentication
- `CustomerAuthManager.shared` provides `token` for customer API calls
- `CustomerAuthManager.shared.isAuthenticated` checks customer login state
- `CustomerAuthManager.shared.currentClient` provides current customer
- `CustomerAuthManager.shared.currentCompany` provides customer's company
- Push notifications registered with `appType: "customer"`

### Role Management
- `AppState.shared.currentRole` indicates current role (staff/customer/nil)
- Role selection persisted to Keychain
- App displays appropriate UI based on role and auth state

### Navigation
- `AppState.shared.selectedStaffTab` for staff tab navigation
- `AppState.shared.selectedCustomerTab` for customer tab navigation
- Deep links handled based on current role

### Feature Implementations
- [See: Stage 04] for Dashboard implementation (Staff)
- [See: Stage 05] for Devices/Orders implementation (Staff)
- [See: Stage 06] for Enquiries implementation (Staff)
- [See: Stage 07] for Settings implementation (Both roles)
- [See: Stage 08] for Customer screens (Customer)
