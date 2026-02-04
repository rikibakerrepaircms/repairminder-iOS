# Stage 07: Settings & Push Notifications

## Objective

Implement settings screen with push notification preferences, appearance settings, and comprehensive notification handling with deep linking.

## Dependencies

- **Requires**: Stage 03 complete (PushNotificationManager)
- **Backend Reference**: `[Ref: /Volumes/Riki Repos/repairminder/worker/device_token_handlers.js]`

## Complexity

**Medium** - Settings UI, preferences API, deep linking

## Files to Modify

| File | Changes |
|------|---------|
| `Features/Settings/SettingsView.swift` | Complete rewrite |
| `Core/Notifications/PushNotificationManager.swift` | Add preferences management |

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Settings/SettingsViewModel.swift` | Settings logic |
| `Features/Settings/NotificationSettingsView.swift` | Push preferences UI |
| `Features/Settings/NotificationSettingsViewModel.swift` | Preferences logic |
| `Features/Settings/AppearanceSettingsView.swift` | Dark mode toggle |
| `Features/Settings/AboutView.swift` | App info |
| `Core/Notifications/DeepLinkHandler.swift` | Notification navigation |

---

## Implementation Details

### SettingsViewModel.swift

```swift
// Features/Settings/SettingsViewModel.swift

import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var user: User?
    private(set) var isLoading = false

    func loadUser() async {
        user = AuthManager.shared.currentUser

        // Refresh if needed
        if user == nil {
            await AuthManager.shared.fetchCurrentUser()
            user = AuthManager.shared.currentUser
        }
    }

    func logout() async {
        await AuthManager.shared.logout()
    }
}
```

---

### SettingsView.swift

```swift
// Features/Settings/SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // User Profile Section
                Section {
                    if let user = viewModel.user {
                        HStack(spacing: 12) {
                            // Avatar
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Text(user.fullName.prefix(1).uppercased())
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.accentColor)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let company = user.company {
                                    Text(company.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        ProgressView()
                    }
                }

                // Notifications Section
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Push Notifications", systemImage: "bell.badge")
                    }
                }

                // Appearance Section
                Section("Appearance") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Theme", systemImage: "paintbrush")
                    }
                }

                // About Section
                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Repair Minder", systemImage: "info.circle")
                    }

                    Link(destination: URL(string: "https://repairminder.com/support")!) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://repairminder.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                // Logout Section
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Logout",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout", role: .destructive) {
                    Task { await viewModel.logout() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to logout?")
            }
            .task {
                await viewModel.loadUser()
            }
        }
    }
}
```

---

### NotificationSettingsViewModel.swift

```swift
// Features/Settings/NotificationSettingsViewModel.swift

import Foundation

@MainActor
@Observable
final class NotificationSettingsViewModel {
    private(set) var preferences: PushPreferences?
    private(set) var isLoading = false
    private(set) var isSaving = false
    var error: String?

    // MARK: - Load

    func loadPreferences() async {
        isLoading = true
        error = nil

        do {
            preferences = try await APIClient.shared.request(
                .pushPreferences(),
                responseType: PushPreferences.self
            )
        } catch {
            self.error = "Failed to load preferences"
        }

        isLoading = false
    }

    // MARK: - Update

    func updatePreference(keyPath: WritableKeyPath<PushPreferences, Bool>, value: Bool) async {
        guard var prefs = preferences else { return }

        // Update local state immediately
        prefs[keyPath: keyPath] = value
        preferences = prefs

        // Save to backend
        await savePreferences()
    }

    func toggleMasterSwitch(_ enabled: Bool) async {
        guard var prefs = preferences else { return }

        prefs.enabled = enabled

        // If disabling, turn off all
        if !enabled {
            prefs.orderCreated = false
            prefs.orderStatusChanged = false
            prefs.orderCollected = false
            prefs.deviceStatusChanged = false
            prefs.quoteApproved = false
            prefs.quoteRejected = false
            prefs.paymentReceived = false
            prefs.newEnquiry = false
            prefs.enquiryReply = false
            prefs.deviceAssigned = false
        }

        preferences = prefs
        await savePreferences()
    }

    private func savePreferences() async {
        guard let prefs = preferences else { return }

        isSaving = true
        error = nil

        do {
            try await APIClient.shared.requestVoid(
                .updatePushPreferences(prefs)
            )
        } catch {
            self.error = "Failed to save preferences"
            // Reload to get server state
            await loadPreferences()
        }

        isSaving = false
    }
}
```

---

### NotificationSettingsView.swift

```swift
// Features/Settings/NotificationSettingsView.swift

import SwiftUI

struct NotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        List {
            if let prefs = viewModel.preferences {
                // Master Toggle
                Section {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { prefs.enabled },
                        set: { newValue in
                            Task { await viewModel.toggleMasterSwitch(newValue) }
                        }
                    ))
                } footer: {
                    Text("Turn off to disable all push notifications")
                }

                // Order Notifications
                Section("Orders") {
                    NotificationToggle(
                        title: "New Orders",
                        subtitle: "When a new order is created",
                        isOn: prefs.orderCreated,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.orderCreated, value: value)
                    }

                    NotificationToggle(
                        title: "Order Status Changes",
                        subtitle: "When order status is updated",
                        isOn: prefs.orderStatusChanged,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.orderStatusChanged, value: value)
                    }

                    NotificationToggle(
                        title: "Order Collected",
                        subtitle: "When customer collects order",
                        isOn: prefs.orderCollected,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.orderCollected, value: value)
                    }
                }

                // Device Notifications
                Section("Devices") {
                    NotificationToggle(
                        title: "Device Status Changes",
                        subtitle: "When device status is updated",
                        isOn: prefs.deviceStatusChanged,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.deviceStatusChanged, value: value)
                    }

                    NotificationToggle(
                        title: "Device Assigned",
                        subtitle: "When a device is assigned to you",
                        isOn: prefs.deviceAssigned,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.deviceAssigned, value: value)
                    }
                }

                // Quote Notifications
                Section("Quotes") {
                    NotificationToggle(
                        title: "Quote Approved",
                        subtitle: "When customer approves a quote",
                        isOn: prefs.quoteApproved,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.quoteApproved, value: value)
                    }

                    NotificationToggle(
                        title: "Quote Rejected",
                        subtitle: "When customer rejects a quote",
                        isOn: prefs.quoteRejected,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.quoteRejected, value: value)
                    }
                }

                // Payment Notifications
                Section("Payments") {
                    NotificationToggle(
                        title: "Payment Received",
                        subtitle: "When a payment is recorded",
                        isOn: prefs.paymentReceived,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.paymentReceived, value: value)
                    }
                }

                // Enquiry Notifications
                Section("Enquiries") {
                    NotificationToggle(
                        title: "New Enquiries",
                        subtitle: "When a new enquiry is received",
                        isOn: prefs.newEnquiry,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.newEnquiry, value: value)
                    }

                    NotificationToggle(
                        title: "Enquiry Replies",
                        subtitle: "When customer replies to enquiry",
                        isOn: prefs.enquiryReply,
                        isEnabled: prefs.enabled
                    ) { value in
                        await viewModel.updatePreference(keyPath: \.enquiryReply, value: value)
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isSaving {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .task {
            await viewModel.loadPreferences()
        }
    }
}

// MARK: - Notification Toggle

struct NotificationToggle: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let isEnabled: Bool
    let onToggle: (Bool) async -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                Task { await onToggle(newValue) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!isEnabled)
    }
}
```

---

### AppearanceSettingsView.swift

```swift
// Features/Settings/AppearanceSettingsView.swift

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some View {
        List {
            Section("Theme") {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearanceMode = mode
                        applyAppearance(mode)
                    } label: {
                        HStack {
                            Label(mode.displayName, systemImage: mode.icon)
                            Spacer()
                            if appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            switch mode {
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            }
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}
```

---

### AboutView.swift

```swift
// Features/Settings/AboutView.swift

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)

                    Text("Repair Minder")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section("Information") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
                LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
            }

            Section {
                Link(destination: URL(string: "https://repairminder.com")!) {
                    Label("Website", systemImage: "globe")
                }

                Link(destination: URL(string: "https://twitter.com/repairminder")!) {
                    Label("Twitter", systemImage: "bird")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
```

---

### DeepLinkHandler.swift

```swift
// Core/Notifications/DeepLinkHandler.swift

import Foundation
import os.log

struct DeepLinkHandler {
    private static let logger = Logger(subsystem: "com.mendmyi.Repair-Minder", category: "DeepLink")

    /// Parse notification payload and return appropriate deep link
    static func parseNotification(userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard let type = userInfo["type"] as? String else {
            logger.warning("Notification missing type")
            return nil
        }

        logger.debug("Parsing notification type: \(type)")

        switch type {
        // Order notifications
        case "order_created", "order_status_changed", "order_collected", "payment_received":
            if let orderId = userInfo["order_id"] as? String {
                return .order(id: orderId)
            }

        // Device notifications
        case "device_status_changed", "quote_approved", "quote_rejected", "device_assigned":
            if let orderId = userInfo["order_id"] as? String,
               let deviceId = userInfo["device_id"] as? String {
                return .device(orderId: orderId, deviceId: deviceId)
            } else if let orderId = userInfo["order_id"] as? String {
                return .order(id: orderId)
            }

        // Ticket notifications
        case "new_enquiry", "enquiry_reply":
            if let ticketId = userInfo["ticket_id"] as? String {
                return .ticket(id: ticketId)
            }

        default:
            logger.warning("Unknown notification type: \(type)")
        }

        return nil
    }

    /// Handle URL scheme deep links
    static func parseURL(_ url: URL) -> DeepLink? {
        guard url.scheme == "repairminder" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = url.host ?? ""
        let queryItems = components?.queryItems ?? []

        switch path {
        case "order":
            if let orderId = queryItems.first(where: { $0.name == "id" })?.value {
                return .order(id: orderId)
            }

        case "device":
            if let orderId = queryItems.first(where: { $0.name == "order_id" })?.value,
               let deviceId = queryItems.first(where: { $0.name == "id" })?.value {
                return .device(orderId: orderId, deviceId: deviceId)
            }

        case "ticket", "enquiry":
            if let ticketId = queryItems.first(where: { $0.name == "id" })?.value {
                return .ticket(id: ticketId)
            }

        default:
            break
        }

        return nil
    }
}
```

---

### Update PushNotificationManager.swift

Add to `handleNotificationTap` in [See: Stage 03]:

```swift
// In PushNotificationManager.swift

func handleNotificationTap(userInfo: [AnyHashable: Any]) {
    if let deepLink = DeepLinkHandler.parseNotification(userInfo: userInfo) {
        AppState.shared.handleDeepLink(deepLink)
    }
}
```

---

### Push Notification Payload Examples

**Order Created**:
```json
{
  "aps": {
    "alert": {
      "title": "New Order",
      "body": "Order #12345 has been created"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "order_created",
  "order_id": "uuid-here"
}
```

**Device Assigned**:
```json
{
  "aps": {
    "alert": {
      "title": "Device Assigned",
      "body": "iPhone 12 Pro has been assigned to you"
    },
    "sound": "default"
  },
  "type": "device_assigned",
  "order_id": "uuid-here",
  "device_id": "uuid-here"
}
```

**Quote Approved**:
```json
{
  "aps": {
    "alert": {
      "title": "Quote Approved",
      "body": "Customer approved quote for Order #12345"
    },
    "sound": "default"
  },
  "type": "quote_approved",
  "order_id": "uuid-here",
  "device_id": "uuid-here"
}
```

**New Enquiry**:
```json
{
  "aps": {
    "alert": {
      "title": "New Enquiry",
      "body": "New message from John Doe"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "new_enquiry",
  "ticket_id": "uuid-here"
}
```

---

## Database Changes

None (iOS only)

## Test Cases

| Test | Steps | Expected |
|------|-------|----------|
| Settings loads | Navigate to Settings | User info displays |
| Push prefs load | Open notification settings | All toggles show |
| Master toggle off | Turn off Enable | All toggles disable |
| Individual toggle | Toggle one setting | Saves to backend |
| Appearance change | Select Dark mode | Theme changes |
| Logout | Tap logout | Returns to login |
| Push order tap | Tap order notification | Opens order detail |
| Push device tap | Tap device notification | Opens device detail |
| Push ticket tap | Tap enquiry notification | Opens enquiry detail |
| Foreground notification | Receive while app open | Banner shows |

## Acceptance Checklist

- [ ] Settings screen shows user info
- [ ] Push preferences load from backend
- [ ] Master toggle disables all preferences
- [ ] Individual toggles save immediately
- [ ] Appearance settings work (light/dark/system)
- [ ] About screen shows version info
- [ ] Logout clears auth and navigates to login
- [ ] Push notifications navigate to correct screen
- [ ] Deep links work for orders, devices, tickets
- [ ] Foreground notifications show banner
- [ ] Badge counts update correctly

## Deployment

1. Build and run on physical device
2. Login and navigate to Settings
3. Open notification settings
4. Toggle preferences and verify saves
5. Test appearance modes
6. Send test push notification from backend
7. Verify notification appears
8. Tap notification and verify navigation
9. Test logout flow

## Handoff Notes

- Push preferences have 10 individual toggles
- Master toggle controls all others
- Appearance mode persisted via @AppStorage
- Deep links parsed from notification payload
- URL scheme: `repairminder://order?id=xxx`
- All stages complete - ready for integration testing
- [See: 00-master-plan.md] for final verification steps
