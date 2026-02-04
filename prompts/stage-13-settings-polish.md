# RepairMinder iOS - Stage 13: Settings & Polish

You are implementing Stage 13 of the RepairMinder iOS app.

**NOTE:** This stage requires Stages 12 and 15 to be complete first.

---

## CONFIGURATION

**Master Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Stage Plan:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/13-settings-polish.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## TASK OVERVIEW

Build the settings screen, add final polish, fix edge cases, and prepare for App Store submission.

---

## FILES TO CREATE

| File | Purpose |
|------|---------|
| `Features/Settings/SettingsView.swift` | Main settings screen |
| `Features/Settings/SettingsViewModel.swift` | Settings state management |
| `Features/Settings/NotificationSettingsView.swift` | Notification preferences toggles |
| `Features/Settings/AppearanceSettingsView.swift` | Theme settings (System/Light/Dark) |
| `Features/Settings/AboutView.swift` | App info, version, legal links |
| `Features/Settings/DebugView.swift` | Debug info (DEBUG builds only) |
| `Features/Settings/Components/SyncStatusRow.swift` | Sync status display |
| `Features/Settings/Components/UserProfileHeader.swift` | User avatar and info |
| `Shared/Components/OfflineBanner.swift` | Global offline indicator banner |

---

## FILES TO MODIFY

| File | Changes |
|------|---------|
| `Repair_MinderApp.swift` | Add `preferredColorScheme` based on appearance setting |
| `ContentView.swift` | Add OfflineBanner at top |
| `Features/Settings/` | Wire up to Settings tab (already exists in router) |

---

## SETTINGS STRUCTURE

```
Settings
├── User Profile Section
│   └── Avatar, Name, Email, Role
├── Preferences Section
│   ├── Notifications → NotificationSettingsView
│   └── Appearance → AppearanceSettingsView
├── Data Section
│   ├── Sync Status Row
│   └── Sync Now Button
├── Support Section
│   ├── Help Center (Link)
│   └── Contact Support (mailto:)
├── About Section
│   ├── About Repair Minder → AboutView
│   └── Debug Info (DEBUG only) → DebugView
└── Sign Out Button (with confirmation)
```

---

## NOTIFICATION SETTINGS

Use `@AppStorage` for persistence:

```swift
@AppStorage("notif_orders") private var ordersEnabled = true
@AppStorage("notif_devices") private var devicesEnabled = true
@AppStorage("notif_messages") private var messagesEnabled = true
@AppStorage("notif_payments") private var paymentsEnabled = true
@AppStorage("notif_enquiries") private var enquiriesEnabled = true
```

Include link to open System Settings for complete control.

---

## APPEARANCE SETTINGS

```swift
enum Appearance: String, CaseIterable {
    case system, light, dark

    var displayName: String { ... }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@AppStorage("appearance") private var appearance: Appearance = .system
```

Apply in `Repair_MinderApp.swift`:
```swift
.preferredColorScheme(appearance.colorScheme)
```

---

## ABOUT VIEW

Display:
- App logo
- App name
- Version and build number (from Bundle)
- Links to Terms of Service, Privacy Policy
- Credits ("Made with love by mendmyi Limited")

---

## DEBUG VIEW (DEBUG only)

Show:
- Network status (connected/type)
- Sync status and pending count
- Last sync date
- Auth token prefix
- Force Sync button
- Clear Cache button

Wrap with `#if DEBUG ... #endif`

---

## OFFLINE BANNER

Global banner at top of app when offline:

```swift
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
```

Add to ContentView with animation.

---

## POLISH CHECKLIST

### UI Polish
- [ ] Loading states for all async operations
- [ ] Error states with retry actions
- [ ] Empty states for lists
- [ ] Pull-to-refresh on all lists
- [ ] Haptic feedback on key actions
- [ ] Smooth animations for transitions
- [ ] Proper keyboard avoidance

### Accessibility
- [ ] VoiceOver labels on interactive elements
- [ ] Dynamic Type support
- [ ] Sufficient color contrast
- [ ] Button hit targets ≥ 44pt

### Performance
- [ ] Image caching
- [ ] List virtualization (LazyVStack)
- [ ] Memory usage profiling

### Edge Cases
- [ ] No network on launch
- [ ] Token expired while offline
- [ ] Very long text truncation
- [ ] Large data sets (pagination)
- [ ] Rapid navigation

---

## INFO.PLIST KEYS

Ensure these are set:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes for quick device lookup.</string>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## SCOPE BOUNDARIES

### DO:
- Create complete Settings screen
- Implement notification preferences
- Implement appearance settings
- Create About page
- Create Debug view (DEBUG only)
- Add global offline banner
- Apply appearance setting to app
- Review and polish all existing views
- Fix any edge cases found
- Ensure accessibility compliance

### DON'T:
- Don't add new features
- Don't refactor working code unnecessarily
- Don't create new targets
- Don't implement analytics (future)

---

## BUILD & VERIFY

```
mcp__XcodeBuildMCP__build_sim
mcp__XcodeBuildMCP__build_run_sim
```

**Full Flow Test:**
1. Login → Dashboard → Orders → Detail → Update → Scan → Settings → Logout
2. Offline test: Airplane mode, use app, reconnect, verify sync
3. Appearance: Test all three modes
4. Settings: Verify all toggles persist

---

## COMPLETION CHECKLIST

- [ ] SettingsView complete with all sections
- [ ] User profile header displays correctly
- [ ] Notification toggles persist
- [ ] Appearance changes apply immediately
- [ ] Sync status shows correct state
- [ ] Sync Now triggers manual sync
- [ ] About page shows version
- [ ] Legal links work
- [ ] Debug view works (DEBUG only)
- [ ] Logout with confirmation works
- [ ] Offline banner shows/hides correctly
- [ ] All lists have empty states
- [ ] All async operations have loading states
- [ ] Accessibility audit passed
- [ ] Project builds without errors
- [ ] Both targets (Staff + Customer) still work

---

## WORKER NOTES

After completing this stage, notify that:
- Stage 13 is complete
- App is polished and ready for final testing
- Stage 14 (White-Label Support) is now unblocked
