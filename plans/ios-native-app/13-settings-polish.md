# Stage 13: Settings & Polish

## Objective

Build the settings screen, add final polish, fix edge cases, and prepare for App Store submission.

---

## Dependencies

**Requires:** All previous stages complete

---

## Complexity

**Low** - UI completion, polish, testing

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Settings/SettingsView.swift` | Main settings screen |
| `Features/Settings/NotificationSettingsView.swift` | Notification preferences |
| `Features/Settings/AppearanceSettingsView.swift` | Theme settings |
| `Features/Settings/AboutView.swift` | App info, version, legal |
| `Features/Settings/DebugView.swift` | Debug info (dev only) |
| `Shared/Components/OfflineBanner.swift` | Global offline indicator |

---

## Implementation Details

### 1. Settings View

```swift
// Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // User Section
                Section {
                    if let user = appState.currentUser {
                        HStack(spacing: 12) {
                            Text(user.initials)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(user.role.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Preferences
                Section("Preferences") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
                }

                // Sync Status
                Section("Data") {
                    SyncStatusRow()

                    Button {
                        Task {
                            await SyncEngine.shared.performFullSync()
                        }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                // Support
                Section("Support") {
                    Link(destination: URL(string: "https://repairminder.com/help")!) {
                        Label("Help Center", systemImage: "questionmark.circle.fill")
                    }

                    Link(destination: URL(string: "mailto:support@repairminder.com")!) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                }

                // About
                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Repair Minder", systemImage: "info.circle.fill")
                    }

                    #if DEBUG
                    NavigationLink {
                        DebugView()
                    } label: {
                        Label("Debug Info", systemImage: "ant.fill")
                    }
                    #endif
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Sign Out", isPresented: $showLogoutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct SyncStatusRow: View {
    @ObservedObject var syncEngine = SyncEngine.shared

    var body: some View {
        HStack {
            Label("Sync Status", systemImage: statusIcon)

            Spacer()

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    var statusIcon: String {
        switch syncEngine.status {
        case .idle: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        }
    }

    var statusText: String {
        switch syncEngine.status {
        case .idle:
            if let lastSync = syncEngine.lastSyncDate {
                return "Last sync: \(lastSync.relativeFormatted())"
            }
            return "Ready"
        case .syncing(let progress):
            return "Syncing \(Int(progress * 100))%"
        case .completed:
            return "Complete"
        case .error(let message):
            return message
        case .offline:
            return "Offline"
        }
    }
}
```

### 2. Notification Settings

```swift
// Features/Settings/NotificationSettingsView.swift
import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("notif_orders") private var ordersEnabled = true
    @AppStorage("notif_devices") private var devicesEnabled = true
    @AppStorage("notif_messages") private var messagesEnabled = true
    @AppStorage("notif_payments") private var paymentsEnabled = true

    var body: some View {
        List {
            Section {
                Toggle(isOn: $ordersEnabled) {
                    Label("Order Updates", systemImage: "doc.text.fill")
                }

                Toggle(isOn: $devicesEnabled) {
                    Label("Device Assignments", systemImage: "iphone")
                }

                Toggle(isOn: $messagesEnabled) {
                    Label("New Messages", systemImage: "message.fill")
                }

                Toggle(isOn: $paymentsEnabled) {
                    Label("Payment Received", systemImage: "creditcard.fill")
                }
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Choose which notifications you'd like to receive")
            }

            Section {
                Button("Open System Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text("To completely disable notifications, go to System Settings")
            }
        }
        .navigationTitle("Notifications")
    }
}
```

### 3. Appearance Settings

```swift
// Features/Settings/AppearanceSettingsView.swift
import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance: Appearance = .system

    enum Appearance: String, CaseIterable {
        case system, light, dark

        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var body: some View {
        List {
            Section("Theme") {
                ForEach(Appearance.allCases, id: \.self) { option in
                    Button {
                        appearance = option
                    } label: {
                        HStack {
                            Text(option.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if appearance == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Appearance")
    }
}
```

### 4. About View

```swift
// Features/Settings/AboutView.swift
import SwiftUI

struct AboutView: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)

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

            Section("Legal") {
                Link("Terms of Service", destination: URL(string: "https://repairminder.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://repairminder.com/privacy")!)
            }

            Section("Credits") {
                Text("Made with love by mendmyi Limited")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
    }
}
```

### 5. Debug View (Dev Only)

```swift
// Features/Settings/DebugView.swift
import SwiftUI

#if DEBUG
struct DebugView: View {
    @ObservedObject var syncEngine = SyncEngine.shared
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        List {
            Section("Network") {
                LabeledContent("Connected", value: networkMonitor.isConnected ? "Yes" : "No")
                LabeledContent("Type", value: String(describing: networkMonitor.connectionType))
            }

            Section("Sync") {
                LabeledContent("Status", value: String(describing: syncEngine.status))
                LabeledContent("Pending Changes", value: "\(syncEngine.pendingChangesCount)")
                if let lastSync = syncEngine.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSync.formatted())
                }
            }

            Section("Auth") {
                if let token = KeychainManager.shared.getString(for: .accessToken) {
                    LabeledContent("Token", value: String(token.prefix(20)) + "...")
                }
            }

            Section("Actions") {
                Button("Force Sync") {
                    Task { await syncEngine.performFullSync() }
                }

                Button("Clear Cache", role: .destructive) {
                    // Clear Core Data
                }
            }
        }
        .navigationTitle("Debug")
    }
}
#endif
```

### 6. Global Offline Banner

```swift
// Shared/Components/OfflineBanner.swift
import SwiftUI

struct OfflineBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("You're offline")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// Add to ContentView
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var networkMonitor = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner()

            Group {
                // ... existing content
            }
        }
        .animation(.easeInOut, value: networkMonitor.isConnected)
    }
}
```

### 7. Apply Appearance Setting

```swift
// Update Repair_MinderApp.swift
@main
struct Repair_MinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()
    @AppStorage("appearance") private var appearance: AppearanceSettingsView.Appearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(router)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    await appState.checkAuthStatus()
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
```

---

## Polish Checklist

### UI Polish
- [ ] Loading states for all async operations
- [ ] Error states with retry actions
- [ ] Empty states for lists
- [ ] Pull-to-refresh on all lists
- [ ] Haptic feedback on actions
- [ ] Smooth animations for transitions
- [ ] Proper keyboard avoidance

### Accessibility
- [ ] VoiceOver labels on all interactive elements
- [ ] Dynamic Type support
- [ ] Sufficient color contrast
- [ ] Button hit targets ≥ 44pt

### Performance
- [ ] Image caching
- [ ] List virtualization (LazyVStack)
- [ ] Background sync optimization
- [ ] Memory usage profiling

### Edge Cases
- [ ] No network on launch
- [ ] Token expired while offline
- [ ] Very long text truncation
- [ ] Large data sets (1000+ orders)
- [ ] Rapid navigation

---

## App Store Preparation

### Required Assets
- [ ] App Icon (1024x1024)
- [ ] Screenshots for all device sizes
- [ ] App Preview video (optional)
- [ ] Privacy Policy URL
- [ ] Support URL

### App Store Connect
- [ ] App description
- [ ] Keywords
- [ ] Categories (Business, Productivity)
- [ ] Age rating (4+)
- [ ] Price (Free)

### Info.plist Keys
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes for quick device lookup.</string>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Settings loads | All sections visible |
| Notification toggles | Persist across launches |
| Appearance change | Theme updates immediately |
| Sync now | Triggers manual sync |
| About shows version | Correct version/build |
| Logout | Confirms, logs out |
| Offline banner | Shows when disconnected |

---

## Acceptance Checklist

- [ ] Settings screen complete
- [ ] Notification preferences work
- [ ] Appearance settings work
- [ ] Sync status visible
- [ ] Manual sync works
- [ ] About page with version
- [ ] Logout with confirmation
- [ ] Offline banner global
- [ ] All edge cases handled
- [ ] Accessibility audit passed
- [ ] Performance acceptable
- [ ] Ready for TestFlight

---

## Final Verification

1. **Full flow test**: Login → Dashboard → Orders → Detail → Update → Scan → Settings → Logout
2. **Offline test**: Enable airplane mode, use app, reconnect, verify sync
3. **Push notification test**: Receive notification, tap, verify navigation
4. **Customer portal test**: Full customer login and tracking flow
5. **Performance test**: Profile with Instruments
6. **Accessibility test**: VoiceOver full walkthrough

---

## Deployment

### TestFlight

```bash
# Archive for TestFlight
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "generic/platform=iOS" \
  -archivePath build/RepairMinder.xcarchive \
  archive

# Export for App Store
xcodebuild -exportArchive \
  -archivePath build/RepairMinder.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/
```

### App Store Submission

1. Upload via Xcode Organizer or `xcrun altool`
2. Complete App Store Connect metadata
3. Submit for review
4. Monitor for rejection/approval

---

## Congratulations!

The Repair Minder iOS app is complete and ready for release!
